import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:connectanum_client/connectanum.dart';
import 'package:connectanum_client/json.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// Rundlauf eines RPC-Aufrufs über den Planer-Router (WebSocket, JSON).
class RouterRpcBenchmark extends AsyncBenchmarkBase {
  RouterRpcBenchmark() : super('server.Router.rpcRundlauf');

  late PlanerRouter _router;
  late Session _dienst;
  late Session _kunde;

  @override
  Future<void> setup() async {
    _router = PlanerRouter.starte(
      const RouterEinstellungen(port: 0, healthListen: '127.0.0.1:0'),
    );
    await Future<void>.delayed(const Duration(milliseconds: 500));
    _dienst = await _verbinde();
    _kunde = await _verbinde();
    final registrierung = await _dienst.register('de.robinienwelt.bench.echo');
    registrierung.onInvoke(
      (aufruf) => aufruf.respondWith(arguments: aufruf.arguments),
    );
  }

  @override
  Future<void> run() async {
    await _kunde.callSingle('de.robinienwelt.bench.echo', arguments: ['ping']);
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
