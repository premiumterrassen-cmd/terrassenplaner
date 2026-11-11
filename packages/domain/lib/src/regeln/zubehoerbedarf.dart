/// Automatische Mengen im Schritt „Zubehör“ (M8-02, Fachkonzept 06) aus
/// Belag, Unterkonstruktion und Fläche. Die Artikel kommen aus den
/// Verweisen der Artikeldaten (B-122); Clips und Schrauben rechnet die
/// Befestigung (M5-09) – hier werden sie nur übernommen, nicht doppelt
/// gerechnet.
library;

import 'dart:math' as math;

import '../artikel/artikel.dart';
import '../artikel/einheiten.dart';
import '../konfiguration/dielenverlegung.dart';
import 'befestigungsbedarf.dart';
import 'feldbreite.dart';
import 'planungsregeln.dart';
import 'regelwerk.dart';
import 'uk_verlegung.dart';
import 'uk_zusatz.dart';

/// Eine Zeile im Schritt „Zubehör“: vom Planer berechnete Menge und die
/// Menge „Tatsächlich“ – eingegeben oder, ohne Eingabe, die berechnete
/// (R-D04) –, dazu die Menge an Pflichtzubehör (M8-03), unter die
/// „Tatsächlich“ nicht sinken kann. Mengen in Verkaufseinheiten.
final class Zubehoerposition {
  const Zubehoerposition(
    this.nummer, {
    this.berechnet = 0,
    int? menge,
    this.pflicht = 0,
  }) : menge = menge ?? berechnet;

  final Artikelnummer nummer;

  /// Vom Planer berechnete Menge.
  final int berechnet;

  /// Menge „Tatsächlich“.
  final int menge;

  /// Pflichtzubehör (M8-03): so viel ist mindestens nötig – nicht abwählbar.
  final int pflicht;

  /// Ob die Menge von der berechneten abweicht – dann erscheint im Angebot
  /// beides (Fachkonzept 06).
  bool get geaendert => menge != berechnet;

  @override
  bool operator ==(Object other) =>
      other is Zubehoerposition &&
      other.nummer == nummer &&
      other.berechnet == berechnet &&
      other.menge == menge &&
      other.pflicht == pflicht;

  @override
  int get hashCode => Object.hash(nummer, berechnet, menge, pflicht);

  @override
  String toString() =>
      '$nummer: $menge (berechnet $berechnet, Pflicht $pflicht)';
}

/// Berechnete Mengen des Zubehörs (M8-02) je Artikel in Verkaufseinheiten,
/// in dieser Reihenfolge:
///
/// - **Clips und Schrauben** samt Montagehilfe aus der [befestigung]
///   (M5-09, B-094, B-090) – unverändert übernommen.
/// - **Bits** ([bits], Planungsregeln Alexander (Planungskern v6,
///   11.11.2026) Regeln 4.2 und 4.3): TX20 zu den Clips, TX25 zu den
///   Schrauben – nur, wenn keine Packung mit Bit dabei ist.
/// - **Gummiband** (Pads & EPDM-Bänder, R-C04, B-039): das erste Band aus
///   dem Zubehör des Belags für die ganze Länge der Unterkonstruktion: die
///   Hölzer der UK-Verlegung [uk] (M6-10, `UkVerlegung.laenge`), ohne sie
///   die Übergangs-UK ([ukLaenge]) im Abstand der wirksamen [feldbreite]
///   (M6-09); die Rollen eines Kartons stehen im Titel („10 Rollen à
///   10 m“).
/// - **Terrassenöl** (RIBOL): die erste Sorte aus dem Zubehör des Belags,
///   [oelJeQuadratmeter] je m² Belagfläche der [stuecke] (R-D05), in ihren
///   Gebinden mit möglichst wenig Überhang ([verpackt]).
///
/// Clips und Schrauben zählt die Befestigung auf denselben UK-Hölzern
/// (`befestigungspunkteAufUk`).
Map<Artikelnummer, int> berechnetesZubehoer(
  Regelwerk regelwerk,
  Artikel belag,
  Befestigungsbedarf befestigung,
  List<Dielenstueck> stuecke, {
  required double winkel,
  Millimeter? feldbreite,
  UkVerlegung? uk,
}) {
  final zubehoer = regelwerk.moeglich(belag.nummer, Beziehung.zubehoer);
  final band = [
    for (final a in zubehoer)
      if (a.art == Artikelart.gummiband)
        if (_bandlaenge(a) case final je?) (a, je),
  ].firstOrNull;
  final holzart = belag.holzart;
  return {
    for (final m in befestigung.mittel) m.nummer: m.anzahl,
    for (final bit in bits(regelwerk, befestigung)) bit.nummer: 1,
    // Holzfliesen liegen ohne Unterkonstruktion
    if ((band, holzart) case ((final a, final je)?, final h?)
        when stuecke.isNotEmpty)
      a.nummer:
          ((uk?.laenge ??
                      ukLaenge(
                        stuecke,
                        winkel: winkel,
                        ukAbstand: wirksameFeldbreite(
                          feldbreite,
                          ukAbstandFuer(
                            h,
                            regelwerk.abstaende(belag.nummer).uk,
                          ),
                        ),
                      )) /
                  je)
              .ceil(),
    for (final (a, anzahl) in _oel(zubehoer, belagflaeche(stuecke)))
      a.nummer: anzahl,
  };
}

