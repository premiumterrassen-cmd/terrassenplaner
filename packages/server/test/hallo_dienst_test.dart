@Timeout(Duration(minutes: 2))
library;

import 'package:connectanum_client/connectanum.dart';
import 'package:connectanum_client/json.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

import 'hilfen.dart';

void main() {
  test('Hallo-Dienst beantwortet die Hallo-Prozedur für Kunden', () async {
    final router = PlanerRouter.starte(await testEinstellungen());
    addTearDown(router.stoppe);
    final dienst = await HalloDienst.starte(router);
    Future<Session> verbinde() => Client(
      realm: WampNamen.realm,
      transport: WebSocketTransport(
        'ws://127.0.0.1:${router.webSocketPort}/ws',
        Serializer(),
        WebSocketSerialization.serializationJson,
      ),
    ).connect().first.timeout(const Duration(seconds: 20));
    final kunde = await verbinde();

    final antwort = await kunde.callSingle(WampNamen.hallo);
    expect(antwort.arguments, ['Verbunden mit Terrassenplaner – ALTO HOLZ']);

    await kunde.close();

    // Nach dem Stopp ist die Prozedur nicht mehr registriert.
    await dienst.stoppe();
    final spaeter = await verbinde();
    await expectLater(spaeter.callSingle(WampNamen.hallo), throwsA(anything));
    await spaeter.close();
  });
}
