import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../sprache/sprache.dart';
import 'steuerung.dart';
import 'zeichnung.dart';

/// Vorschau beim Zeichnen der Freiform (#128): eine Linie vom letzten Punkt
/// zu dem Ort, an dem der nächste Punkt landen würde, mit Zielkreis und
/// Live-Maß (Länge, Winkel). So sieht man vor dem Klick, wo Zeichnungshilfe
/// und Raster fangen.
class VorschauMaler extends CustomPainter {
  VorschauMaler({
    required this.ansicht,
    required this.zeiger,
    required this.letzter,
    required this.ziel,
    required this.sprache,
    required this.farbe,
  }) : super(repaint: Listenable.merge([ansicht, zeiger]));

  final AnsichtSteuerung ansicht;

  /// Mausposition in mm, `null` = Maus außerhalb.
  final ValueListenable<Punkt?> zeiger;

  /// Letzter gesetzter Punkt, `null` = noch keiner.
  final Punkt? letzter;

  /// Wohin ein Punkt an der Maus fiele (dieselbe Regel wie beim Setzen).
  final Punkt Function(Punkt ort) ziel;

  final PlanerTexte sprache;
  final Color farbe;

  /// Radius des Zielkreises in Bildschirmpunkten.
  static const kreis = 5.0;

  Offset _schirm(Punkt p) =>
      ansicht.verschiebung + Offset(p.x, p.y) * (pixelJeMm * ansicht.zoom);

  /// Text des Live-Maßes von [von] nach [nach]: Länge in cm und Winkel.
  String mass(Punkt von, Punkt nach) {
    final cm = zahlText(sprache, (nach - von).laenge.round() / 10, '0.#');
    final grad = zahlText(sprache, Zeichenhilfe.winkelVon(von, nach), '0.#');
    return '$cm cm · $grad°';
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ort = zeiger.value;
    if (ort == null) return;
    final p = ziel(ort);
    final punkt = _schirm(p);
    final stift = Paint()
      ..color = farbe
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(punkt, kreis, stift);
    final von = letzter;
    if (von == null) return;
    canvas.drawLine(_schirm(von), punkt, stift);
    TextPainter(
        text: TextSpan(
          text: mass(von, p),
          style: TextStyle(fontSize: 12, color: farbe),
        ),
        textDirection: TextDirection.ltr,
      )
      ..layout()
      ..paint(canvas, punkt + const Offset(kreis * 2, kreis * 2));
  }

  @override
  bool shouldRepaint(VorschauMaler alt) =>
      alt.letzter != letzter ||
      alt.farbe != farbe ||
      alt.sprache != sprache ||
      alt.ziel != ziel;
}
