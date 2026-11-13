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
import '../regeln/rinnen.dart';
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

  /// Die Zahlen der Kette (`kettenzahlen`); [platz] ist der Platz längs der
  /// Kette in mm, den ein Text im Maßstab der Zeichnung braucht.
  List<Kettenzahl> zahlen(double Function(String text) platz) =>
      kettenzahlen(abstaende, platz);
}

/// Abstände unter dieser Länge (mm) bekommen keine Zahl – etwa zwischen
/// den Hölzern einer Doppel-UK; die Marken stehen trotzdem.
const kleinsterAchsabstand = 100.0;

/// Eine Zahl der Achsmaßkette (R-E02): sie steht mittig zwischen den Marken
/// [von] und [bis] (Indizes der Marken) – eine Zahl je Abstand, oder bei
/// mehreren gleichen Abständen in Folge zusammengefasst („12 × 40“).
typedef Kettenzahl = ({int von, int bis, String text});

/// Zahlen einer Maßkette mit den [abstaende]n (mm) in cm, nie übereinander
/// (Planungsregeln Alexander (Planungskern v10, 12.11.2026), Regel 12.1
/// „Beschriftung ohne Überlappung“; bei 25 m Kantenlänge liefen die 40er
/// sonst ineinander). [platz] ist der Platz längs der Kette, den ein Text
/// im Maßstab der Zeichnung braucht (mm, mit Rand) – App und PDF kennen
/// ihren Maßstab und ihre Schrift:
///
/// 1. Abstände unter [kleinsterAchsabstand] bekommen keine Zahl.
/// 2. Passt jede Zahl in ihren Abstand, steht jede einzeln (38 / 40 / 40 …).
/// 3. Sonst werden gleiche Abstände in Folge zusammengefasst
///    („38 · 61 × 40 · 22“).
/// 4. Würde eine Zahl dann noch die vorige berühren, entfällt sie.
List<Kettenzahl> kettenzahlen(
  List<double> abstaende,
  double Function(String text) platz,
) {
  final cm = [for (final d in abstaende) '${(d / 10).round()}'];
  final einzeln = <Kettenzahl>[
    for (var i = 0; i < abstaende.length; i++)
      if (abstaende[i] >= kleinsterAchsabstand)
        (von: i, bis: i + 1, text: cm[i]),
  ];
  final zahlen = einzeln.every((z) => platz(z.text) <= abstaende[z.von])
      ? einzeln
      : _zusammengefasst(einzeln);
  final lagen = [0.0];
  for (final d in abstaende) {
    lagen.add(lagen.last + d);
  }
  final gesetzt = <Kettenzahl>[];
  var frei = double.negativeInfinity;
  for (final z in zahlen) {
    final mitte = (lagen[z.von] + lagen[z.bis]) / 2;
    final halb = platz(z.text) / 2;
    if (mitte - halb < frei) continue;
    gesetzt.add(z);
    frei = mitte + halb;
  }
  return gesetzt;
}

