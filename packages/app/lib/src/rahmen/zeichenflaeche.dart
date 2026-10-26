import 'package:flutter/material.dart';

import '../design/planer_design.dart';
import 'steuerung.dart';

/// Zeichenfläche (M3-03): Raster, Zoom mit Mausrad oder Regler, Verschieben
/// mit der Maus; darunter die Werkzeugleiste. Gezeichnet wird ab M4.
class Zeichenflaeche extends StatelessWidget {
  const Zeichenflaeche({
    required this.planung,
    required this.ansicht,
    super.key,
  });

  final PlanungsSteuerung planung;
  final AnsichtSteuerung ansicht;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: LayoutBuilder(
          builder: (context, raum) {
            ansicht.flaeche = raum.biggest;
            return ColoredBox(
              key: const ValueKey('zeichenflaeche'),
              color: PlanerFarben.weiss,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: RasterMaler(ansicht: ansicht)),
                  ),
                  Positioned.fill(
                    child: InteractiveViewer(
                      transformationController: ansicht,
                      minScale: AnsichtSteuerung.kleinsterZoom,
                      maxScale: AnsichtSteuerung.groessterZoom,
                      boundaryMargin: const EdgeInsets.all(double.infinity),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      Werkzeugleiste(planung: planung, ansicht: ansicht),
    ],
  );
}

/// Zeichnet ein Raster, das Zoom und Verschiebung der [ansicht] folgt.
class RasterMaler extends CustomPainter {
  RasterMaler({required this.ansicht, this.abstand = 40})
    : super(repaint: ansicht) {
    // Ohne positiven Abstand endeten die Schleifen in paint() nie.
    if (abstand <= 0) {
      throw ArgumentError.value(abstand, 'abstand', 'muss größer als 0 sein');
    }
  }

  final AnsichtSteuerung ansicht;

  /// Rasterabstand bei 100 % Zoom in Pixeln.
  final double abstand;

  @override
  void paint(Canvas canvas, Size size) {
    final schritt = abstand * ansicht.zoom;
    final v = ansicht.verschiebung;
    final stift = Paint()
      ..color = PlanerFarben.linie
      ..strokeWidth = 1;
    for (var x = v.dx % schritt; x <= size.width; x += schritt) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), stift);
    }
    for (var y = v.dy % schritt; y <= size.height; y += schritt) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), stift);
    }
  }

  @override
  bool shouldRepaint(RasterMaler alt) =>
      alt.abstand != abstand || alt.ansicht != ansicht;
}

/// Werkzeugleiste unter der Zeichenfläche: Rückgängig, Wiederherstellen,
/// Zentrieren, Zoom −/Regler/+ und Bedienhinweis.
class Werkzeugleiste extends StatelessWidget {
  const Werkzeugleiste({
    required this.planung,
    required this.ansicht,
    super.key,
  });

  final PlanungsSteuerung planung;
  final AnsichtSteuerung ansicht;

  static const rueckgaengig = 'Rückgängig';
  static const wiederherstellen = 'Wiederherstellen';
  static const zentrieren = 'Zentrieren';
  static const verkleinern = 'Verkleinern';
  static const vergroessern = 'Vergrößern';
  static const zoom = 'Zoom';
  static const hinweis = 'Mausrad: Zoom · Ziehen: Verschieben';

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([planung, ansicht]),
    builder: (context, _) => Container(
      key: const ValueKey('werkzeugleiste'),
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: PlanerAbstand.klein),
      decoration: const BoxDecoration(
        color: PlanerFarben.weiss,
        border: Border(top: BorderSide(color: PlanerFarben.linie)),
      ),
      child: Row(
        children: [
          IconButton(
            key: const ValueKey('rueckgaengig'),
            tooltip: rueckgaengig,
            icon: const Icon(Icons.undo),
            onPressed: planung.kannRueckgaengig ? planung.rueckgaengig : null,
          ),
          IconButton(
            key: const ValueKey('wiederherstellen'),
            tooltip: wiederherstellen,
            icon: const Icon(Icons.redo),
            onPressed: planung.kannWiederherstellen
                ? planung.wiederherstellen
                : null,
          ),
          IconButton(
            key: const ValueKey('zentrieren'),
            tooltip: zentrieren,
            icon: const Icon(Icons.center_focus_strong),
            onPressed: ansicht.zentriere,
          ),
          IconButton(
            key: const ValueKey('verkleinern'),
            tooltip: verkleinern,
            icon: const Icon(Icons.zoom_out),
            onPressed: ansicht.verkleinern,
          ),
          SizedBox(
            width: 160,
            child: Slider(
              key: const ValueKey('zoom-regler'),
              label: zoom,
              value: ansicht.reglerWert.clamp(0, 1),
              onChanged: ansicht.setzeReglerWert,
            ),
          ),
          IconButton(
            key: const ValueKey('vergroessern'),
            tooltip: vergroessern,
            icon: const Icon(Icons.zoom_in),
            onPressed: ansicht.vergroessern,
          ),
          SizedBox(
            width: 56,
            child: Text(
              ansicht.prozent,
              key: const ValueKey('zoom-prozent'),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: PlanerAbstand.mittel),
          const Flexible(
            child: Text(
              hinweis,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: PlanerFarben.text),
            ),
          ),
        ],
      ),
    ),
  );
}
