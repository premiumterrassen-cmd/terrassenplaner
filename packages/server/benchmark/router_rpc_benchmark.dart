import 'dart:io';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:connectanum_client/connectanum.dart';
import 'package:connectanum_client/json.dart';
import 'package:connectanum_router/connectanum_router.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// Rundlauf eines RPC-Aufrufs über den Planer-Router (WebSocket, JSON).
class RouterRpcBenchmark extends AsyncBenchmarkBase {
  RouterRpcBenchmark() : super('server.Router.rpcRundlauf');

  late PlanerRouter _router;
  late RouterSession _dienst;
  late Session _kunde;

  @override
  Future<void> setup() async {
    final auth = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final authPort = auth.port;
    await auth.close();
    _router = await PlanerRouter.starte(
      RouterEinstellungen(
        port: 0,
        healthListen: '127.0.0.1:0',
        authListen: '127.0.0.1:$authPort',
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
      arguments: ['ping'],
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
      Serializer(),
      WebSocketSerialization.serializationJson,
    ),
  ).connect().first;
}

Future<void> main() => RouterRpcBenchmark().report();
