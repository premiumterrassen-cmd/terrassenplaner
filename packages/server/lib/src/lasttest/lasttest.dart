import 'dart:async';
import 'dart:io';

import 'lastlauf.dart';
import 'lasttest_optionen.dart';
import 'latenzstatistik.dart';
import 'prozessmessung.dart';
import 'zielwerte.dart';

/// Misst den Serverprozess (Speicher, CPU-Zeit); `null` = nicht messbar.
typedef Messung = Future<Prozessmessung?> Function();

/// Ein Szenario des Lasttests: seine [profile] laufen gleichzeitig.
final class Szenario {
  const Szenario(this.name, this.beschreibung, this.profile);

  final String name;
  final String beschreibung;
  final List<Lastprofil> profile;
}

/// Ergebnis eines Szenarios samt Speicherspitze und CPU-Bedarf des
/// Serverprozesses.
final class Szenarioergebnis {
  const Szenarioergebnis(
    this.szenario,
    this.ergebnisse, {
    this.speicherVorherMb,
    this.speicherSpitzeMb,
    this.cpuKerne,
    this.lastCpuKerne,
  });

  final Szenario szenario;
  final List<Lastergebnis> ergebnisse;
  final double? speicherVorherMb;
  final double? speicherSpitzeMb;

  /// Mittlere Zahl belegter Kerne des Servers während des Szenarios
  /// (CPU-Zeit ÷ Laufzeit).
  final double? cpuKerne;

  /// Belegte Kerne des Lastwerkzeugs selbst – nahe an der Zahl seiner
  /// Kerne heißt: das Werkzeug, nicht der Router begrenzt.
  final double? lastCpuKerne;

  /// Ergebnis des Profils [name].
  Lastergebnis profil(String name) =>
      ergebnisse.firstWhere((e) => e.profil.name == name);

  Map<String, Object?> alsJson() => {
    'szenario': szenario.name,
    'beschreibung': szenario.beschreibung,
    'speicher_vorher_mb': ?speicherVorherMb,
    'speicher_spitze_mb': ?speicherSpitzeMb,
    'cpu_kerne': ?cpuKerne,
    'lastwerkzeug_cpu_kerne': ?lastCpuKerne,
    'profile': [for (final e in ergebnisse) e.alsJson()],
  };
}

/// Last- und Leistungstest (M10-02): gleichzeitige Nutzer, große Projekte
/// und Router-Durchsatz gegen einen laufenden Planer-Router.
abstract final class Lasttest {
  /// Schritte einer Bedienrunde in der App: drei Änderungen (je eine
  /// Berechnung), Zwischenspeichern, SPEICHERN und LADEN.
  static const bedienrunde = [
    Vorgang.berechnen,
    Vorgang.berechnen,
    Vorgang.berechnen,
    Vorgang.entwurf,
    Vorgang.speichern,
    Vorgang.laden,
  ];

  /// Die Szenarien; [dauer] je Szenario (lang 60 s, kurz für Tests und
  /// Build-Chain), [faktor] skaliert die Zahl der Sitzungen.
  static List<Szenario> szenarien({
    Duration dauer = const Duration(seconds: 60),
    double faktor = 1,
  }) {
    int n(int anzahl) => (anzahl * faktor).ceil();
    return [
      Szenario(
        'nutzer',
        '${n(50)} gleichzeitig arbeitende Nutzer (Bedienrunde, 1 s Denkzeit)',
        [
          Lastprofil(
            name: 'nutzer',
            sitzungen: n(50),
            dauer: dauer,
            schritte: bedienrunde,
            denkzeit: const Duration(seconds: 1),
          ),
        ],
      ),
      Szenario(
        'sitzungen',
        '${n(100)} verbundene Sitzungen, je eine Bedienrunde alle 5 s',
        [
          Lastprofil(
            name: 'sitzungen',
            sitzungen: n(100),
            dauer: dauer,
            schritte: bedienrunde,
            denkzeit: const Duration(seconds: 5),
          ),
        ],
      ),
      Szenario(
        'gross',
        '${n(2)} Sitzungen rechnen ohne Pause große Projekte, '
            '${n(20)} Nutzer arbeiten nebenher',
        [
          Lastprofil(
            name: 'gross',
            sitzungen: n(2),
            dauer: dauer,
            schritte: const [Vorgang.berechnenGross],
          ),
          Lastprofil(
            name: 'nebenher',
            sitzungen: n(20),
            dauer: dauer,
            schritte: bedienrunde,
            denkzeit: const Duration(seconds: 1),
          ),
        ],
      ),
      Szenario(
        'durchsatz',
        '${n(100)} Sitzungen rufen ohne Pause die kleinste Prozedur auf',
        [
          Lastprofil(
            name: 'durchsatz',
            sitzungen: n(100),
            dauer: dauer,
            schritte: const [Vorgang.hallo],
          ),
        ],
      ),
    ];
  }

