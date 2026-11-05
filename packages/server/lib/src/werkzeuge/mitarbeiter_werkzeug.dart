import 'package:connectanum_client/connectanum.dart' as wamp;
import 'package:connectanum_client/json.dart';
import 'package:connectanum_client/socket.dart';

import '../dienste/mitarbeiter_verwaltung.dart';
import '../router/auth_server_einstellungen.dart';
import '../router/umgebung.dart';
import '../zugriff/mitarbeiter_zugang.dart';

/// Ruft eine Verwaltungsprozedur des Auth-Servers auf; Fehler des Servers
/// kommen als [VerwaltungsFehler].
typedef Verwaltungsaufruf = Future<List<Object?>> Function(
  String prozedur,
  List<Object?> argumente,
);

/// Ablehnung durch den Auth-Server mit seiner Meldung.
final class VerwaltungsFehler implements Exception {
  const VerwaltungsFehler(this.meldung);

  final String meldung;

  @override
  String toString() => meldung;
}

/// Verbindung des Werkzeugs zum Auth-Server.
typedef Verwaltungsverbindung = ({
  Verwaltungsaufruf rufe,
  Future<void> Function() schliesse,
});

/// Kommandozeilenwerkzeug für Mitarbeiter-Konten (M9-10,
/// `bin/mitarbeiter.dart`, docs/betrieb/mitarbeiter.md):
///
/// ```text
/// mitarbeiter anlegen <email>     Passwort über stdin
/// mitarbeiter passwort <email>    neues Passwort über stdin
/// mitarbeiter sperren <email>
/// mitarbeiter entsperren <email>
/// mitarbeiter liste
/// ```
///
/// Das Passwort kommt nie als Argument (es stünde sonst in der
/// Prozessliste und im Shell-Verlauf); das Werkzeug leitet die
/// SCRAM-Schlüssel selbst ab und schickt nur sie an den Auth-Server.
class MitarbeiterWerkzeug {
  MitarbeiterWerkzeug({
    required this.rufe,
    required this.passwortLesen,
    required this.ausgabe,
    required this.fehler,
    this.interaktiv = false,
    this.ableiten = _ableiten,
  });

  final Verwaltungsaufruf rufe;

  /// Liest eine Zeile (verdeckt, wenn [interaktiv]); `null` am Ende der
  /// Eingabe.
  final String? Function(String frage) passwortLesen;
  final void Function(String zeile) ausgabe;
  final void Function(String zeile) fehler;

  /// Am Terminal wird das Passwort zur Kontrolle zweimal abgefragt.
  final bool interaktiv;

  final Future<MitarbeiterZugang> Function(String email, String passwort)
  ableiten;

  /// Mindestlänge eines Passworts.
  static const mindestlaenge = 12;

  static const aufruf =
      'Aufruf: mitarbeiter anlegen|passwort|sperren|entsperren <email> '
      '| mitarbeiter liste';

  static Future<MitarbeiterZugang> _ableiten(String email, String passwort) =>
      MitarbeiterZugang.ableiten(authId: email, passwort: passwort);

  /// Führt den Befehl aus; liefert den Exit-Code (0 gut, 1 abgelehnt,
  /// 64 falscher Aufruf).
  Future<int> fuehreAus(List<String> argumente) async {
    try {
      switch (argumente) {
        case ['liste']:
          for (final [email as String, gesperrt as bool] in (await rufe(
            MitarbeiterVerwaltung.liste,
            const [],
          )).cast<List<Object?>>()) {
            ausgabe(gesperrt ? '$email (gesperrt)' : email);
          }
        case ['anlegen', final email]:
          await _mitPasswort(MitarbeiterVerwaltung.anlegen, email);
          ausgabe('Konto ${MitarbeiterZugang.email(email)} angelegt');
        case ['passwort', final email]:
          await _mitPasswort(MitarbeiterVerwaltung.passwort, email);
          ausgabe('Passwort für ${MitarbeiterZugang.email(email)} gesetzt');
        case ['sperren', final email]:
          await rufe(MitarbeiterVerwaltung.sperren, [
            MitarbeiterZugang.email(email),
          ]);
          ausgabe('Konto ${MitarbeiterZugang.email(email)} gesperrt');
        case ['entsperren', final email]:
          await rufe(MitarbeiterVerwaltung.entsperren, [
            MitarbeiterZugang.email(email),
          ]);
          ausgabe('Konto ${MitarbeiterZugang.email(email)} entsperrt');
        default:
          fehler(aufruf);
          return 64;
      }
      return 0;
    } on ArgumentError catch (f) {
      fehler('${f.message}: ${f.invalidValue}');
      return 64;
    } on VerwaltungsFehler catch (f) {
      fehler('Abgelehnt: ${f.meldung}');
      return 1;
    }
  }

  Future<void> _mitPasswort(String prozedur, String text) async {
    final email = MitarbeiterZugang.email(text);
    final passwort = _neuesPasswort(email);
    final zugang = await ableiten(email, passwort);
    await rufe(prozedur, [zugang.alsJson()]);
  }

  String _neuesPasswort(String email) {
    final passwort = passwortLesen('Passwort für $email: ') ?? '';
    if (passwort.length < mindestlaenge) {
      throw ArgumentError.value(
        '${passwort.length} Zeichen',
        'passwort',
        'Passwort zu kurz (mindestens $mindestlaenge Zeichen)',
      );
    }
    if (interaktiv && passwortLesen('Wiederholen: ') != passwort) {
      throw ArgumentError.value(
        'Wiederholung',
        'passwort',
        'Passwörter stimmen nicht überein',
      );
    }
    return passwort;
  }

  /// Verbindet sich mit dem Auth-Server: Adresse aus `PLANER_AUTH_ADRESSE`
  /// (sonst `PLANER_AUTH_LISTEN`, wie in der Umgebungsdatei des
  /// Auth-Servers), Ticket aus `PLANER_AUTH_DIENST_TICKET`.
  static Future<Verwaltungsverbindung> verbinde(
    Map<String, String> umgebung,
  ) async {
    final adresse = Uri.parse(
      'tcp://${umgebung['PLANER_AUTH_ADRESSE'] ?? umgebung['PLANER_AUTH_LISTEN'] ?? AuthServerEinstellungen.standardListen}',
    );
    final sitzung =
        await wamp.Client(
              realm: AuthServerEinstellungen.authRealm,
              authId: AuthServerEinstellungen.verwaltungId,
              authenticationMethods: [
                wamp.TicketAuthentication(
                  Umgebung.pflicht(umgebung, 'PLANER_AUTH_DIENST_TICKET'),
                ),
              ],
              transport: SocketTransport(
                // Im Container lauscht der Auth-Server auf 0.0.0.0.
                adresse.host == '0.0.0.0' ? '127.0.0.1' : adresse.host,
                adresse.port,
                Serializer(),
                SocketHelper.serializationJson,
              ),
            )
            .connect(options: wamp.ClientConnectOptions(reconnectCount: 0))
            .first
            .timeout(const Duration(seconds: 20));
    return (
      rufe: (String prozedur, List<Object?> argumente) async {
        try {
          return (await sitzung.callSingle(
                prozedur,
                arguments: argumente,
              )).arguments ??
              const <Object?>[];
        } on wamp.Error catch (f) {
          throw VerwaltungsFehler('${f.arguments?.firstOrNull ?? f.error}');
        }
      },
      schliesse: sitzung.close,
    );
  }
}
