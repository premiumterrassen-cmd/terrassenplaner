/// Geometrie der Pläne (Planungsregeln Alexander (Planungskern v6,
/// 11.11.2026), Abschnitt 6): Stoßlinien im Verlegeplan (R-E01) und die
/// Achsmaßkette im UK-Plan (R-E02). Der Server rechnet sie, App und PDF
/// zeichnen sie nur.
library;

import 'dart:math' as math;

import 'package:flat_buffers/flat_buffers.dart' as fb;

import '../geometrie/punkt.dart';
import '../konfiguration/dielenverlegung.dart';
import '../konfiguration/planungsstand.dart';
import '../regeln/uk_verlegung.dart';

/// Eine Strecke in Planungskoordinaten (mm).
typedef Strecke = ({Punkt von, Punkt bis});

/// Maßkette der UK-Achsen (R-E02): die [marken] liegen auf einer Kante des
/// umschließenden Rechtecks (quer zur UK) – Rand, jede Achse, Rand –, die
/// [normale] zeigt von dort aus der Fläche hinaus; dorthin wird die Kette
/// versetzt gezeichnet.
final class Masskette {
  Masskette(List<Punkt> marken, this.normale)
    : marken = List.unmodifiable(marken);

  final List<Punkt> marken;
  final Punkt normale;

  /// Abstand je zwei benachbarter [marken] in mm.
  List<double> get abstaende => [
    for (var i = 1; i < marken.length; i++) marken[i - 1].abstand(marken[i]),
  ];
}

/// Maß eines Bogens an einer Seite (Planungsregeln Alexander (Planungskern
/// v12, 12.11.2026), Regel 14.1.3): Nummer der [seite], Bogenlänge und
/// Radius in mm, der [scheitel] (Mitte des Bogens) und die Richtung
/// [aussen] aus der Fläche – dort steht „Bogen … · R …“ statt der Sehne.
typedef Bogenmass = ({
  int seite,
  double laenge,
  double radius,
  Punkt scheitel,
  Punkt aussen,
});

/// Bogenmaße der gewölbten Seiten von [stand] (`Rundungen.seitenboegen`).
List<Bogenmass> bogenmasse(Planungsstand stand) => [
  for (final MapEntry(key: seite, value: b)
      in stand.rundungen.seitenboegen(stand.grundriss).entries)
    if (b.start.gedreht(b.winkel / 2, b.mittelpunkt) case final scheitel)
      if ((scheitel - b.mittelpunkt).einheit case final d)
        (
          seite: seite,
          laenge: b.laenge,
          radius: b.radius,
          scheitel: scheitel,
          aussen: stand.kontur.enthaelt(scheitel + d * 10) ? d * -1 : d,
        ),
];

/// Was die Pläne über Umriss, Dielen und UK hinaus zeigen.
final class Planbild {
  Planbild({
    List<Strecke> stoesse = const [],
    this.achsen,
    List<Bogenmass> boegen = const [],
    List<Strecke> riegel = const [],
  }) : stoesse = List.unmodifiable(stoesse),
       boegen = List.unmodifiable(boegen),
       riegel = List.unmodifiable(riegel);

  /// Liest die Tabelle am Ort [ort] ([schreibe]).
  factory Planbild.lies(fb.BufferContext puffer, int ort) {
    List<Punkt> punkte(int platz) {
      final k = const fb.ListReader<double>(fb.Float64Reader())
          .vTableGet(puffer, ort, 4 + 2 * platz, const []);
      // Zählschleife mit i++ (docs/erkenntnisse/mutation-tests.md)
      return [
        for (var i = 0; i < k.length ~/ 2; i++) Punkt(k[2 * i], k[2 * i + 1]),
      ];
    }

    List<Strecke> strecken(int platz) {
      final enden = punkte(platz);
      return [
        for (var i = 0; i < enden.length ~/ 2; i++)
          (von: enden[2 * i], bis: enden[2 * i + 1]),
      ];
    }

    final marken = punkte(_markenPlatz);
    final normale = punkte(_normalePlatz);
    final boegen = const fb.ListReader<double>(fb.Float64Reader())
        .vTableGet(puffer, ort, 4 + 2 * _boegenPlatz, const []);
    return Planbild(
      stoesse: strecken(_stoessePlatz),
      achsen: marken.isEmpty ? null : Masskette(marken, normale.single),
      boegen: [
        for (var i = 0; i < boegen.length ~/ 7; i++)
          (
            seite: boegen[7 * i].round(),
            laenge: boegen[7 * i + 1],
            radius: boegen[7 * i + 2],
            scheitel: Punkt(boegen[7 * i + 3], boegen[7 * i + 4]),
            aussen: Punkt(boegen[7 * i + 5], boegen[7 * i + 6]),
          ),
      ],
      riegel: strecken(_riegelPlatz),
    );
  }

  /// Ohne Stöße und Achsmaßkette.
  static final leer = Planbild();

  /// Dielenstöße als Strecken quer über die Reihe (rot gestrichelt).
  final List<Strecke> stoesse;

  /// Achsmaßkette der UK; `null` ohne mindestens zwei UK-Linien.
  final Masskette? achsen;