  /// Fährt [szenario] und misst den Serverprozess alle [takt].
  static Future<Szenarioergebnis> fahre(
    Szenario szenario,
    Verbindung verbinde, {
    Messung? messe,
    Messung? messeLast,
    Duration takt = abtastTakt,
    Duration zeitlimit = Lastlauf.standardZeitlimit,
  }) async {
    final vorher = await messe?.call();
    final lastVorher = await messeLast?.call();
    double? spitze = vorher?.speicherMb;
    final uhr = Stopwatch()..start();
    final abtastung = messe == null
        ? null
        : Timer.periodic(takt, (_) async {
            final m = await messe();
            if (m != null && m.speicherMb > (spitze ?? 0)) {
              spitze = m.speicherMb;
            }
          });
    final ergebnisse = await Future.wait([
      for (final p in szenario.profile)
        Lastlauf.fahre(p, verbinde, zeitlimit: zeitlimit),
    ]);
    abtastung?.cancel();
    final nachher = await messe?.call();
    final lastNachher = await messeLast?.call();
    final laufzeit = uhr.elapsed;
    return Szenarioergebnis(
      szenario,
      ergebnisse,
      speicherVorherMb: vorher?.speicherMb,
      speicherSpitzeMb: spitze,
      cpuKerne: vorher == null || nachher == null
          ? null
          : kerne(nachher.cpuZeit - vorher.cpuZeit, laufzeit),
      lastCpuKerne: lastVorher == null || lastNachher == null
          ? null
          : kerne(lastNachher.cpuZeit - lastVorher.cpuZeit, laufzeit),
    );
  }

  /// Fährt die Szenarien des [lauf]s nacheinander, meldet je Szenario eine
  /// Zeile und prüft die Zielwerte.
  static Future<Lastbericht> fuehreAus(
    Lauf lauf,
    Verbindung verbinde, {
    Messung? messe,
    Messung? messeLast,
    void Function(String zeile) melde = _still,
    Duration zeitlimit = Lastlauf.standardZeitlimit,
  }) async {
    final auswahl = [
      for (final s in szenarien(dauer: lauf.dauer, faktor: lauf.faktor))
        if (lauf.szenarien.isEmpty || lauf.szenarien.contains(s.name)) s,
    ];
    final ergebnisse = <Szenarioergebnis>[];
    for (final s in auswahl) {
      melde('== ${s.name}: ${s.beschreibung}');
      final e = await fahre(
        s,
        verbinde,
        messe: messe,
        messeLast: messeLast,
        zeitlimit: zeitlimit,
      );
      ergebnisse.add(e);
      for (final p in e.ergebnisse) {
        melde(zeile(p));
        for (final MapEntry(:key, :value) in p.statistik.entries) {
          melde(
            '     ${key.name}: p50 ${Latenzstatistik.ms(value.p50)} ms, '
            'p95 ${Latenzstatistik.ms(value.p95)} ms, '
            'max ${Latenzstatistik.ms(value.hoechst)} ms',
          );
        }
      }
      melde(
        '   Server: Speicher ${e.speicherVorherMb} → ${e.speicherSpitzeMb} MiB, '
        'CPU ${e.cpuKerne} Kerne; Lastwerkzeug CPU ${e.lastCpuKerne} Kerne',
      );
    }
    final bericht = Lastbericht(ergebnisse);
    for (final z in bericht.zielwerte) {
      melde(
        '${z.erreicht ? 'ok    ' : 'VERFEHLT'} ${z.kennung}: '
        '${z.zielserver} ${z.einheit} (lokal ${z.gemessen}, '
        '${z.mindestens ? '≥' : '≤'} ${z.grenze})',
      );
    }
    return bericht;
  }

  static void _still(String _) {}

  /// Abstand der Speichermessungen am Server.
  static const abtastTakt = Duration(milliseconds: 250);

  /// Zusammenfassung eines Profils: Aufrufe, Fehler, Durchsatz und der
  /// erste Fehler.
  static String zeile(Lastergebnis p) =>
      '   ${p.profil.name}: ${p.aufrufe} Aufrufe, ${p.fehlerSumme} Fehler, '
      '${p.durchsatz.toStringAsFixed(1)}/s'
      '${p.ersterFehler == null ? '' : ' (${p.ersterFehler})'}';

  /// Belegte Kerne: [cpu] Zeit in [laufzeit], zwei Nachkommastellen.
  static double kerne(Duration cpu, Duration laufzeit) =>
      (cpu.inMicroseconds * 100 / laufzeit.inMicroseconds).round() / 100;
}

/// Bericht eines Lasttests: Szenarien, Messumgebung und Zielwerte.
final class Lastbericht {
  Lastbericht(this.ergebnisse, {DateTime? erstellt})
    : erstellt = erstellt ?? DateTime.now(),
      zielwerte = Zielwerte.pruefe(ergebnisse);

  final List<Szenarioergebnis> ergebnisse;
  final DateTime erstellt;
  final List<Zielwert> zielwerte;

  bool get zielwerteErreicht => zielwerte.every((z) => z.erreicht);

  Map<String, Object?> alsJson() => {
    'erstellt': erstellt.toIso8601String(),
    'messrechner': {
      'betriebssystem': Platform.operatingSystemVersion,
      'kerne': Platform.numberOfProcessors,
      'dart': Platform.version,
    },
    'faktor_zielserver': Zielwerte.faktor,
    'zielwerte_erreicht': zielwerteErreicht,
    'zielwerte': [for (final z in zielwerte) z.alsJson()],
    'szenarien': [for (final e in ergebnisse) e.alsJson()],
  };
}
