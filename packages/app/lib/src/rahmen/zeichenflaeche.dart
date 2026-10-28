import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'ansichtsoptionen.dart';
import 'freiform.dart';
import 'rundung.dart';
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
    this.rundung,
  });

  final PlanungsSteuerung planung;
  final AnsichtSteuerung ansicht;
  final AnsichtsOptionen optionen;
  final Zeichnung zeichnung;

  /// Zeichnen der Freiform (M4-08): Antippen setzt einen Punkt, Taste x
  /// schließt die Form – nur solange sie offen ist.
  final FreiformBedienung? freiform;

  /// Rundungsmodus (M4-11): eigene Griffe statt der Eckenbearbeitung.
  final RundungsBedienung? rundung;

  /// Bildschirmpunkt in mm der Zeichnung (Umkehrung der Ansicht).
  Punkt inMillimeter(Offset lokal) {
    final mm = (lokal - ansicht.verschiebung) / (pixelJeMm * ansicht.zoom);
    return Punkt(mm.dx, mm.dy);
  }

  /// Ziehpunkte zum Bearbeiten (M4-09): Ecken (antippen wählt aus, ziehen
  /// verschiebt) und Kantenmitten (antippen fügt einen Punkt ein, ziehen
  /// verschiebt die Kante parallel). Sie liegen über der Ansicht, damit
  /// Ziehen an einem Griff die Fläche nicht verschiebt.
  List<Widget> _griffe() {
    if (rundung case final r? when r.aktiv) return _rundungsGriffe(r);
    final bedienung = freiform;
    final ecken = zeichnung.ecken;
    if (bedienung?.bearbeitbar == null ||
        !zeichnung.geschlossen ||
        ecken.length < 3) {
      return const [];
    }
    return [
      Positioned.fill(
        child: ListenableBuilder(
          listenable: Listenable.merge([ansicht, bedienung!.modus]),
          builder: (context, _) {
            Offset schirm(Offset mm) =>
                ansicht.verschiebung + mm * (pixelJeMm * ansicht.zoom);
            final n = ecken.length;
            return Stack(
              children: [
                for (var i = 0; i < n; i++) ...[
                  Griff(
                    key: ValueKey('ecke-$i'),
                    mitte: schirm(ecken[i]),
                    ausgewaehlt: bedienung.modus.auswahl == i,
                    zoom: ansicht.zoom,
                    onTap: () => bedienung.modus.auswahl = i,
                    onZiehen: (versatz, {required beginn}) {
                      if (beginn) bedienung.modus.auswahl = i;
                      bedienung.ziehePunkt(i, versatz, beginn: beginn);
                    },
                  ),
                  Griff(
                    key: ValueKey('kante-$i'),
                    mitte: schirm(
                      Offset.lerp(ecken[i], ecken[(i + 1) % n], 0.5)!,
                    ),
                    kante: true,
                    zoom: ansicht.zoom,
                    onTap: () => FreiformBedienung.melde(
                      context,
                      bedienung.fuegePunktEin(i),
                    ),
                    onZiehen: (versatz, {required beginn}) =>
                        bedienung.zieheKante(i, versatz, beginn: beginn),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    ];
  }

  /// Griffe im Rundungsmodus (M4-11): innen an jeder Ecke (Zugweg nach
  /// innen = Radius) und auf jeder Seite (Zugweg nach außen = Stich).
  List<Widget> _rundungsGriffe(RundungsBedienung r) {
    final ecken = zeichnung.ecken;
    if (ecken.length < 3) return const [];
    return [
      Positioned.fill(
        child: ListenableBuilder(
          listenable: Listenable.merge([ansicht, r]),
          builder: (context, _) {
            final massstab = pixelJeMm * ansicht.zoom;
            Offset schirm(Offset mm) => ansicht.verschiebung + mm * massstab;
            final n = ecken.length;
            final seiten = planung.aktuell.rundungen.seiten;
            return Stack(
              children: [
                for (var i = 0; i < n; i++) ...[
                  _rundungsGriff(
                    r,
                    (ecke: true, nummer: i),
                    schirm(ecken[i]) +
                        ZeichnungsMaler.innen(ecken, i) * Griff.groesse,
                    ZeichnungsMaler.innen(ecken, i),
                  ),
                  _rundungsGriff(
                    r,
                    (ecke: false, nummer: i),
                    schirm(
                      Offset.lerp(ecken[i], ecken[(i + 1) % n], 0.5)! +
                          ZeichnungsMaler.aussen(ecken, i) *
                              (seiten[i]?.mm ?? 0).toDouble(),
                    ),
                    ZeichnungsMaler.aussen(ecken, i),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    ];
  }

  Widget _rundungsGriff(
    RundungsBedienung r,
    RundungsAuswahl ziel,
    Offset mitte,
    Offset richtung,
  ) => Griff(
    key: ValueKey('rundung-${ziel.ecke ? 'ecke' : 'seite'}-${ziel.nummer}'),
    mitte: mitte,
    kante: !ziel.ecke,
    ausgewaehlt: r.auswahl == ziel,
    zoom: ansicht.zoom,
    onTap: () => r.waehle(ziel),
    onZiehen: (versatz, {required beginn}) =>
        r.ziehe(ziel, versatz, Punkt(richtung.dx, richtung.dy), beginn: beginn),
  );

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
                  ..._griffe(),
                ],
              ),
            );
          },
        ),
      ),
      Werkzeugleiste(
        planung: planung,
        ansicht: ansicht,
        optionen: optionen,
        zeichnung: zeichnung,
        onGeaendert: freiform?.onGeaendert,
      ),
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
/// Form drehen, Zentrieren, Zoom −/Regler/+ und Bedienhinweis.
class Werkzeugleiste extends StatelessWidget {
  const Werkzeugleiste({
    required this.planung,
    required this.ansicht,
    required this.optionen,
    super.key,
    this.zeichnung,
    this.onGeaendert,
  });

  final PlanungsSteuerung planung;
  final AnsichtSteuerung ansicht;
  final AnsichtsOptionen optionen;

  /// Was gezeichnet ist – „Zentrieren“ stellt es in die Mitte (M4-10).
  final Zeichnung? zeichnung;

  /// Meldet eine Änderung des Grundrisses (Standardwert-Hinweis, M3-05).
  final VoidCallback? onGeaendert;

  /// Drehwinkel des Knopfs „Form drehen“ (in der Zeichnung rechtsherum).
  static const drehwinkel = 90.0;

  /// Dreht die Form (M4-10); gibt es Ausschnitte, erst nach Bestätigung,
  /// denn sie werden dabei zurückgesetzt.
  Future<void> _drehe(BuildContext context) async {
    final stand = planung.aktuell;
    if (stand.ausschnitte.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => const DrehenDialog(),
      );
      if (!(ok ?? false)) return;
    }
    planung.setze(stand.gedreht(drehwinkel));
    onGeaendert?.call();
  }

  /// Kreis und offene Freiform lassen sich nicht drehen.
  bool get _drehbar => switch (planung.aktuell.grundriss) {
    FreiformGrundriss(geschlossen: false) => false,
    final g => g.alsFreiform != null,
  };

  void _zentriere() {
    final umriss = zeichnung?.umriss ?? const [];
    if (umriss.isEmpty) {
      ansicht.zentriere();
      return;
    }
    ansicht.zentriereAuf(
      Rect.fromPoints(
        Offset(
          umriss.map((p) => p.dx).reduce(math.min),
          umriss.map((p) => p.dy).reduce(math.min),
        ),
        Offset(
          umriss.map((p) => p.dx).reduce(math.max),
          umriss.map((p) => p.dy).reduce(math.max),
        ),
      ),
      pixelJeMm,
    );
  }

  /// Ab dieser Breite zeigt die Leiste Zoom-Regler, Prozent und
  /// Bedienhinweis.
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
              key: const ValueKey('form-drehen'),
              tooltip: t.formDrehen,
              icon: const Icon(Icons.rotate_right),
              onPressed: _drehbar ? () => _drehe(context) : null,
            ),
            IconButton(
              key: const ValueKey('zentrieren'),
              tooltip: t.zentrieren,
              icon: const Icon(Icons.center_focus_strong),
              onPressed: _zentriere,
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
            // schmal (z. B. 1024 px mit Menü) ohne Prozentanzeige – Platz
            // für „Form drehen“ (M4-10)
            if (breit) ...[
              SizedBox(
                width: 56,
                child: Text(
                  ansicht.prozent,
                  key: const ValueKey('zoom-prozent'),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: PlanerAbstand.klein),
            ],
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

/// Ein Ziehpunkt der Zeichenfläche (M4-09): rund für Ecken, eckig für
/// Kantenmitten. Meldet beim Ziehen den Versatz in mm seit Beginn.
class Griff extends StatefulWidget {
  const Griff({
    required this.mitte,
    required this.zoom,
    required this.onTap,
    required this.onZiehen,
    super.key,
    this.kante = false,
    this.ausgewaehlt = false,
  });

  /// Lage auf dem Bildschirm.
  final Offset mitte;

  /// Zoom der Ansicht – rechnet Pixel in Millimeter um.
  final double zoom;
  final VoidCallback onTap;
  final void Function(Punkt versatz, {required bool beginn}) onZiehen;
  final bool kante;
  final bool ausgewaehlt;

  /// Kantenlänge der Trefferfläche in Pixeln.
  static const groesse = 20.0;

  @override
  State<Griff> createState() => _GriffState();
}

class _GriffState extends State<Griff> {
  // vom Aufsetzen an gemessen: die Strecke bis zum Erkennen der Geste
  // (Touch-Slop) zählt mit, und der Griff selbst wandert mit
  var _aufgesetzt = Offset.zero;
  var _beginn = true;

  @override
  Widget build(BuildContext context) => Positioned(
    left: widget.mitte.dx - Griff.groesse / 2,
    top: widget.mitte.dy - Griff.groesse / 2,
    width: Griff.groesse,
    height: Griff.groesse,
    child: GestureDetector(
      onTap: widget.onTap,
      onPanDown: (aufsetzen) {
        _aufgesetzt = aufsetzen.globalPosition;
        _beginn = true;
      },
      onPanUpdate: (ziehen) {
        final mm =
            (ziehen.globalPosition - _aufgesetzt) / (pixelJeMm * widget.zoom);
        widget.onZiehen(Punkt(mm.dx, mm.dy), beginn: _beginn);
        _beginn = false;
      },
      child: Center(
        child: Container(
          width: widget.kante ? 8 : 12,
          height: widget.kante ? 8 : 12,
          decoration: BoxDecoration(
            color: widget.ausgewaehlt
                ? PlanerFarben.gruen
                : context.farben.surface,
            border: Border.all(color: PlanerFarben.braun, width: 2),
            shape: widget.kante ? BoxShape.rectangle : BoxShape.circle,
          ),
        ),
      ),
    ),
  );
}

/// Rückfrage vor dem Drehen, wenn Ausschnitte zurückgesetzt würden (M4-10).
class DrehenDialog extends StatelessWidget {
  const DrehenDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    return AlertDialog(
      key: const ValueKey('drehen-dialog'),
      title: Text(t.drehenTitel),
      content: Text(t.drehenText),
      actions: [
        TextButton(
          key: const ValueKey('drehen-abbrechen'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(t.abbrechen),
        ),
        FilledButton(
          key: const ValueKey('drehen-bestaetigen'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(t.drehenBestaetigen),
        ),
      ],
    );
  }
}
