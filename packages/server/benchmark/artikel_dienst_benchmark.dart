import 'dart:io';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:connectanum_client/connectanum.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// Artikeldatei in der Größenordnung der Upload-Datei v6: 50 Beläge mit je
/// 5 Verweisen je Beziehung auf 200 Zubehörartikel.
Artikeldatei artikeldatei() {
  Artikel artikel(String nummer, Artikelart art) => Artikel(
    nummer: Artikelnummer(nummer),
    titel: 'Artikel $nummer',
    art: art,
    einheit: Verkaufseinheit(Mengeneinheit.stueck),
    holzart: art.istHolz ? robinie : null,
    serie: art.istHolz ? premiumSelect : null,
    bilder: const ['profil.webp', 'stirn.webp'],
  );
  final zubehoer = [
    for (var i = 0; i < 200; i++)
      Artikeleintrag(artikel: artikel('Z-$i', Artikelart.sonstiges)),
  ];
  return Artikeldatei(
    quelle: 'benchmark',
    version: '1',
    eintraege: [
      ...zubehoer,
      for (var i = 0; i < 50; i++)
        Artikeleintrag(
          artikel: artikel('B-$i', Artikelart.diele),
          verweise: {
            for (final (j, b) in Beziehung.values.indexed)
              b.spalte: [
                for (var k = 0; k < 5; k++)
                  zubehoer[(i + j * 5 + k) % zubehoer.length].artikel.nummer,
              ],
          },
          benoetigt: {zubehoer[i].artikel.nummer: 2},
        ),
    ],
  );
}

/// Rundlauf eines Artikeldienst-Aufrufs über den Planer-Router (FlatBuffers
/// wie in der App, M2-06).
class ArtikelDienstBenchmark extends AsyncBenchmarkBase {
  ArtikelDienstBenchmark(super.name, this._aufruf);

  final Future<void> Function(Session kunde) _aufruf;

  late PlanerRouter _router;
  late ArtikelDienst _dienst;
  late Session _kunde;

  @override
  Future<void> setup() async {
    final health = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final healthPort = health.port;
    await health.close();
    _router = PlanerRouter.starte(
      RouterEinstellungen(
        authToken: 'bench',
        dienstTicket: 'bench',
        port: 0,
        healthListen: '127.0.0.1:$healthPort',
      ),
    );
    _dienst = await ArtikelDienst.starte(_router, artikeldatei());
    _kunde = await Client(
      realm: WampNamen.realm,
      transport: WebSocketTransport.withFlatBuffersSerializer(
        'ws://127.0.0.1:${_router.webSocketPort}/ws',
      ),
    ).connect().first;
  }

  @override
  Future<void> run() => _aufruf(_kunde);

  @override
  Future<void> teardown() async {
    await _kunde.close();
    await _dienst.stoppe();
    await _router.stoppe();
  }
}

Future<void> main() async {
  await ArtikelDienstBenchmark(
    'server.ArtikelDienst.liste',
    (kunde) => kunde.callSingle(WampNamen.artikelListe),
  ).report();
  await ArtikelDienstBenchmark(
    'server.ArtikelDienst.regeln',
    (kunde) => kunde.callSingle(WampNamen.artikelRegeln, arguments: ['B-7']),
  ).report();
}