  /// Maße der Bögen an den Seiten (Regel 14.1.3).
  final List<Bogenmass> boegen;

  /// Riegel am Bogen (Regel 14.2.3, `UkVerlegung.riegel`) – im UK-Plan
  /// grün umrandet.
  final List<Strecke> riegel;

  /// Schreibt `{ 0: stoesse ([float64] x, y von und bis je Stoß),
  /// 1: marken ([float64] x, y je Marke der Achsmaßkette), 2: normale
  /// ([float64] x, y; beide fehlen ohne Kette), 10: boegen ([float64]
  /// Seite, Länge, Radius, Scheitel x, y, außen x, y je Bogen), 11: riegel
  /// ([float64] x, y von und bis je Riegel) }`.
  int schreibe(fb.Builder fbb) {
    List<double> zahlen(List<Strecke> strecken) => [
      for (final s in strecken) ...[s.von.x, s.von.y, s.bis.x, s.bis.y],
    ];
    final stoesseOrt = fbb.writeListFloat64(zahlen(stoesse));
    final boegenOrt = fbb.writeListFloat64([
      for (final b in boegen) ...[
        b.seite.toDouble(),
        b.laenge,
        b.radius,
        b.scheitel.x,
        b.scheitel.y,
        b.aussen.x,
        b.aussen.y,
      ],
    ]);
    final riegelOrt = fbb.writeListFloat64(zahlen(riegel));
    final kette = achsen;
    final markenOrt = kette == null
        ? null
        : fbb.writeListFloat64([
            for (final m in kette.marken) ...[m.x, m.y],
          ]);
    final normaleOrt = kette == null
        ? null
        : fbb.writeListFloat64([kette.normale.x, kette.normale.y]);
    fbb
      ..startTable(_riegelPlatz + 1)
      ..addOffset(_stoessePlatz, stoesseOrt)
      ..addOffset(_markenPlatz, markenOrt)
      ..addOffset(_normalePlatz, normaleOrt)
      ..addOffset(_boegenPlatz, boegenOrt)
      ..addOffset(_riegelPlatz, riegelOrt);
    return fbb.endTable();
  }

  static const _stoessePlatz = 0;
  static const _markenPlatz = 1;
  static const _normalePlatz = 2;

  /// Plätze mit Abstand, damit andere Branches 3 … 9 nutzen können.
  static const _boegenPlatz = 10;
  static const _riegelPlatz = 11;
}

/// Ein Dielenende und der Anfang der nächsten Diele derselben Reihe liegen
/// höchstens so weit (mm) auseinander, dann ist dort ein Stoß.
const stossluecke = 10.0;

/// Stoßlinien des Verlegeplans (R-E01, Planungskern Regel 6.1): je
/// Teilfläche (die Stücke einer Liste in [teile]) und Reihe jede Stelle,
/// an der zwei Stücke stirnseitig aneinanderstoßen – als Strecke quer über
/// die gemeinsame Breite beider Stücke, mittig zwischen Ende und Anfang.
/// [winkel] ist die Verlegerichtung der Dielen in Grad.
List<Strecke> stosslinien(List<List<Dielenstueck>> teile, double winkel) {
  final drehung = -winkel * math.pi / 180;
  final linien = <Strecke>[];
  for (final stuecke in teile) {
    final reihen = <int, List<Huellrechteck>>{};
    for (final s in stuecke) {
      reihen
          .putIfAbsent(s.reihe, () => [])
          .add(
            Huellrechteck.um([for (final p in s.umriss) p.gedreht(drehung)]),
          );
    }
    for (final reihe in reihen.values) {
      reihe.sort((a, b) => a.min.x.compareTo(b.min.x));
      for (var i = 1; i < reihe.length; i++) {
        final (a, b) = (reihe[i - 1], reihe[i]);
        if (b.min.x - a.max.x > stossluecke) continue;
        final x = (a.max.x + b.min.x) / 2;
        linien.add((
          von: Punkt(x, math.max(a.min.y, b.min.y)).gedreht(-drehung),
          bis: Punkt(x, math.min(a.max.y, b.max.y)).gedreht(-drehung),
        ));
      }
    }
  }
  return linien;
}

/// Achsmaßkette des UK-Plans (R-E02, Planungskern Regel 6.1): quer zur UK
/// am Rand des [umriss] (in der Drehung der UK unten), Marken am Rand, an
/// jeder UK-Linie mit Holz und am anderen Rand. Unter zwei Linien `null`.
Masskette? achsmasskette(UkVerlegung uk, List<Punkt> umriss) {
  final drehung = -uk.winkel * math.pi / 180;
  final achsen = <double>{
    for (final l in uk.linien)
      if (l.abschnitte.isNotEmpty) l.x,
  }.toList()..sort();
  if (achsen.length < 2) return null;
  final huelle = Huellrechteck.um([for (final p in umriss) p.gedreht(drehung)]);
  final y = huelle.max.y;
  return Masskette([
    for (final x in [huelle.min.x, ...achsen, huelle.max.x])
      Punkt(x, y).gedreht(-drehung),
  ], const Punkt(0, 1).gedreht(-drehung));
}
