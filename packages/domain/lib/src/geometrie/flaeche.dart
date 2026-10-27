import 'dart:math' as math;

import 'kontur.dart';
import 'mengen.dart';
import 'punkt.dart';

/// Kleinste Fläche in mm², die als Überschneidung zählt (M4-01).
const flaechenToleranz = 1.0;

/// Zusammenhängende Fläche: äußere [kontur] ohne die [loecher] (M4-01).
/// Löcher liegen innerhalb der Kontur und überschneiden sich nicht.
final class Flaeche {
  Flaeche(this.kontur, [List<Kontur> loecher = const []])
    : loecher = List.unmodifiable(loecher);

  final Kontur kontur;
  final List<Kontur> loecher;

  /// Fläche in mm² ohne Löcher.
  double get flaeche =>
      loecher.fold(kontur.flaeche, (summe, loch) => summe - loch.flaeche);

  /// Länge aller Ränder (außen und Löcher) in mm.
  double get umfang =>
      loecher.fold(kontur.umfang, (summe, loch) => summe + loch.umfang);

  Iterable<Kontur> get _raender => [kontur, ...loecher];

  bool enthaelt(Punkt p) =>
      kontur.enthaelt(p) && !loecher.any((loch) => loch.enthaelt(p));

  double abstandZumRand(Punkt p) => _raender.fold(
    double.infinity,
    (m, r) => math.min(m, r.abstandZumRand(p)),
  );

  Huellrechteck get huellrechteck => kontur.huellrechteck;

  Flaeche verschoben(Punkt v) => Flaeche(kontur.verschoben(v), [
    for (final loch in loecher) loch.verschoben(v),
  ]);

  /// Um [winkel] (Grad, gegen den Uhrzeigersinn) um [mitte] gedreht.
  Flaeche gedreht(double winkel, [Punkt mitte = Punkt.ursprung]) => Flaeche(
    kontur.gedreht(winkel, mitte),
    [for (final loch in loecher) loch.gedreht(winkel, mitte)],
  );

  /// Ränder als Sehnenzüge für die Mengenoperationen.
  List<List<Punkt>> get sehnenzuege => [for (final r in _raender) r.vieleck()];

  /// Vereinigung; mehrere Teile, wenn die Flächen getrennt liegen.
  List<Flaeche> vereinigt(Flaeche andere) =>
      verknuepfe([this], [andere], Verknuepfung.vereinigung);

  /// Schnittmenge; leer, wenn sich die Flächen nicht überschneiden.
  List<Flaeche> geschnitten(Flaeche andere) =>
      verknuepfe([this], [andere], Verknuepfung.schnitt);

  /// Diese Fläche ohne [andere]; mehrere Teile, wenn [andere] sie teilt.
  List<Flaeche> ohne(Flaeche andere) =>
      verknuepfe([this], [andere], Verknuepfung.differenz);

  /// Überschneiden sich die Flächen um mehr als [flaechenToleranz]?
  /// Berührung an Rand oder Ecke zählt nicht.
  bool ueberschneidet(Flaeche andere) =>
      gesamtflaeche(geschnitten(andere)) > flaechenToleranz;

  /// Liegt [andere] vollständig in dieser Fläche (Rand eingeschlossen)?
  bool umschliesst(Flaeche andere) =>
      gesamtflaeche(andere.ohne(this)) < flaechenToleranz;

  /// Kürzester Abstand der Ränder in mm; 0 bei Überschneidung.
  double abstand(Flaeche andere) {
    if (ueberschneidet(andere)) return 0;
    var minimum = double.infinity;
    for (final a in sehnenzuege) {
      for (final b in andere.sehnenzuege) {
        minimum = math.min(minimum, _zugAbstand(a, b));
      }
    }
    return minimum;
  }
}

/// Summe der Flächen in mm².
double gesamtflaeche(Iterable<Flaeche> flaechen) =>
    flaechen.fold(0, (summe, f) => summe + f.flaeche);

double _zugAbstand(List<Punkt> a, List<Punkt> b) {
  var minimum = double.infinity;
  for (var i = 0, vorI = a.length - 1; i < a.length; vorI = i++) {
    for (var j = 0, vorJ = b.length - 1; j < b.length; vorJ = j++) {
      minimum = math.min(
        minimum,
        streckenAbstand(a[vorI], a[i], b[vorJ], b[j]),
      );
    }
  }
  return minimum;
}
