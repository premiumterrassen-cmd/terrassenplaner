import 'dart:io';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:connectanum_client/cbor.dart' as cbor_kodierung;
import 'package:connectanum_client/connectanum.dart';
import 'package:connectanum_client/flatbuffers.dart' as fb_kodierung;
import 'package:connectanum_client/json.dart' as json_kodierung;
import 'package:connectanum_router/connectanum_router.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// Serialisierung des WebSocket-Transports (#110: JSON, CBOR, FlatBuffers).
enum Kodierung {
  json(WebSocketSerialization.serializationJson),
  cbor(WebSocketSerialization.serializationCbor),
  flatbuffers(WebSocketSerialization.serializationFlatBuffers);

  const Kodierung(this.protokoll);

  final String protokoll;

  AbstractSerializer serializer() => switch (this) {
    Kodierung.json => json_kodierung.Serializer(),
    Kodierung.cbor => cbor_kodierung.Serializer(),
    Kodierung.flatbuffers => fb_kodierung.Serializer(),
  };
}

/// Planungsähnliche Nutzlast: [anzahl] Dielen mit Lage, Länge und Artikel.
List<Object> planung(int anzahl) => [
  for (var i = 0; i < anzahl; i++)
    {
      'artikel': '10-10-060-022',
      'laenge': 5000,
      'x': i * 65,
      'y': 0,
      'freidiele': false,
    },
];

/// Rundlauf eines RPC-Aufrufs über den Planer-Router (WebSocket).
class RouterRpcBenchmark extends AsyncBenchmarkBase {
  RouterRpcBenchmark(this.kodierung, this.nutzlast, String groesse)
    : super(
        kodierung == Kodierung.json && groesse == 'klein'
            ? 'server.Router.rpcRundlauf'
            : 'server.Router.rpcRundlauf.${kodierung.name}.$groesse',
      );

  final Kodierung kodierung;
  final List<Object> nutzlast;

  late PlanerRouter _router;
  late RouterSession _dienst;
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
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _dienst = await _router.dienstSitzung('bench-dienst');
    _kunde = await _verbinde();
    final registrierung = await _dienst.register(
      '${Rollen.kundeUri}bench.echo',
    );
    registrierung.onInvoke(
      (aufruf) => aufruf.respondWith(arguments: aufruf.arguments),
    );
  }

  @override
  Future<void> run() async {
    await _kunde.callSingle(
      '${Rollen.kundeUri}bench.echo',
      arguments: nutzlast,
    );
  }

  @override
  Future<void> teardown() async {
    await _kunde.close();
    await _dienst.close();
    await _router.stoppe();
  }

  Future<Session> _verbinde() => Client(
    realm: RouterEinstellungen.standardRealm,
    transport: WebSocketTransport(
      'ws://127.0.0.1:${_router.webSocketPort}/ws',
      kodierung.serializer(),
      kodierung.protokoll,
    ),
  ).connect().first;
}

Future<void> main() async {
  for (final kodierung in Kodierung.values) {
    await RouterRpcBenchmark(kodierung, ['ping'], 'klein').report();
    await RouterRpcBenchmark(kodierung, planung(500), 'gross').report();
  }
}
