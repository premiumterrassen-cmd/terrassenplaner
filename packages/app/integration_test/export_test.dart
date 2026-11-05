import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:terrassenplaner_app/src/export/datei_angebot.dart';
import 'package:terrassenplaner_app/src/verbindung/planer_verbindung.dart';
import 'package:terrassenplaner_app/src/verbindung/wamp_adresse.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:web/web.dart' as web;

/// Export für GrandTotal (M9-08) im echten Browser: Importdatei vom Server
/// und Download über einen Blob-Link.
/// Testkonto, das `tool/smoke.sh` nur für diesen Lauf anlegt (M9-10).
const _email = String.fromEnvironment('SMOKE_MITARBEITER_EMAIL');
const _passwort = String.fromEnvironment('SMOKE_MITARBEITER_PASSWORT');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Importdatei vom Server nur für Mitarbeiter', (_) async {
    expect(_email, isNotEmpty, reason: 'Testkonto fehlt (tool/smoke.sh)');
    final verbindung = PlanerVerbindung(
      wampAdresse(
        Uri.base,
        vorgabe: const String.fromEnvironment('PLANER_WAMP_URL'),
      ),
    );
    // Kunde (anonym): der Router lehnt ab
    await expectLater(
      verbindung.exportGrandTotal(Planung.start, Uri.base),
      throwsA(anything),
    );
    await verbindung.anmelden(_email, _passwort);
    addTearDown(verbindung.abmelden);
    // Der Smoke-Server läuft ohne Artikeldatei: nur die Spaltenköpfe
    expect(
      await verbindung.exportGrandTotal(Planung.start, Uri.base),
      grandTotalCsv(const []),
    );
  });

  testWidgets('bietet die Datei als Download an', (_) async {
    final links = <web.HTMLAnchorElement>[];
    final mitschnitt = ((web.Event e) {
      final ziel = e.target;
      if (ziel.isA<web.HTMLAnchorElement>()) {
        links.add(ziel! as web.HTMLAnchorElement);
        // nicht wirklich herunterladen
        e.preventDefault();
      }
    }).toJS;
    web.document.addEventListener('click', mitschnitt);
    addTearDown(() => web.document.removeEventListener('click', mitschnitt));

    bieteDateiAn('GrandTotal_Import.csv', 'Bezeichnung;Anzahl\r\n');

    expect(links, hasLength(1));
    expect(links.single.download, 'GrandTotal_Import.csv');
    expect(links.single.href, startsWith('blob:'));
    // der Link bleibt nicht im Dokument
    expect(links.single.isConnected, isFalse);
  });
}
