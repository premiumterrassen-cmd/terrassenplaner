@Timeout(Duration(minutes: 2))
library;

import 'dart:typed_data';

import 'package:connectanum_client/connectanum.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

import 'hilfen.dart';

void main() {
  test('typisierter Stapel läuft byte-genau vom Kunden zum Dienst', () async {
    final router = PlanerRouter.starte(await testEinstellungen());
    addTearDown(router.stoppe);
    final dienst = await router.dienstSitzung('ppt-dienst');
    final angekommen = <Uint8List?>[];
    final kennung = <String?>[];
    final registrierung = await dienst.register('${Rollen.kundeUri}ppt.stapel');
    registrierung.onLazyInvokePayload((aufruf) {
      angekommen.add(aufruf.payload.packedPayloadBytes);
      kennung.addAll([aufruf.pptScheme, aufruf.pptSerializer]);
      aufruf.respondWith(arguments: [Stapel(angekommen.single!).laenge]);
    });
    final kunde = await Client(
      realm: RouterEinstellungen.standardRealm,
      transport: WebSocketTransport.withFlatBuffersSerializer(
        'ws://127.0.0.1:${router.webSocketPort}/ws',
      ),
    ).connect().first.timeout(const Duration(seconds: 20));
    addTearDown(kunde.close);

    final stapel = Stapel.baue(AenderungSicht.schemaName, [
      for (var seq = 1; seq <= 3; seq++)
        baueAenderung(
          schluessel: 'k:$seq',
          knoten: 'k',
          seq: seq,
          entitaet: 'Benutzer',
          uid: 'u-$seq',
          partition: 'global',
          hlc: 'h-$seq',
          art: 'anlegen',
        ),
    ]);
    final antwort = await kunde.callSingleWithLazyPayload(
      '${Rollen.kundeUri}ppt.stapel',
      payload: LazyMessagePayload.packed(
        encoding: LazyPayloadEncoding.flatbuffers,
        packedPayloadBytes: stapel,
        packedPayloadDecoder: (b) => (arguments: [b], argumentsKeywords: null),
      ),
      options: CallOptions(
        pptScheme: WampNamen.pptSchema,
        pptSerializer: WampNamen.pptSerializer,
      ),
    );

    expect(antwort.arguments, [3]);
    expect(angekommen.single, stapel);
    expect(kennung, [WampNamen.pptSchema, WampNamen.pptSerializer]);
    final empfangen = Stapel(angekommen.single!);
    expect(empfangen.schema, 'Aenderung');
    expect(AenderungSicht(empfangen[2]).uid, 'u-3');
  });
}
