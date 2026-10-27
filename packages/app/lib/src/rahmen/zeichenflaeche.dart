import 'package:flutter/material.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'ansichtsoptionen.dart';
import 'steuerung.dart';
import 'zeichnung.dart';

/// Zeichenfläche (M3-03): Raster, Zoom mit Mausrad oder Regler, Verschieben
/// mit der Maus; darunter die Werkzeugleiste. Gezeichnet wird ab M4.
class Zeichenflaeche extends StatelessWidget {
  const Zeichenflaeche({
    required this.planung,
    required this.ansicht,
    required this.optionen,
    required this.zeichnung,
    super.key,
  });

  final PlanungsSteuerung planung;
  final AnsichtSteuerung ansicht;
  final AnsichtsOptionen optionen;
  final Zeichnung zeichnung;

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
                    child: CustomPaint(
                      key: const ValueKey('zeichnung'),
                      painter: ZeichnungsMaler(
                        zeichnung: zeichnung,
                        optionen: optionen,
                        ansicht: ansicht,
                        sprache: context.texte,
                      ),
                    ),
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
      Werkzeugleiste(planung: planung, ansicht: ansicht, optionen: optionen),
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
    required this.optionen,
    super.key,
  });

  final PlanungsSteuerung planung;
  final AnsichtSteuerung ansicht;
  final AnsichtsOptionen optionen;

  /// Ab dieser Breite zeigt die Leiste Zoom-Regler und Bedienhinweis.
  static const breitAb = 1000.0;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([planung, ansicht, optionen]),
    builder: (context, _) => LayoutBuilder(
      builder: (context, raum) =>
          _leiste(context.texte, breit: raum.maxWidth >= breitAb),
    ),
  );

  Widget _leiste(PlanerTexte t, {required bool breit}) => Container(
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
          tooltip: t.rueckgaengig,
          icon: const Icon(Icons.undo),
          onPressed: planung.kannRueckgaengig ? planung.rueckgaengig : null,
        ),
        IconButton(
          key: const ValueKey('wiederherstellen'),
          tooltip: t.wiederherstellen,
          icon: const Icon(Icons.redo),
          onPressed: planung.kannWiederherstellen
              ? planung.wiederherstellen
              : null,
        ),
        IconButton(
          key: const ValueKey('zentrieren'),
          tooltip: t.zentrieren,
          icon: const Icon(Icons.center_focus_strong),
          onPressed: ansicht.zentriere,
        ),
        IconButton(
          key: const ValueKey('verkleinern'),
          tooltip: t.verkleinern,
          icon: const Icon(Icons.zoom_out),
          onPressed: ansicht.verkleinern,
        ),
        if (breit)
          SizedBox(
            width: 160,
            child: Slider(
              key: const ValueKey('zoom-regler'),
              label: t.zoom,
              value: ansicht.reglerWert.clamp(0, 1),
              onChanged: ansicht.setzeReglerWert,
            ),
          ),
        IconButton(
          key: const ValueKey('vergroessern'),
          tooltip: t.vergroessern,
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
        const SizedBox(width: PlanerAbstand.klein),
        SegmentedButton<Ebene>(
          key: const ValueKey('ebenen'),
          multiSelectionEnabled: true,
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          segments: [
            for (final e in Ebene.values)
              ButtonSegment(
                value: e,
                label: Text(e.titel(t)),
                tooltip: e.langerTitel(t),
              ),
          ],
          selected: optionen.ebenen,
          onSelectionChanged: optionen.setzeEbenen,
        ),
        PopupMenuButton<Beschriftung>(
          key: const ValueKey('beschriftungen'),
          tooltip: t.beschriftungen,
          icon: const Icon(Icons.label_outline),
          onSelected: optionen.schalte,
          itemBuilder: (_) => [
            for (final b in Beschriftung.values)
              CheckedPopupMenuItem(
                key: ValueKey('beschriftung-${b.name}'),
                value: b,
                checked: optionen.beschriftet(b),
                child: Text(b.titel(t)),
              ),
          ],
        ),
        if (breit) ...[
          const SizedBox(width: PlanerAbstand.klein),
          Flexible(
            child: Text(
              t.bedienHinweis,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: PlanerFarben.text),
            ),
          ),
        ],
      ],
    ),
  );
}
