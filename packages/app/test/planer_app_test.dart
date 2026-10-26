import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/planer_app.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

void main() {
  testWidgets('Projekttitel im Browser-Tab, Rahmen mit Planer-Thema', (
    tester,
  ) async {
    await tester.pumpWidget(PlanerApp(hallo: () async => 'x'));
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.title, 'Terrassenplaner – ALTO HOLZ');
    expect(app.debugShowCheckedModeBanner, isFalse);
    expect(app.theme!.colorScheme.primary, PlanerFarben.braun);
    expect(find.byType(PlanerRahmen), findsOneWidget);
    expect(find.text(PlanerRahmen.titel), findsOneWidget);
  });

  testWidgets('übergebene Projektdaten im Browser-Tab', (tester) async {
    const info = ProjektInfo(name: 'Test', firma: 'X');
    await tester.pumpWidget(PlanerApp(hallo: () async => 'x', info: info));
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
      'Test – X',
    );
  });

  testWidgets('Status: erst „Verbinde …“, dann die Antwort des Servers', (
    tester,
  ) async {
    final antwort = Completer<String>();
    await tester.pumpWidget(PlanerApp(hallo: () => antwort.future));
    expect(find.text(ServerStatus.verbinde), findsOneWidget);
    antwort.complete('Verbunden mit Test');
    await tester.pump();
    expect(find.text('Verbunden mit Test'), findsOneWidget);
  });

  testWidgets('Status bei Fehler: keine Verbindung', (tester) async {
    await tester.pumpWidget(
      PlanerApp(hallo: () => Future<String>.error(StateError('weg'))),
    );
    await tester.pump();
    expect(find.text(ServerStatus.keineVerbindung), findsOneWidget);
  });

  test('Texte des Status', () {
    expect(ServerStatus.verbinde, 'Verbinde mit dem Server …');
    expect(ServerStatus.keineVerbindung, 'Keine Verbindung zum Server');
  });
}
