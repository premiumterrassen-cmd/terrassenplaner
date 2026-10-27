import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';

import 'hilfe.dart';

Future<RahmenZustand> _zeige(WidgetTester tester, Size groesse) async {
  tester.view
    ..physicalSize = groesse
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final zustand = RahmenZustand();
  await tester.pumpWidget(
    testApp(
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
    expect(find.text(de.planerTitel), findsOneWidget);
    expect(
      tester.widget<Image>(find.byType(Image)).image,
      const AssetImage(Kopfzeile.logo),
    );
    for (final s in PlanerSchritt.values) {
      expect(find.byKey(ValueKey('station-${s.name}')), findsOneWidget);
      expect(find.text('${s.nummer}. ${s.titel(de)}'), findsOneWidget);
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
    final titel = tester.widget<Text>(find.text(de.planerTitel)).style!;
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
      expect(find.text(s.nummerierteUnterpunkte(de).first), findsOneWidget);
    }
    final fortschritt = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(fortschritt.value, 1);
  });

  testWidgets('Menüeintrag wählt den Schritt', (tester) async {
    final zustand = await _zeige(tester, _desktop);
    ListTile eintrag(PlanerSchritt s) =>
        tester.widget<ListTile>(find.byKey(ValueKey('menu-${s.name}')));
    expect(eintrag(PlanerSchritt.grundriss).selected, isTrue);
    expect(eintrag(PlanerSchritt.treppen).selected, isFalse);
    expect(
      (eintrag(PlanerSchritt.grundriss).trailing! as Icon).icon,
      Icons.expand_less,
    );
    expect(
      (eintrag(PlanerSchritt.treppen).trailing! as Icon).icon,
      Icons.expand_more,
    );
    expect(eintrag(PlanerSchritt.treppen).selectedColor, PlanerFarben.braun);
    await tester.tap(find.byKey(const ValueKey('menu-treppen')));
    await tester.pump();
    expect(zustand.aktiv, PlanerSchritt.treppen);
    expect(find.text('5.1 Treppen'), findsOneWidget);
    expect(find.text('1.1 Terrassenform auswählen'), findsNothing);
  });

  testWidgets('Griff klappt das Menü ein und aus (Desktop)', (tester) async {
    await _zeige(tester, _desktop);
    expect(find.bySemanticsLabel(de.menuEinklappen), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('menu-griff')));
    await tester.pump();
    expect(find.byKey(const ValueKey('bearbeitungsmenue')), findsNothing);
    expect(find.bySemanticsLabel(de.menuAusklappen), findsOneWidget);
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
    TextStyle titel(PlanerSchritt s) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(ValueKey('station-${s.name}')),
            matching: find.text(s.titel(de)),
          ),
        )
        .style!;
    expect(
      [
        titel(PlanerSchritt.treppen).fontSize,
        titel(PlanerSchritt.treppen).fontWeight,
      ],
      [11, FontWeight.w700],
    );
    expect(titel(PlanerSchritt.zubehoer).fontWeight, FontWeight.w400);
  });

  test('Kennzahlen mit Komma und Einheit', () {
    expect(Kennzahlen.zahl(de, null, 'm²'), '– m²');
    expect(Kennzahlen.zahl(de, 14.835, 'm²'), '14,84 m²');
    expect(Kennzahlen.zahl(de, 0.5, 'm³'), '0,50 m³');
  });

  testWidgets('Kennzahlen mit Werten', (tester) async {
    await tester.pumpWidget(
      testApp(home: const Kennzahlen(flaeche: 12, volumen: 0.25)),
    );
    expect(find.text('Fläche: 12,00 m²'), findsOneWidget);
    expect(find.text('Volumen: 0,25 m³'), findsOneWidget);
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
    expect(Kopfzeile.logo, 'assets/bilder/robinienwelt_logo.png');
    expect(thema.cardTheme.color, PlanerFarben.weiss);
    expect(thema.cardTheme.surfaceTintColor, PlanerFarben.weiss);
    expect(thema.cardTheme.elevation, 1);
    expect(thema.dividerColor, PlanerFarben.linie);
    expect(thema.dialogTheme.backgroundColor, PlanerFarben.weiss);
    expect(thema.dialogTheme.surfaceTintColor, PlanerFarben.weiss);
    expect(thema.scaffoldBackgroundColor, PlanerFarben.weiss);
  });
}
