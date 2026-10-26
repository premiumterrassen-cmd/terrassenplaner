import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/modell3d/modell3d_seite.dart';

import 'hilfe.dart';

void main() {
  testWidgets('lädt, dann Ansicht (auf der VM: Hinweis)', (tester) async {
    final glb = Completer<Uint8List>();
    await tester.pumpWidget(
      testApp(home: Modell3dSeite(lade: () => glb.future)),
    );
    expect(find.text(de.modell3dTitel), findsOneWidget);
    expect(find.text(de.modell3dLaedt), findsOneWidget);
    glb.complete(Uint8List(4));
    await tester.pump();
    expect(find.text(de.nurImBrowser), findsOneWidget);
    expect(
      tester.widget<Text>(find.text(de.nurImBrowser)).semanticsLabel,
      de.modell3dTitel,
    );
  });

  testWidgets('Fehler beim Laden', (tester) async {
    await tester.pumpWidget(
      testApp(home: Modell3dSeite(lade: () => Future.error(StateError('weg')))),
    );
    await tester.pump();
    expect(find.text(de.modell3dFehler), findsOneWidget);
  });

  test('Texte', () {
    expect(de.modell3dTitel, '3D-Vorschau (Prototyp): Terrasse 4 x 3 m');
    expect(de.modell3dLaedt, 'Lade 3D-Modell …');
    expect(de.modell3dFehler, '3D-Modell konnte nicht geladen werden');
    expect(de.nurImBrowser, 'Die 3D-Ansicht gibt es nur im Browser.');
  });
}
