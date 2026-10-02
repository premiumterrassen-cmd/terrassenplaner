@Timeout(Duration(minutes: 2))
library;

import 'dart:async';
import 'dart:io';

import 'package:connectanum_client/connectanum.dart';
import 'package:connectanum_client/json.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

void main() {
  late PlanerRouter router;

  setUpAll(() async {
    router = PlanerRouter.starte(
      const RouterEinstellungen(port: 0, healthListen: '127.0.0.1:0'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });

  tearDownAll(() => router.stoppe());

  Future<Session> verbinde() {
    final client = Client(
      realm: RouterEinstellungen.standardRealm,
      transport: WebSocketTransport(
        'ws://127.0.0.1:${router.webSocketPort}/ws',
        Serializer(),
        WebSocketSerialization.serializationJson,
      ),
    );
    return client.connect().first.timeout(const Duration(seconds: 20));
  }

  test('Client ruft einen registrierten Dienst auf', () async {
    final dienst = await verbinde();
    final kunde = await verbinde();
    final registrierung = await dienst.register('de.robinienwelt.test.echo');
    registrierung.onInvoke(
      (aufruf) =>
          aufruf.respondWith(arguments: ['pong:${aufruf.arguments!.first}']),
    );

    final ergebnis = await kunde.callSingle(
      'de.robinienwelt.test.echo',
      arguments: ['ping'],
    );
    expect(ergebnis.arguments, ['pong:ping']);

    await kunde.close();
    await dienst.close();
  });

  test('Client empfängt ein veröffentlichtes Ereignis', () async {
    final empfaenger = await verbinde();
    final sender = await verbinde();
    final abo = await empfaenger.subscribe('de.robinienwelt.test.ereignis');
    final erstes = abo.eventStream!.first;

    await sender.publish(
      'de.robinienwelt.test.ereignis',
      arguments: ['hallo'],
      options: PublishOptions(acknowledge: true),
    );
    final ereignis = await erstes.timeout(const Duration(seconds: 10));
    expect(ereignis.arguments, ['hallo']);

    await sender.close();
    await empfaenger.close();
  });

  test('Health-Endpunkt meldet Bereitschaft', () async {
    final http = HttpClient();
    final antwort = await (await http.get(
      '127.0.0.1',
      router.healthPort,
      '/healthz',
    )).close();
    expect(antwort.statusCode, 200);
    http.close();
  });
}