/// Zeilen „Tatsächlich“ aus den [berechnet]en Mengen, den [eingaben] des
/// Kunden (M8-01) und dem [pflicht]-Zubehör (M8-03): zuerst die
/// berechneten Artikel, dann das Pflichtzubehör, dann die nur eingegebenen.
/// Das Pflichtzubehör zählt zur berechneten Menge und ist nicht abwählbar –
/// eine kleinere Eingabe gilt als Pflichtmenge. Artikel ohne Menge und ohne
/// Berechnung fehlen.
List<Zubehoerposition> zubehoerpositionen(
  Map<Artikelnummer, int> berechnet,
  Map<Artikelnummer, int> eingaben, {
  Map<Artikelnummer, int> pflicht = const {},
}) => [
  for (final nummer in {...berechnet.keys, ...pflicht.keys, ...eingaben.keys})
    if (_position(nummer, berechnet, eingaben, pflicht[nummer] ?? 0)
        case final p when p.berechnet > 0 || p.menge > 0)
      p,
];

Zubehoerposition _position(
  Artikelnummer nummer,
  Map<Artikelnummer, int> berechnet,
  Map<Artikelnummer, int> eingaben,
  int pflicht,
) {
  final summe = (berechnet[nummer] ?? 0) + pflicht;
  return Zubehoerposition(
    nummer,
    berechnet: summe,
    menge: math.max(eingaben[nummer] ?? summe, pflicht),
    pflicht: pflicht,
  );
}

/// Pflichtzubehör (M8-03): benötigtes Zubehör mit fester Anzahl je Artikel
/// aus der Upload-Datei (`benoetigtesZubehoer`, B-122) für die [verwendet]en
/// Artikel (Anzahl je Artikel). Was ein Pflichtartikel selbst braucht,
/// kommt dazu – höchstens [_stufen] Stufen tief, damit ein Kreis in den
/// Daten nicht endlos rechnet. Unbekannte Artikel haben keins.
Map<Artikelnummer, int> pflichtzubehoer(
  Regelwerk regelwerk,
  Map<Artikelnummer, int> verwendet,
) {
  final summe = <Artikelnummer, int>{};
  var stufe = verwendet;
  for (var i = 0; i < _stufen; i++) {
    final neu = <Artikelnummer, int>{};
    for (final MapEntry(key: nummer, value: anzahl) in stufe.entries) {
      if (regelwerk.datei[nummer] == null) continue;
      for (final MapEntry(key: z, value: je)
          in regelwerk.pflichtzubehoer(nummer).entries) {
        neu.update(
          z.nummer,
          (n) => n + je * anzahl,
          ifAbsent: () => je * anzahl,
        );
      }
    }
    for (final MapEntry(:key, :value) in neu.entries) {
      summe.update(key, (n) => n + value, ifAbsent: () => value);
    }
    stufe = neu;
  }
  return summe;
}

/// Stufen des Pflichtzubehörs (Pflichtartikel eines Pflichtartikels …).
const _stufen = 5;

/// Fläche des Belags in m²: je Stück Länge mal Breite samt Fuge – die
/// Terrassenfläche, auf die sich der Ölverbrauch bezieht (R-D05).
double belagflaeche(List<Dielenstueck> stuecke) =>
    stuecke.fold(0.0, (summe, s) => summe + s.laenge.mm * s.breite) / 1e6;

/// Bandlänge je Verkaufseinheit in mm: Rollenlänge ([Abmessungen.laengste])
/// mal Rollen im Karton laut Titel; ohne Rollenlänge `null`.
int? _bandlaenge(Artikel band) {
  final rolle = band.abmessungen.laengste;
  if (rolle == null) return null;
  final rollen = RegExp(r'(\d+)\s*Rollen').firstMatch(band.titel);
  return rolle.mm * (rollen == null ? 1 : int.parse(rollen.group(1)!));
}

/// Inhalt eines Ölgebindes laut Titel („2,5 Liter“) und die Sorte (der
/// Titel davor); `null` ohne Literangabe.
({String sorte, int zentiliter})? _gebinde(Artikel a) {
  final treffer = RegExp(r'(\d+(?:,\d+)?)\s*Liter').firstMatch(a.titel);
  if (treffer == null) return null;
  final liter = double.parse(treffer.group(1)!.replaceFirst(',', '.'));
  return (
    sorte: a.titel
        .substring(0, treffer.start)
        .replaceFirst(RegExp(r'[\s,]+$'), ''),
    zentiliter: (liter * 100).round(),
  );
}

