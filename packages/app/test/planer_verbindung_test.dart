@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/verbindung/planer_verbindung.dart';
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

    final verbindung = PlanerVerbindung(
      Uri.parse('ws://127.0.0.1:${router.webSocketPort}/ws'),
    );
    expect(verbindung.adresse.port, router.webSocketPort);
    expect(
      await verbindung.hallo(),
      'Verbunden mit Terrassenplaner – ALTO HOLZ',
    );
  });
}
