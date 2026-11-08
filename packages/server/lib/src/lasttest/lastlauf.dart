import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:connectanum_client/connectanum.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../dienste/planungs_dienst.dart';
import 'lastdaten.dart';
import 'latenzstatistik.dart';

/// Baut eine neue WAMP-Sitzung zum Planer-Router auf.
typedef Verbindung = Future<Session> Function();

/// Ein Aufruf, wie ihn die App macht (M10-02).
enum Vorgang {
  /// Hallo-Prozedur: kleinster Rundlauf über den Router (Durchsatz).
  hallo,

  /// Typische Planung berechnen (bei jeder Änderung in der App).
  berechnen,

  /// Großes Projekt berechnen ([Lastdaten.gross]).
  berechnenGross,

  /// Typische Planung als neue Version speichern (SPEICHERN).
  speichern,

  /// Zuletzt gespeicherte Version laden (LADEN).
  laden,

  /// Automatisches Zwischenspeichern des Entwurfs.
  entwurf,
}

/// Lastprofil: [sitzungen] gleichzeitige Sitzungen wiederholen [dauer] lang
/// ihre [schritte], nach jeder Runde im Mittel [denkzeit] Pause (Bedienung
/// der App). Damit die Sitzungen nicht im Gleichschritt rechnen, beginnt
/// jede zufällig versetzt und streut ihre Pausen ([pause]).
final class Lastprofil {
  const Lastprofil({
    required this.name,
    required this.sitzungen,
    required this.dauer,
    required this.schritte,
    this.denkzeit = Duration.zero,
  });

  final String name;
  final int sitzungen;
  final Duration dauer;
  final List<Vorgang> schritte;
  final Duration denkzeit;

  /// Pause nach einer Runde: gleichverteilt zwischen der halben und der
  /// anderthalbfachen [denkzeit].
  Duration pause(Random zufall) => denkzeit * (0.5 + zufall.nextDouble());

  /// Versatz zum Start: gleichverteilt bis zu einer [denkzeit].
  Duration versatz(Random zufall) => denkzeit * zufall.nextDouble();
}

/// Ergebnis eines Lastlaufs: Antwortzeiten und Fehler je [Vorgang].
final class Lastergebnis {
  Lastergebnis({
    required this.profil,
    required this.laufzeit,
    required Map<Vorgang, List<Duration>> zeiten,
    required Map<Vorgang, int> fehler,
    this.ersterFehler,
  }) : statistik = {
         for (final MapEntry(:key, :value) in zeiten.entries)
           key: Latenzstatistik.aus(value),
       },
       fehler = Map.unmodifiable(fehler);

  final Lastprofil profil;
  final Duration laufzeit;
  final Map<Vorgang, Latenzstatistik> statistik;
  final Map<Vorgang, int> fehler;

  /// Text des ersten Fehlers (zur Diagnose), sonst `null`.
  final String? ersterFehler;

  /// Erfolgreiche Aufrufe insgesamt.
  int get aufrufe => statistik.values.fold(0, (s, l) => s + l.anzahl);

  /// Gescheiterte Aufrufe insgesamt.
  int get fehlerSumme => fehler.values.fold(0, (s, n) => s + n);

  /// Erfolgreiche Aufrufe je Sekunde Laufzeit.
  double get durchsatz =>
      laufzeit == Duration.zero ? 0 : aufrufe * 1e6 / laufzeit.inMicroseconds;

  Map<String, Object?> alsJson() => {
    'profil': profil.name,
    'sitzungen': profil.sitzungen,
    'denkzeit_ms': profil.denkzeit.inMilliseconds,
    'laufzeit_s': Latenzstatistik.ms(laufzeit) / 1000,
    'aufrufe': aufrufe,
    'fehler': fehlerSumme,
    'durchsatz_je_s': (durchsatz * 10).round() / 10,
    'vorgaenge': {
      for (final MapEntry(:key, :value) in statistik.entries)
        key.name: {...value.alsJson(), 'fehler': fehler[key] ?? 0},
    },
    'erster_fehler': ?ersterFehler,
  };
}

/// Fährt ein [Lastprofil] gegen den Router (M10-02): alle Sitzungen
/// verbinden sich zuerst, dann rechnen, speichern und laden sie
/// gleichzeitig. Die Zeit läuft je Aufruf vom Absenden bis zur Antwort.
abstract final class Lastlauf {
  static final _ppt = CallOptions(
    pptScheme: WampNamen.pptSchema,
    pptSerializer: WampNamen.pptSerializer,
  );