/// Gebinde der ersten Ölsorte für [quadratmeter] Belagfläche.
List<(Artikel, int)> _oel(List<Artikel> zubehoer, double quadratmeter) {
  final oele = [
    for (final a in zubehoer)
      if (a.art == Artikelart.pflege)
        if (_gebinde(a) case final g?) (a, g),
  ];
  if (oele.isEmpty) return const [];
  final sorte = oele.first.$2.sorte;
  final gebinde = [
    for (final (a, g) in oele)
      if (g.sorte == sorte) a,
  ];
  return verpackt(
    (quadratmeter * oelJeQuadratmeter * 100).ceil(),
    gebinde,
    inhalt: (a) => _gebinde(a)!.zentiliter,
  );
}

/// Bits zur [befestigung] (Planungsregeln Alexander (Planungskern v6,
/// 11.11.2026) Regeln 4.2 und 4.3), je eines:
///
/// - **TX20** zu Clips, wenn keine Clip-Packung mit Bit dabei ist –
///   CLIP-FIXX ab VPE [clipBitAbVpe], DUO-CLIP-FIXX ab [duoClipBitAbVpe];
/// - **TX25** zu Schrauben (Verschraubung von oben, Anfangs- und Enddiele),
///   wenn kein Schraubenset ab [schraubenBitAbVpe] Stück (mit Bit) dabei ist.
///
/// Ob eine Packung ein Bit enthält, führen die Artikeldaten nicht; es folgt
/// aus der Packungsgröße. Gezählt wird je Fläche, das Werkzeug geht einmal
/// je Planung in die Materialliste. Die Bits sind die ersten
/// Werkzeug-Artikel mit „Bit TX20“ bzw. „Bit TX25“ im Titel – die
/// Upload-Datei kennt keine Beziehung Befestigung → Bit.
List<Artikel> bits(Regelwerk regelwerk, Befestigungsbedarf befestigung) {
  final packungen = [
    for (final b in befestigung.bedarf)
      for (final (a, _) in verpackt(b.stueck, b.einheiten)) a,
  ];
  final clips = packungen.where((a) => a.art == Artikelart.clip);
  final schrauben = packungen.where((a) => a.art == Artikelart.schraube);
  return [
    if (clips.isNotEmpty && !clips.any(_clipMitBit))
      ?_werkzeug(regelwerk, 'Bit TX20'),
    if (schrauben.isNotEmpty &&
        !schrauben.any((a) => a.einheit.inhalt >= schraubenBitAbVpe))
      ?_werkzeug(regelwerk, 'Bit TX25'),
  ];
}

/// Ob die Clip-Packung [a] ein Bit enthält (Planungskern v6 Regel 4.2).
bool _clipMitBit(Artikel a) =>
    a.einheit.inhalt >= (istDuoClip(a) ? duoClipBitAbVpe : clipBitAbVpe);

/// Erster Werkzeug-Artikel mit [titel] im Titel.
Artikel? _werkzeug(Regelwerk regelwerk, String titel) => regelwerk
    .datei
    .eintraege
    .map((e) => e.artikel)
    .where((a) => a.art == Artikelart.werkzeug && a.titel.contains(titel))
    .firstOrNull;

/// Länge der Unterkonstruktion unter den [stuecke]n in mm (M8-02): je
/// Linie der Übergangs-UK (`uebergangsUk`) die Strecke quer zur
/// Verlegerichtung, die Dielen überdecken; Fugen bis [_luecke] werden
/// überbrückt (die UK läuft unter der Fuge durch). F01: 13 × 309 cm.
double ukLaenge(
  List<Dielenstueck> stuecke, {
  required double winkel,
  required Millimeter ukAbstand,
}) {
  final uk = uebergangsUk(stuecke, winkel: winkel, ukAbstand: ukAbstand);
  var summe = 0.0;
  for (final x in uk.linien) {
    final quer = [
      for (final l in uk.lagen)
        if (l.anfang <= x + _luecke && l.ende >= x - _luecke) (l.unten, l.oben),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    var bis = double.negativeInfinity;
    for (final (unten, oben) in quer) {
      // neue Strecke nach einer Lücke, sonst bis zum neuen oberen Ende
      summe += unten > bis + _luecke ? oben - unten : math.max(0, oben - bis);
      bis = math.max(bis, oben);
    }
  }
  return summe;
}

/// Größte Lücke quer zur Verlegerichtung, die die UK überbrückt: die Fuge
/// (R-B06) mit etwas Spiel für gerundete Umrisse.
final _luecke = fuge.mm * 2.0;
