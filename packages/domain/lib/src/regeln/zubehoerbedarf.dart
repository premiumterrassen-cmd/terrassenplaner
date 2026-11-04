/// Automatische Mengen im Schritt „Zubehör“ (M8-02, Fachkonzept 06) aus
/// Belag, Unterkonstruktion und Fläche. Die Artikel kommen aus den
/// Verweisen der Artikeldaten (B-122); Clips und Schrauben rechnet die
/// Befestigung (M5-09) – hier werden sie nur übernommen, nicht doppelt
/// gerechnet.
library;

import 'dart:math' as math;

import '../artikel/artikel.dart';
import '../artikel/einheiten.dart';
import '../konfiguration/befestigungsart.dart';
import '../konfiguration/dielenverlegung.dart';
import 'befestigungsbedarf.dart';
import 'planungsregeln.dart';
import 'regelwerk.dart';

/// Eine Zeile im Schritt „Zubehör“: vom Planer berechnete Menge und die
/// Menge „Tatsächlich“ – eingegeben oder, ohne Eingabe, die berechnete
/// (R-D04). Mengen in Verkaufseinheiten.
final class Zubehoerposition {
  const Zubehoerposition(this.nummer, {this.berechnet = 0, int? menge})
    : menge = menge ?? berechnet;

  final Artikelnummer nummer;

  /// Vom Planer berechnete Menge.
  final int berechnet;

  /// Menge „Tatsächlich“.
  final int menge;

  /// Ob die Menge von der berechneten abweicht – dann erscheint im Angebot
  /// beides (Fachkonzept 06).
  bool get geaendert => menge != berechnet;

  @override
  bool operator ==(Object other) =>
      other is Zubehoerposition &&
      other.nummer == nummer &&
      other.berechnet == berechnet &&
      other.menge == menge;

  @override
  int get hashCode => Object.hash(nummer, berechnet, menge);

  @override
  String toString() => '$nummer: $menge (berechnet $berechnet)';
}

/// Berechnete Mengen des Zubehörs (M8-02) je Artikel in Verkaufseinheiten,
/// in dieser Reihenfolge:
///
/// - **Clips und Schrauben** samt Montagehilfe aus der [befestigung]
///   (M5-09, B-094, B-090) – unverändert übernommen.
/// - **Bit TX25** (Allgemein): eines bei Verschraubung, wie im alten Planer
///   (F24); bei Clips nicht (F01).
/// - **Gummiband** (Pads & EPDM-Bänder, R-C04, B-039): das erste Band aus
///   dem Zubehör des Belags für die ganze Länge der Unterkonstruktion
///   ([ukLaenge]); die Rollen eines Kartons stehen im Titel („10 Rollen à
///   10 m“).
/// - **Terrassenöl** (RIBOL): die erste Sorte aus dem Zubehör des Belags,
///   [oelJeQuadratmeter] je m² Belagfläche der [stuecke] (R-D05), in ihren
///   Gebinden mit möglichst wenig Überhang ([verpackt]).
///
/// Solange die Unterkonstruktion fehlt (M6), liegt sie wie bei der
/// Befestigung gleichmäßig im Abstand der Artikeldaten (`uebergangsUk`).
Map<Artikelnummer, int> berechnetesZubehoer(
  Regelwerk regelwerk,
  Artikel belag,
  Befestigungsbedarf befestigung,
  List<Dielenstueck> stuecke, {
  required double winkel,
}) {
  final zubehoer = regelwerk.moeglich(belag.nummer, Beziehung.zubehoer);
  final verschraubt =
      befestigung.art != null && befestigung.art != Befestigungsart.clips;
  final band = [
    for (final a in zubehoer)
      if (a.art == Artikelart.gummiband)
        if (_bandlaenge(a) case final je?) (a, je),
  ].firstOrNull;
  final holzart = belag.holzart;
  final bit = verschraubt ? _bit(regelwerk) : null;
  return {
    for (final m in befestigung.mittel) m.nummer: m.anzahl,
    if (bit != null) bit.nummer: 1,
    // Holzfliesen liegen ohne Unterkonstruktion
    if ((band, holzart) case ((final a, final je)?, final h?)
        when stuecke.isNotEmpty)
      a.nummer:
          (ukLaenge(
                    stuecke,
                    winkel: winkel,
                    ukAbstand: ukAbstandFuer(regelwerk, belag, h),
                  ) /
                  je)
              .ceil(),
    for (final (a, anzahl) in _oel(zubehoer, belagflaeche(stuecke)))
      a.nummer: anzahl,
  };
}

/// Zeilen „Tatsächlich“ aus den [berechnet]en Mengen und den [eingaben]
/// des Kunden (M8-01): zuerst die berechneten Artikel, dann die nur
/// eingegebenen. Artikel ohne Menge und ohne Berechnung fehlen.
List<Zubehoerposition> zubehoerpositionen(
  Map<Artikelnummer, int> berechnet,
  Map<Artikelnummer, int> eingaben,
) => [
  for (final nummer in {...berechnet.keys, ...eingaben.keys})
    if (Zubehoerposition(
          nummer,
          berechnet: berechnet[nummer] ?? 0,
          menge: eingaben[nummer],
        )
        case final p when p.berechnet > 0 || p.menge > 0)
      p,
];

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

/// Bit TX25 aus den Artikeldaten: der erste Werkzeug-Artikel mit „Bit TX25“
/// im Titel – die Upload-Datei kennt keine Beziehung Schraube → Bit.
Artikel? _bit(Regelwerk regelwerk) => regelwerk.datei.eintraege
    .map((e) => e.artikel)
    .where((a) => a.art == Artikelart.werkzeug && a.titel.contains('Bit TX25'))
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
