@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/verbindung/planer_verbindung.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// Ende-zu-Ende gegen einen echten Router mit Hallo-Dienst (M0-12).
void main() {
  test('hallo() liefert die Begrüßung des Servers', () async {
    final health = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final healthPort = health.port;
    await health.close();
    final router = PlanerRouter.starte(
      RouterEinstellungen(
        authToken: 't',
        dienstTicket: 'k',
        port: 0,
        healthListen: '127.0.0.1:$healthPort',
      ),
    );
    addTearDown(router.stoppe);
    final dienst = await HalloDienst.starte(router);
    addTearDown(dienst.stoppe);
    final modell3d = await Modell3dDienst.starte(router);
    addTearDown(modell3d.stoppe);
    final planung = await PlanungsDienst.starte(router);
    addTearDown(planung.stoppe);

    final verbindung = PlanerVerbindung(
      Uri.parse('ws://127.0.0.1:${router.webSocketPort}/ws'),
    );
    expect(verbindung.adresse.port, router.webSocketPort);
    expect(
      await verbindung.hallo(),
      'Verbunden mit Terrassenplaner – ALTO HOLZ',
    );
    final glb = await verbindung.modell3dRechteck(
      const Millimeter(4000),
      const Millimeter(3000),
    );
    expect(glb, isA<Uint8List>());
    expect(
      glb,
      Modell3dDienst.rechteck(const Millimeter(4000), const Millimeter(3000)),
    );
    // M4-02/M4-14: Planung hin, Berechnung zurück – typisiert
    final berechnung = await verbindung.berechne(Planung.start);
    expect(berechnung.flaecheQuadratmeter, 14.832);
    expect(berechnung.umriss[1], const Punkt(4800, 0));
  });

  test('Packed-Nutzlast materialisiert als ein Binärargument', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    expect(PlanerVerbindung.verpacke(bytes).arguments, [bytes]);
  });
}
