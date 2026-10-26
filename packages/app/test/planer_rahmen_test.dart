import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';

Future<RahmenZustand> _zeige(WidgetTester tester, Size groesse) async {
  tester.view
    ..physicalSize = groesse
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final zustand = RahmenZustand();
  await tester.pumpWidget(
    MaterialApp(
      theme: planerThema(),
      home: PlanerRahmen(status: const Text('Status'), zustand: zustand),
    ),
  );
  return zustand;
}

const _desktop = Size(1440, 900);
const _tablet = Size(768, 1024);

void main() {
  testWidgets('Kopfzeile, Schrittleiste, Menü, Fläche, Status (Desktop)', (
    tester,
  ) async {
    await _zeige(tester, _desktop);
    expect(find.text(PlanerRahmen.titel), findsOneWidget);
    expect(
      tester.widget<Image>(find.byType(Image)).image,
      const AssetImage(Kopfzeile.logo),
    );
    for (final s in PlanerSchritt.values) {
      expect(find.byKey(ValueKey('station-${s.name}')), findsOneWidget);
      expect(find.text('${s.nummer}. ${s.titel}'), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('bearbeitungsmenue')), findsOneWidget);
    expect(find.text('1.1 Terrassenform auswählen'), findsOneWidget);
    expect(find.text('2.1 Terrassenbelag auswählen'), findsNothing);
    expect(find.byKey(const ValueKey('zeichenflaeche')), findsOneWidget);
    expect(find.text('Fläche: – m²'), findsOneWidget);
    expect(find.text('Volumen: – m³'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
    final logo = tester.widget<Image>(find.byType(Image));
    expect([logo.height, logo.semanticLabel], [48, 'RobinienWelt']);
    final titel = tester.widget<Text>(find.text(PlanerRahmen.titel)).style!;
    expect(
      [titel.color, titel.fontWeight, titel.letterSpacing],
      [PlanerFarben.braun, FontWeight.w500, 1.5],
    );
    final status = DefaultTextStyle.of(tester.element(find.text('Status')));
    expect(
      [status.style.fontSize, status.style.color],
      [12, PlanerFarben.text],
    );
    // Breite Stationen (1440 / 7 > 160 px): Titel ungetrennt.
    expect(find.text('UNTERKONSTRUKTION'), findsOneWidget);
    expect(Station.schmalUnter, 160);
    expect(tester.takeException(), isNull, reason: 'kein Überlauf');
  });

  testWidgets('jede Station ist erreichbar', (tester) async {
    final zustand = await _zeige(tester, _desktop);
    for (final s in PlanerSchritt.values.reversed) {
      await tester.tap(find.byKey(ValueKey('station-${s.name}')));
      await tester.pump();
      expect(zustand.aktiv, s);
      expect(find.text(s.nummerierteUnterpunkte.first), findsOneWidget);
    }
    final fortschritt = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(fortschritt.value, 1);
  });

  testWidgets('Menüeintrag wählt den Schritt', (tester) async {
    final zustand = await _zeige(tester, _desktop);
    await tester.tap(find.byKey(const ValueKey('menu-treppen')));
    await tester.pump();
    expect(zustand.aktiv, PlanerSchritt.treppen);
    expect(find.text('5.1 Treppen'), findsOneWidget);
    expect(find.text('1.1 Terrassenform auswählen'), findsNothing);
  });

  testWidgets('Griff klappt das Menü ein und aus (Desktop)', (tester) async {
    await _zeige(tester, _desktop);
    expect(find.bySemanticsLabel(MenuGriff.einklappen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('menu-griff')));
    await tester.pump();
    expect(find.byKey(const ValueKey('bearbeitungsmenue')), findsNothing);
    expect(find.bySemanticsLabel(MenuGriff.ausklappen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('menu-griff')));
    await tester.pump();
    expect(find.byKey(const ValueKey('bearbeitungsmenue')), findsOneWidget);
  });

  testWidgets('Tablet: Menü zu, ausgeklappt über der Zeichenfläche', (
    tester,
  ) async {
    await _zeige(tester, _tablet);
    expect(find.byKey(const ValueKey('bearbeitungsmenue')), findsNothing);
    for (final s in PlanerSchritt.values) {
      expect(find.byKey(ValueKey('station-${s.name}')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('menu-griff')));
    await tester.pump();
    final menu = find.byKey(const ValueKey('bearbeitungsmenue'));
    expect(menu, findsOneWidget);
    expect(find.ancestor(of: menu, matching: find.byType(Stack)), findsWidgets);
    expect(tester.getSize(menu).width, PlanerLayout.menuBreite);
    expect(find.text('UNTER-\nKONSTRUKTION'), findsOneWidget);
    expect(find.text('UNTERKONSTRUKTION'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Station zeigt aktiv, besucht und offen unterschiedlich', (
    tester,
  ) async {
    final zustand = await _zeige(tester, _desktop);
    zustand.waehle(PlanerSchritt.treppen);
    await tester.pump();
    Color farbe(PlanerSchritt s) => tester
        .widget<CircleAvatar>(
          find.descendant(
            of: find.byKey(ValueKey('station-${s.name}')),
            matching: find.byType(CircleAvatar),
          ),
        )
        .backgroundColor!;
    expect(farbe(PlanerSchritt.treppen), PlanerFarben.gruen);
    expect(farbe(PlanerSchritt.grundriss), PlanerFarben.braun);
    expect(farbe(PlanerSchritt.zubehoer), PlanerFarben.linie);
  });

  test('Kennzahlen mit Komma und Einheit', () {
    expect(Kennzahlen.zahl(null, 'm²'), '– m²');
    expect(Kennzahlen.zahl(14.835, 'm²'), '14,84 m²');
    expect(Kennzahlen.zahl(0.5, 'm³'), '0,50 m³');
  });

  testWidgets('Kennzahlen mit Werten', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Kennzahlen(flaeche: 12, volumen: 0.25)),
    );
    expect(find.text('Fläche: 12,00 m²'), findsOneWidget);
    expect(find.text('Volumen: 0,25 m³'), findsOneWidget);
  });

  test('Raster neu zeichnen nur bei anderem Abstand', () {
    const maler = RasterMaler();
    expect(maler.abstand, 40);
    expect(maler.shouldRepaint(const RasterMaler()), isFalse);
    expect(maler.shouldRepaint(const RasterMaler(abstand: 20)), isTrue);
  });

  test('Raster: Linien im Abstand über die ganze Fläche', () {
    final aufnahme = PictureRecorder();
    final leinwand = _ZaehlendeLeinwand(Canvas(aufnahme));
    const RasterMaler(abstand: 50).paint(leinwand, const Size(100, 60));
    // x = 0, 50, 100 und y = 0, 50
    expect(leinwand.linien, [
      (const Offset(0, 0), const Offset(0, 60)),
      (const Offset(50, 0), const Offset(50, 60)),
      (const Offset(100, 0), const Offset(100, 60)),
      (const Offset(0, 0), const Offset(100, 0)),
      (const Offset(0, 50), const Offset(100, 50)),
    ]);
    expect(
      {for (final f in leinwand.farben) f.toARGB32()},
      {PlanerFarben.linie.toARGB32()},
    );
    aufnahme.endRecording();
  });

  test('Design: Farben, Breakpoints, Thema', () {
    expect(PlanerFarben.braun, const Color(0xFFB0864B));
    expect(PlanerFarben.gruen, const Color(0xFF95C11C));
    expect([PlanerLayout.tabletAb, PlanerLayout.desktopAb], [600, 1024]);
    expect(PlanerLayout.istDesktop(1024), isTrue);
    expect(PlanerLayout.istDesktop(1023), isFalse);
    expect(
      [PlanerAbstand.klein, PlanerAbstand.mittel, PlanerAbstand.gross],
      [8, 16, 24],
    );
    final thema = planerThema();
    expect(thema.colorScheme.primary, PlanerFarben.braun);
    expect(thema.colorScheme.secondary, PlanerFarben.gruen);
    expect(thema.textTheme.bodyMedium!.fontFamily, planerSchrift);
    expect(planerSchrift, 'Roboto');
    expect(thema.cardTheme.color, PlanerFarben.weiss);
    expect(thema.cardTheme.surfaceTintColor, PlanerFarben.weiss);
    expect(thema.cardTheme.elevation, 1);
    expect(thema.dividerColor, PlanerFarben.linie);
    expect(thema.scaffoldBackgroundColor, PlanerFarben.weiss);
  });
}

class _ZaehlendeLeinwand implements Canvas {
  _ZaehlendeLeinwand(this._ziel);

  final Canvas _ziel;
  final linien = <(Offset, Offset)>[];
  final farben = <Color>[];

  @override
  void drawLine(Offset p1, Offset p2, Paint paint) {
    linien.add((p1, p2));
    farben.add(paint.color);
    _ziel.drawLine(p1, p2, paint);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
