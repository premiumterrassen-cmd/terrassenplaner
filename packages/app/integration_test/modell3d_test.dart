import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:terrassenplaner_app/src/modell3d/modell3d_seite.dart';
import 'package:terrassenplaner_app/src/verbindung/planer_verbindung.dart';
import 'package:terrassenplaner_app/src/verbindung/wamp_adresse.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:web/web.dart' as web;

import '../test/hilfe.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('3D-Prototyp: Server erzeugt GLB, Browser zeigt es an', (
    tester,
  ) async {
    final verbindung = PlanerVerbindung(
      wampAdresse(
        Uri.base,
        vorgabe: const String.fromEnvironment('PLANER_WAMP_URL'),
      ),
    );
    await tester.pumpWidget(
      testApp(
        home: Modell3dSeite(
          lade: () => verbindung.modell3dRechteck(
            const Millimeter(4000),
            const Millimeter(3000),
          ),
        ),
      ),
    );
    web.Element? viewer;
    var geladen = false;
    for (var i = 0; i < 300 && !geladen; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      viewer = web.document.querySelector('model-viewer');
      geladen = viewer?.getProperty<JSBoolean?>('loaded'.toJS)?.toDart ?? false;
    }
    expect(viewer, isNotNull, reason: 'model-viewer im DOM');
    expect(geladen, isTrue, reason: 'GLB vom Server geladen');
    expect(viewer!.getAttribute('src'), startsWith('blob:'));
    expect(viewer.hasAttribute('ar'), isTrue);
    expect(find.text(de.modell3dFehler), findsNothing);
  });
}
