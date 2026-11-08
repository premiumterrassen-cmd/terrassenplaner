import 'lastlauf.dart';
import 'lasttest.dart';

/// Ein Zielwert des Lasttests (M10-02) mit dem lokal gemessenen und dem auf
/// den Zielserver umgerechneten Wert.
final class Zielwert {
  const Zielwert({
    required this.kennung,
    required this.beschreibung,
    required this.grenze,
    required this.einheit,
    required this.gemessen,
    required this.zielserver,
    this.mindestens = false,
  });

  final String kennung;
  final String beschreibung;
  final double grenze;
  final String einheit;

  /// Lokal gemessener Wert.
  final double gemessen;

  /// Auf den Zielserver umgerechneter Wert ([Zielwerte.faktor]).
  final double zielserver;

  /// `true`: der Wert muss mindestens [grenze] sein, sonst höchstens.
  final bool mindestens;

  /// Ohne Messwert (negativ, z. B. kein erfolgreicher Aufruf) nie erreicht.
  bool get erreicht =>
      gemessen >= 0 &&
      (mindestens ? zielserver >= grenze : zielserver <= grenze);

  Map<String, Object> alsJson() => {
    'kennung': kennung,
    'beschreibung': beschreibung,
    'grenze': grenze,
    'einheit': einheit,
    'gemessen': gemessen,
    'zielserver': zielserver,
    'erreicht': erreicht,
  };
}

/// Zielwerte für den Zielserver (2 Kerne, 3,8 GB RAM) – Begründung in
/// docs/abnahme/lasttest.md.
abstract final class Zielwerte {
  /// Sicherheitsfaktor für den Zielserver: ein Kern dort gilt als halb so
  /// schnell wie ein Kern des Messrechners; Zeiten und CPU-Bedarf werden
  /// verdoppelt, der Durchsatz halbiert. Der Speicher bleibt.
  static const faktor = 2.0;

  /// Speicherbudget des Router-Prozesses in MiB.
  static const speicherMb = 1024.0;

  /// Prüft die [ergebnisse] der vorhandenen Szenarien.
  static List<Zielwert> pruefe(List<Szenarioergebnis> ergebnisse) => [
    for (final e in ergebnisse) ..._fuer(e),
  ];

  static List<Zielwert> _fuer(Szenarioergebnis e) {
    final name = e.szenario.name;
    final werte = <Zielwert>[
      _fehler(name, e),
      if (e.speicherSpitzeMb case final mb?)
        Zielwert(
          kennung: '$name.speicher',
          beschreibung: 'Speicher des Routers (Spitze)',
          grenze: speicherMb,
          einheit: 'MiB',
          gemessen: mb,
          zielserver: mb,
        ),
    ];
    switch (name) {
      case 'nutzer':
        final p = e.profil('nutzer');
        werte.addAll([
          _p95('nutzer.berechnen', p, Vorgang.berechnen, 250),
          _p95('nutzer.speichern', p, Vorgang.speichern, 250),
          _p95('nutzer.laden', p, Vorgang.laden, 250),
          if (e.cpuKerne case final kerne?)
            Zielwert(
              kennung: 'nutzer.cpu',
              beschreibung: 'CPU-Bedarf des Routers',
              grenze: 1,
              einheit: 'Kerne',
              gemessen: kerne,
              zielserver: kerne * faktor,
            ),
        ]);
      case 'sitzungen':
        final p = e.profil('sitzungen');
        werte.addAll([
          _p95('sitzungen.berechnen', p, Vorgang.berechnen, 500),
          _p95('sitzungen.speichern', p, Vorgang.speichern, 500),
        ]);
      case 'gross':
        final n = e.profil('nebenher');
        werte.addAll([
          _p95(
            'gross.berechnenGross',
            e.profil('gross'),
            Vorgang.berechnenGross,
            5000,
          ),
          _p95('gross.nebenher.berechnen', n, Vorgang.berechnen, 500),
          _p95('gross.nebenher.speichern', n, Vorgang.speichern, 500),
        ]);
      case 'durchsatz':
        final p = e.profil('durchsatz');
        werte.addAll([
          Zielwert(
            kennung: 'durchsatz.aufrufe',
            beschreibung: 'Aufrufe je Sekunde über den Router',
            grenze: 2000,
            einheit: '1/s',
            gemessen: _runde(p.durchsatz),
            zielserver: _runde(p.durchsatz / faktor),
            mindestens: true,
          ),
          _p95('durchsatz.hallo', p, Vorgang.hallo, 100),
        ]);
    }
    return werte;
  }

  static Zielwert _fehler(String name, Szenarioergebnis e) {
    final fehler = e.ergebnisse.fold(0, (s, l) => s + l.fehlerSumme);
    return Zielwert(
      kennung: '$name.fehler',
      beschreibung: 'gescheiterte Aufrufe',
      grenze: 0,
      einheit: 'Aufrufe',
      gemessen: fehler.toDouble(),
      zielserver: fehler.toDouble(),
    );
  }

  static Zielwert _p95(
    String kennung,
    Lastergebnis ergebnis,
    Vorgang vorgang,
    double grenzeMs,
  ) {
    final statistik = ergebnis.statistik[vorgang];
    final ms = statistik == null || statistik.anzahl == 0
        ? -1.0
        : statistik.p95.inMicroseconds / 1000;
    return Zielwert(
      kennung: kennung,
      beschreibung: 'p95 ${vorgang.name}',
      grenze: grenzeMs,
      einheit: 'ms',
      gemessen: _runde(ms),
      zielserver: ms < 0 ? ms : _runde(ms * faktor),
    );
  }

  static double _runde(double wert) => (wert * 10).round() / 10;
}
