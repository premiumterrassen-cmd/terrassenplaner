import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/modell3d/modell3d_ansicht_stub.dart';
import 'package:terrassenplaner_app/src/modell3d/modell3d_seite.dart';

void main() {
  testWidgets('lädt, dann Ansicht (auf der VM: Hinweis)', (tester) async {
    final glb = Completer<Uint8List>();
    await tester.pumpWidget(
      MaterialApp(home: Modell3dSeite(lade: () => glb.future)),
    );
    expect(find.text(Modell3dSeite.titel), findsOneWidget);
    expect(find.text(Modell3dSeite.laedt), findsOneWidget);
    glb.complete(Uint8List(4));
    await tester.pump();
    expect(find.text(nurImBrowser), findsOneWidget);
    expect(
      tester.widget<Text>(find.text(nurImBrowser)).semanticsLabel,
      Modell3dSeite.titel,
    );
  });

  testWidgets('Fehler beim Laden', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Modell3dSeite(lade: () => Future.error(StateError('weg'))),
      ),
    );
    await tester.pump();
    expect(find.text(Modell3dSeite.fehler), findsOneWidget);
  });

  test('Texte', () {
    expect(Modell3dSeite.titel, '3D-Vorschau (Prototyp): Terrasse 4 x 3 m');
    expect(Modell3dSeite.laedt, 'Lade 3D-Modell …');
    expect(Modell3dSeite.fehler, '3D-Modell konnte nicht geladen werden');
    expect(nurImBrowser, 'Die 3D-Ansicht gibt es nur im Browser.');
  });
}
