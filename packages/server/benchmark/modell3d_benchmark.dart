import 'dart:io';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:connectanum_client/connectanum.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// Erzeugung des GLB einer Rechteck-Terrasse auf dem Server (M3-10).
class GlbErzeugungBenchmark extends BenchmarkBase {
  GlbErzeugungBenchmark(this.laenge, this.breite, String groesse)
    : super('server.Modell3d.glb.$groesse');

  final Millimeter laenge;
  final Millimeter breite;
  var _bytes = 0;

  @override
  void run() => _bytes += Modell3dDienst.rechteck(laenge, breite).length;

  @override
  void teardown() {
    if (_bytes == 0) throw StateError('Benchmark hat nichts erzeugt');
  }
}

/// Erzeugung und Übertragung über den Router (FlatBuffers wie in der App).
class Modell3dRpcBenchmark extends AsyncBenchmarkBase {
  Modell3dRpcBenchmark() : super('server.Modell3d.rpc.4x3m');

  late PlanerRouter _router;
  late Modell3dDienst _dienst;
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
    _dienst = await Modell3dDienst.starte(_router);
    _kunde = await Client(
      realm: WampNamen.realm,
      transport: WebSocketTransport.withFlatBuffersSerializer(
        'ws://127.0.0.1:${_router.webSocketPort}/ws',
      ),
    ).connect().first;
  }

  @override
  Future<void> run() async {
    await _kunde.callSingle(
      WampNamen.modell3dRechteck,
      arguments: [4000, 3000],
    );
  }

  @override
  Future<void> teardown() async {
    await _kunde.close();
    await _dienst.stoppe();
    await _router.stoppe();
  }
}

Future<void> main() async {
  GlbErzeugungBenchmark(
    const Millimeter(4000),
    const Millimeter(3000),
    '4x3m',
  ).report();
  GlbErzeugungBenchmark(
    const Millimeter(12000),
    const Millimeter(8000),
    '12x8m',
  ).report();
  await Modell3dRpcBenchmark().report();
}
