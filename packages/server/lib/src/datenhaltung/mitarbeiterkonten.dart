import '../../objectbox.g.dart';
import '../zugriff/mitarbeiter_zugang.dart';
import 'datenbank.dart';
import 'entitaeten.dart';

/// Ein Konto gibt es schon (anlegen) bzw. nicht (alle anderen Befehle).
final class KontoFehler implements Exception {
  const KontoFehler(this.meldung);

  final String meldung;

  @override
  String toString() => meldung;
}

/// Mitarbeiter-Konten des Auth-Servers in ObjectBox (Entität [Benutzer],
/// M9-10). Keine Selbstregistrierung: angelegt, gesperrt und mit neuem
/// Passwort versehen werden Konten nur über das Verwaltungswerkzeug.
class Mitarbeiterkonten {
  Mitarbeiterkonten(this.datenbank);

  final Datenbank datenbank;

  /// Zugang zu [authId] (auch gesperrt) oder `null`.
  MitarbeiterZugang? finde(String authId) {
    final b = datenbank.benutzer(authId);
    if (b == null) return null;
    return MitarbeiterZugang(
      authId: b.authId,
      salt: b.salt,
      kdf: b.kdf,
      iterationen: b.iterationen,
      speicher: b.speicher,
      storedKey: b.storedKey,
      serverKey: b.serverKey,
      gesperrt: b.gesperrt,
    );
  }

  /// Legt ein neues Konto an; vorhanden: [KontoFehler].
  void anlegen(MitarbeiterZugang zugang) => datenbank.transaktion(() {
    if (datenbank.benutzer(zugang.authId) != null) {
      throw KontoFehler('Konto ${zugang.authId} gibt es schon');
    }
    datenbank.speichere(
      Benutzer(
        authId: zugang.authId,
        salt: zugang.salt,
        kdf: zugang.kdf,
        iterationen: zugang.iterationen,
        speicher: zugang.speicher,
        storedKey: zugang.storedKey,
        serverKey: zugang.serverKey,
      ),
    );
  });

  /// Neue Schlüssel (neues Passwort) für ein vorhandenes Konto; die Sperre
  /// bleibt, wie sie ist.
  void setzePasswort(MitarbeiterZugang zugang) => datenbank.transaktion(() {
    datenbank.speichere(
      _konto(zugang.authId)
        ..salt = zugang.salt
        ..kdf = zugang.kdf
        ..iterationen = zugang.iterationen
        ..speicher = zugang.speicher
        ..storedKey = zugang.storedKey
        ..serverKey = zugang.serverKey,
    );
  });

  /// Sperrt ein Konto oder gibt es wieder frei.
  void sperre(String authId, {required bool gesperrt}) =>
      datenbank.transaktion(() {
        datenbank.speichere(_konto(authId)..gesperrt = gesperrt);
      });

  /// Alle Konten nach E-Mail-Adresse sortiert, mit Sperrvermerk.
  List<({String authId, bool gesperrt})> liste() {
    final abfrage = datenbank.store
        .box<Benutzer>()
        .query(Benutzer_.geloeschtAm.isNull())
        .order(Benutzer_.authId)
        .build();
    try {
      return [
        for (final b in abfrage.find())
          (authId: b.authId, gesperrt: b.gesperrt),
      ];
    } finally {
      abfrage.close();
    }
  }

  Benutzer _konto(String authId) =>
      datenbank.benutzer(authId) ??
      (throw KontoFehler('Konto $authId gibt es nicht'));
}
