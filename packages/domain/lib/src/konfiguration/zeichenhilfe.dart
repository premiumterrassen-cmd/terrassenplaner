import 'dart:math' as math;

import '../artikel/einheiten.dart';
import '../geometrie/punkt.dart';

/// Hilfen beim Zeichnen einer Freiform (M4-08) – reine Eingabehilfen, die
/// App nutzt sie für die gesetzten Punkte. Winkel in Grad wie in der
/// Zeichnung: 0° nach rechts, 90° nach unten (y quer, nach unten).
abstract final class Zeichenhilfe {
  /// Rasterweite der Einrastfunktion: 10 cm.
  static const raster = Millimeter(100);

  /// Winkelschritt der Zeichnungshilfe.
  static const winkelschritt = 15.0;

  /// Einrastfunktion: [p] auf das nächste Rasterkreuz.
  static Punkt einrasten(Punkt p) {
    final r = raster.mm;
    return Punkt(
      (p.x / r).round() * r.toDouble(),
      (p.y / r).round() * r.toDouble(),
    );
  }

  /// Zeichnungshilfe: [nach] so drehen, dass die Strecke von [von] in einem
  /// Vielfachen von [winkelschritt] verläuft; die Länge bleibt.
  static Punkt ausrichten(Punkt von, Punkt nach) {
    final d = nach - von;
    final winkel =
        (winkelVon(von, nach) / winkelschritt).round() * winkelschritt;
    return streckenpunkt(von, d.laenge, winkel);
  }

  /// Punkt in [laenge] mm und [winkel] Grad von [von] (Maßeingabe
  /// „Strecke“).
  static Punkt streckenpunkt(Punkt von, double laenge, double winkel) {
    final b = winkel * math.pi / 180;
    return von + Punkt(math.cos(b), math.sin(b)) * laenge;
  }

  /// Winkel der Strecke von [von] nach [nach] in Grad (0 … 360).
  static double winkelVon(Punkt von, Punkt nach) =>
      ((nach - von).richtung * 180 / math.pi) % 360;
}
