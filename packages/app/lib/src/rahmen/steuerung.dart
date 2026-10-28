import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Planungsstände mit Rückgängig, Wiederherstellen und Zurücksetzen
/// (M3-03) für die Oberfläche.
class PlanungsSteuerung extends ChangeNotifier {
  PlanungsSteuerung([Planungsstand anfang = Planungsstand.start])
    : _verlauf = Verlauf(anfang);

  final Verlauf<Planungsstand> _verlauf;

  Planungsstand get aktuell => _verlauf.aktuell;
  bool get kannRueckgaengig => _verlauf.kannRueckgaengig;
  bool get kannWiederherstellen => _verlauf.kannWiederherstellen;

  void setze(Planungsstand stand) {
    _verlauf.setze(stand);
    notifyListeners();
  }

  /// Ersetzt den aktuellen Stand ohne neuen Rückgängig-Schritt (Ziehen,
  /// M4-09).
  void ersetze(Planungsstand stand) {
    _verlauf.ersetze(stand);
    notifyListeners();
  }

  void rueckgaengig() {
    _verlauf.rueckgaengig();
    notifyListeners();
  }

  void wiederherstellen() {
    _verlauf.wiederherstellen();
    notifyListeners();
  }

  /// Neue Planung mit der Startkonfiguration – nur nach Bestätigung aufrufen.
  void zuruecksetzen() {
    _verlauf.zuruecksetzen(Planungsstand.start);
    notifyListeners();
  }
}

/// Zoom und Verschiebung der Zeichenfläche (M3-03); kein Teil der Planung,
/// daher nicht im Verlauf.
class AnsichtSteuerung extends TransformationController {
  AnsichtSteuerung();

  static const kleinsterZoom = 0.25;
  static const groessterZoom = 4.0;

  /// Faktor je Klick auf + oder −.
  static const schritt = 1.25;

  /// Größe der Zeichenfläche – Mittelpunkt für Zoom per Knopf und Regler.
  Size flaeche = Size.zero;

  double get zoom => value.getMaxScaleOnAxis();

  Offset get verschiebung {
    final t = value.getTranslation();
    return Offset(t.x, t.y);
  }

  /// Zoomt auf [neu] (begrenzt) um die Mitte der Zeichenfläche.
  void zoomeAuf(double neu) {
    final ziel = neu.clamp(kleinsterZoom, groessterZoom);
    final mitte = flaeche.center(Offset.zero);
    final faktor = ziel / zoom;
    final v = verschiebung;
    final neuVerschoben = mitte - (mitte - v) * faktor;
    value = Matrix4.identity()
      ..translateByDouble(neuVerschoben.dx, neuVerschoben.dy, 0, 1)
      ..scaleByDouble(ziel, ziel, ziel, 1);
  }

  void vergroessern() => zoomeAuf(zoom * schritt);
  void verkleinern() => zoomeAuf(zoom / schritt);

  /// Zoom 100 % und Ursprung oben links.
  void zentriere() => value = Matrix4.identity();

  /// „Zentrieren“ (M4-10): Zoom 100 %, die Mitte von [mm] (Zeichnung in mm,
  /// [pixelJeMm] Pixel je mm) in der Mitte der Zeichenfläche.
  void zentriereAuf(Rect mm, double pixelJeMm) {
    final mitte = flaeche.center(Offset.zero) - mm.center * pixelJeMm;
    value = Matrix4.identity()..translateByDouble(mitte.dx, mitte.dy, 0, 1);
  }

  /// Zoom als Prozent, z. B. „125 %“.
  String get prozent => '${(zoom * 100).round()} %';

  /// Logarithmische Lage des Zooms zwischen kleinstem und größtem (0 … 1) –
  /// für den Regler.
  double get reglerWert =>
      math.log(zoom / kleinsterZoom) / math.log(groessterZoom / kleinsterZoom);

  void setzeReglerWert(double wert) =>
      zoomeAuf(kleinsterZoom * math.pow(groessterZoom / kleinsterZoom, wert));
}