  static Future<Lastergebnis> fahre(
    Lastprofil profil,
    Verbindung verbinde, {
    Duration zeitlimit = const Duration(seconds: 60),
  }) async {
    final sitzungen = await Future.wait([
      for (var i = 0; i < profil.sitzungen; i++) verbinde(),
    ]);
    final zeiten = <Vorgang, List<Duration>>{
      for (final v in profil.schritte) v: [],
    };
    final fehler = <Vorgang, int>{};
    String? ersterFehler;
    final inhalte = [
      Lastdaten.typisch().zuBytes(),
      Lastdaten.typisch(5500).zuBytes(),
    ];
    final gross = Lastdaten.gross().zuBytes();
    final uhr = Stopwatch()..start();
    Future<void> sitzung(Session s, int nummer) async {
      final zustand = _Zustand(s, nummer, inhalte, gross);
      // je Sitzung eigener, fester Zufall: wiederholbare Läufe
      final zufall = Random(nummer);
      await Future<void>.delayed(profil.versatz(zufall));
      while (uhr.elapsed < profil.dauer) {
        for (final vorgang in profil.schritte) {
          final start = uhr.elapsed;
          try {
            await zustand.fuehreAus(vorgang).timeout(zeitlimit);
            zeiten[vorgang]!.add(uhr.elapsed - start);
          } on Object catch (f) {
            fehler[vorgang] = (fehler[vorgang] ?? 0) + 1;
            ersterFehler ??= '${vorgang.name}: $f';
          }
        }
        await Future<void>.delayed(profil.pause(zufall));
      }
    }

    await Future.wait([
      for (var i = 0; i < sitzungen.length; i++) sitzung(sitzungen[i], i),
    ]);
    final laufzeit = uhr.elapsed;
    await Future.wait([for (final s in sitzungen) schliesse(s)]);
    return Lastergebnis(
      profil: profil,
      laufzeit: laufzeit,
      zeiten: zeiten,
      fehler: fehler,
      ersterFehler: ersterFehler,
    );
  }

  /// Schließt [s]; eine schon getrennte Sitzung zählt nicht als Fehler des
  /// Lasttests (die gescheiterten Aufrufe sind bereits gezählt).
  static Future<void> schliesse(Session s) => ohneGeschlossenFehler(s.close);

  /// Führt [schliessen] aus; „Transport nicht offen“ ([StateError]) ist
  /// beim Schließen kein Fehler.
  static Future<void> ohneGeschlossenFehler(
    Future<void> Function() schliessen,
  ) async {
    try {
      await schliessen();
    } on StateError {
      return;
    }
  }

  /// Berechnung über den Planungsdienst (typisierte Planung hin und zurück);
  /// prüft, dass eine Berechnung zurückkommt.
  static Future<Berechnung> berechne(Session s, Uint8List planung) async {
    final antwort = await s.callSingleLazyPayloadView(
      WampNamen.planungBerechnen,
      payload: PlanungsDienst.verpacke(planung),
      options: _ppt,
    );
    return Berechnung.ausBytes(antwort.payload.packedPayloadBytes!);
  }
}

/// Zustand einer Sitzung: zuletzt gespeicherte Kennung und Version.
final class _Zustand {
  _Zustand(this.sitzung, this.nummer, this.inhalte, this.gross);

  final Session sitzung;
  final int nummer;
  final List<Uint8List> inhalte;
  final Uint8List gross;
  String? kennung;
  int version = 0;
  var _runde = 0;

  /// Sitzungsschlüssel des Browsers (128 Bit hexadezimal) je Sitzung.
  String get schluessel => nummer.toRadixString(16).padLeft(32, '0');

  Uint8List get inhalt => inhalte[_runde % inhalte.length];

  Future<void> fuehreAus(Vorgang vorgang) async {
    switch (vorgang) {
      case Vorgang.hallo:
        await sitzung.callSingle(WampNamen.hallo);
      case Vorgang.berechnen:
        await Lastlauf.berechne(sitzung, inhalt);
      case Vorgang.berechnenGross:
        await Lastlauf.berechne(sitzung, gross);
      case Vorgang.speichern:
        _runde++;
        final antwort = await sitzung.callSingle(
          WampNamen.konfigurationSpeichern,
          arguments: [inhalt, ?kennung],
        );
        final [neu as String, neueVersion as int] = antwort.arguments!;
        kennung = neu;
        version = neueVersion;
      case Vorgang.laden:
        if (kennung == null) await fuehreAus(Vorgang.speichern);
        await sitzung.callSingle(
          WampNamen.konfigurationLaden,
          arguments: [kennung, version],
        );
      case Vorgang.entwurf:
        await sitzung.callSingle(
          WampNamen.entwurfSpeichern,
          arguments: [schluessel, inhalt],
        );
    }
  }
}
