import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'ansichtsoptionen.dart';
import 'freiform.dart';
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
    this.freiform,
  });

  final PlanungsSteuerung planung;
  final AnsichtSteuerung ansicht;
  final AnsichtsOptionen optionen;
  final Zeichnung zeichnung;

  /// Zeichnen der Freiform (M4-08): Antippen setzt einen Punkt, Taste x
  /// schließt die Form – nur solange sie offen ist.
  final FreiformBedienung? freiform;

  /// Bildschirmpunkt in mm der Zeichnung (Umkehrung der Ansicht).
  Punkt inMillimeter(Offset lokal) {
    final mm = (lokal - ansicht.verschiebung) / (pixelJeMm * ansicht.zoom);
    return Punkt(mm.dx, mm.dy);
  }

  Widget _zeichnen(BuildContext context, Widget kind) {
    final bedienung = freiform;
    if (bedienung?.offen == null) return kind;
    return Focus(
      autofocus: true,
      onKeyEvent: (_, ereignis) {
        if (ereignis is! KeyDownEvent ||
            ereignis.logicalKey != LogicalKeyboardKey.keyX) {
          return KeyEventResult.ignored;
        }
        FreiformBedienung.melde(context, bedienung!.schliesse());
        return KeyEventResult.handled;
      },
      child: Builder(
        builder: (fokus) => GestureDetector(
          key: const ValueKey('freiform-zeichnen'),
          onTapUp: (tipp) {
            Focus.of(fokus).requestFocus();
            FreiformBedienung.melde(
              context,
              bedienung!.setzePunkt(inMillimeter(tipp.localPosition)),
            );
          },
          child: kind,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: LayoutBuilder(
          builder: (context, raum) {
            ansicht.flaeche = raum.biggest;
            return ColoredBox(
              key: const ValueKey('zeichenflaeche'),
              color: context.farben.surface,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: RasterMaler(
                        ansicht: ansicht,
                        linie: context.farben.outlineVariant,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      key: const ValueKey('zeichnung'),
                      painter: ZeichnungsMaler(
                        zeichnung: zeichnung,
                        optionen: optionen,
                        ansicht: ansicht,
                        sprache: context.texte,
                        strich: context.farben.onSurface,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: _zeichnen(
                      context,
                      InteractiveViewer(
                        transformationController: ansicht,
                        minScale: AnsichtSteuerung.kleinsterZoom,
                        maxScale: AnsichtSteuerung.groessterZoom,
                        boundaryMargin: const EdgeInsets.all(double.infinity),
                        child: const SizedBox.expand(),
                      ),
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
  RasterMaler({
    required this.ansicht,
    this.abstand = 40,
    this.linie = PlanerFarben.linie,
  }) : super(repaint: ansicht) {
    // Ohne positiven Abstand endeten die Schleifen in paint() nie.
    if (abstand <= 0) {
      throw ArgumentError.value(abstand, 'abstand', 'muss größer als 0 sein');
    }
  }

  final AnsichtSteuerung ansicht;

  /// Rasterabstand bei 100 % Zoom in Pixeln.
  final double abstand;

  /// Farbe der Rasterlinien (hell/dunkel, M3-09).
  final Color linie;

  @override
  void paint(Canvas canvas, Size size) {
    final schritt = abstand * ansicht.zoom;
    final v = ansicht.verschiebung;
    final stift = Paint()
      ..color = linie
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
      alt.abstand != abstand || alt.ansicht != ansicht || alt.linie != linie;
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
          _leiste(context, context.texte, breit: raum.maxWidth >= breitAb),
    ),
  );

  Widget _leiste(BuildContext context, PlanerTexte t, {required bool breit}) =>
      Container(
        key: const ValueKey('werkzeugleiste'),
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: PlanerAbstand.klein),
        decoration: BoxDecoration(
          color: context.farben.surface,
          border: Border(top: BorderSide(color: context.farben.outlineVariant)),
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
                  switch (planung.aktuell.grundriss) {
                    FreiformGrundriss(geschlossen: false) => t.freiformHinweis,
                    _ => t.bedienHinweis,
                  },
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.farben.onSurface,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
}