/// Die Zahlen [einzeln] mit gleichen, aneinandergrenzenden Abständen
/// zusammengefasst: „n × Abstand“ von der ersten bis zur letzten Marke.
List<Kettenzahl> _zusammengefasst(List<Kettenzahl> einzeln) {
  final gruppen = <List<Kettenzahl>>[];
  for (final z in einzeln) {
    final letzte = gruppen.lastOrNull?.last;
    if (letzte != null && letzte.bis == z.von && letzte.text == z.text) {
      gruppen.last.add(z);
    } else {
      gruppen.add([z]);
    }
  }
  return [
    for (final g in gruppen)
      (
        von: g.first.von,
        bis: g.last.bis,
        text: g.length == 1 ? g.first.text : '${g.length} × ${g.first.text}',
      ),
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

/// Band einer Entwässerungsrinne RELO V im Plan (Planungsregeln Alexander,
/// Planungskern v11, Regel 13.1.6, R-E07): die [ecken] außen an der Kante
/// von – bis, dann innen bis – von, [rinnenprofilbreite] breit.
final class Rinnenband {
  Rinnenband(List<Punkt> ecken) : ecken = List.unmodifiable(ecken) {
    if (ecken.length != 4) {
      throw ArgumentError.value(ecken, 'ecken', 'genau vier Ecken');
    }
  }

  /// Band innen an der Rinnenkante [k]; ohne [belag] ein Rechteck.
  ///
  /// [belag] sind die Ecken des Belags (`belagstand`), dort enden die
  /// Dielen [rinnenabstand] vor der Kante. Die beiden versetzten Ecken der
  /// Seite liegen auf den Nachbarseiten – bei einem Bogen auf seinem Kreis
  /// (Planungskern v22/v23, Rinne neben Bogen). Das Band reicht innen bis
  /// dorthin (anteilig: Profil ohne Fuge) und wird so zum Trapez, statt
  /// als Rechteck vor dem Bogen zu enden.
  factory Rinnenband.an(Rinnenkante k, [List<Punkt>? belag]) {
    final innen = k.innen * rinnenprofilbreite.mm.toDouble();
    if (belag == null) {
      return Rinnenband([k.von, k.bis, k.bis + innen, k.von + innen]);
    }
    final anteil = rinnenprofilbreite.mm / rinnenabstand.mm;
    final von = belag[k.seite];
    final bis = belag[(k.seite + 1) % belag.length];
    return Rinnenband([
      k.von,
      k.bis,
      k.bis + (bis - k.bis) * anteil,
      k.von + (von - k.von) * anteil,
    ]);
  }

  final List<Punkt> ecken;

  /// Länge der Rinne in mm.
  double get laenge => ecken[0].abstand(ecken[1]);

  /// Mitte des Bandes – dort steht das Etikett „Rinne RELO V“.
  Punkt get mitte => (ecken[0] + ecken[2]) * 0.5;

  /// Strecke längs des Bandes im Abstand [abstand] (mm) von der Kante.
  Strecke _laengs(double abstand) {
    final t = abstand / rinnenprofilbreite.mm;
    return (
      von: ecken[0] + (ecken[3] - ecken[0]) * t,
      bis: ecken[1] + (ecken[2] - ecken[1]) * t,
    );
  }

  /// Die beiden Auflagerprofile RELO VA unter dem Profil, je
  /// [auflagerprofilRand] vom Rand des Bandes (UK-Plan).
  List<Strecke> get auflagerprofile => [
    _laengs(auflagerprofilRand),
    _laengs(rinnenprofilbreite.mm - auflagerprofilRand),
  ];

  /// Schlitze des Profils quer zur Kante alle [schlitzabstand] mm, je
  /// [schlitzrand] vom Rand des Bandes (Verlegeplan).
  List<Strecke> get schlitze {
    final (a, b) = (
      _laengs(schlitzrand),
      _laengs(rinnenprofilbreite.mm - schlitzrand),
    );
    final n = (laenge / schlitzabstand).floor();
    return [
      for (var i = 1; i < n; i++)
        if (i / n case final t)
          (von: a.von + (a.bis - a.von) * t, bis: b.von + (b.bis - b.von) * t),
    ];
  }
}

/// Rinnenbänder der [kanten] von [stand] (R-E07): innen bis an den Belag
/// des `belagstand` – neben einem Bogen bis an die auf den Kreis
/// gerutschte Ecke (`Rinnenband.an`).
List<Rinnenband> rinnenbaender(Planungsstand stand, List<Rinnenkante> kanten) {
  if (kanten.isEmpty) return const [];
  final belag = belagstand(stand, kanten).grundriss.ecken;
  return [for (final k in kanten) Rinnenband.an(k, belag)];
}

/// Abstand der Auflagerprofile vom Rand des Rinnenbandes in mm.
const auflagerprofilRand = 25.0;

/// Abstand der Schlitze im Rinnenband in mm.
const schlitzabstand = 50.0;

/// Abstand der Schlitze vom Rand des Rinnenbandes in mm.
const schlitzrand = 35.0;

/// Was die Pläne über Umriss, Dielen und UK hinaus zeigen.
final class Planbild {
  Planbild({
    List<Strecke> stoesse = const [],
    this.achsen,
    List<Bogenmass> boegen = const [],
    List<Strecke> riegel = const [],
    List<Rinnenband> rinnen = const [],
  }) : stoesse = List.unmodifiable(stoesse),
       boegen = List.unmodifiable(boegen),
       riegel = List.unmodifiable(riegel),
       rinnen = List.unmodifiable(rinnen);

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
    final rinnen = punkte(_rinnenPlatz);
    final boegen = const fb.ListReader<double>(fb.Float64Reader())
        .vTableGet(puffer, ort, 4 + 2 * _boegenPlatz, const []);
    return Planbild(
      rinnen: [
        for (var i = 0; i < rinnen.length ~/ 4; i++)
          Rinnenband(rinnen.sublist(4 * i, 4 * i + 4)),
      ],
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

  /// Entwässerungsrinnen (R-E07) im Verlegeplan und im UK-Plan.
  final List<Rinnenband> rinnen;

  /// Schreibt `{ 0: stoesse ([float64] x, y von und bis je Stoß),
  /// 1: marken ([float64] x, y je Marke der Achsmaßkette), 2: normale
  /// ([float64] x, y; beide fehlen ohne Kette), 3: rinnen ([float64] x, y
  /// der vier Ecken je Rinnenband, Planungskern v11), 10: boegen
  /// ([float64] Seite, Länge, Radius, Scheitel x, y, außen x, y je Bogen,
  /// Planungskern v12), 11: riegel ([float64] x, y von und bis je Riegel) }`.
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
    final rinnenOrt = rinnen.isEmpty
        ? null
        : fbb.writeListFloat64([
            for (final r in rinnen)
              for (final e in r.ecken) ...[e.x, e.y],
          ]);
    fbb
      ..startTable(_riegelPlatz + 1)
      ..addOffset(_stoessePlatz, stoesseOrt)
      ..addOffset(_markenPlatz, markenOrt)
      ..addOffset(_normalePlatz, normaleOrt)
      ..addOffset(_rinnenPlatz, rinnenOrt)
      ..addOffset(_boegenPlatz, boegenOrt)
      ..addOffset(_riegelPlatz, riegelOrt);
    return fbb.endTable();
  }

  static const _stoessePlatz = 0;
  static const _markenPlatz = 1;
  static const _normalePlatz = 2;
  static const _rinnenPlatz = 3;

  /// Plätze mit Abstand, damit andere Branches 4 … 9 nutzen können.
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
