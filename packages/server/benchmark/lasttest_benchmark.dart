import 'dart:io';
import 'dart:typed_data';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:connectanum_client/connectanum.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// M10-02, kurzer Lasttest für die Build-Chain (der lange Lauf ist
/// tool/lasttest.sh): Router mit Artikel-, Planungs- und
/// Konfigurationsdienst im selben Prozess, erfundene Artikeldaten
/// ([Lastdaten]), ObjectBox auf der Platte.
abstract class LasttestBenchmark extends AsyncBenchmarkBase {
  LasttestBenchmark(super.name, this.sitzungen);

  final int sitzungen;

  late Directory _ordner;
  late Datenbank _db;
  late PlanerRouter _router;
  late List<Future<void> Function()> _stopp;
  late List<Session> kunden;

  @override
  Future<void> setup() async {
    _ordner = Directory.systemTemp.createTempSync('planer-bench-last-');
    _db = Datenbank.oeffne('${_ordner.path}/daten', knoten: 'bench');
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
    final artikel = await ArtikelDienst.starte(_router, Lastdaten.artikeldatei);
    final planung = await PlanungsDienst.starte(
      _router,
      belag: artikel.belag,
      regelwerk: () => artikel.regelwerk,
      unterkonstruktion: (s) =>
          artikel.unterkonstruktion(s.belag, s.unterkonstruktion),
    );
    final konfiguration = await KonfigurationsDienst.starte(
      _router,
      Konfigurationsablage(_db),
    );
    _stopp = [artikel.stoppe, planung.stoppe, konfiguration.stoppe];
    final url = 'ws://127.0.0.1:${_router.webSocketPort}/ws';
    kunden = await Future.wait([
      for (var i = 0; i < sitzungen; i++)
        Client(
          realm: WampNamen.realm,
          transport: WebSocketTransport.withFlatBuffersSerializer(url),
        ).connect().first,
    ]);
  }

  @override
  Future<void> teardown() async {
    for (final k in kunden) {
      await Lastlauf.schliesse(k);
    }
    for (final s in _stopp) {
      await s();
    }
    await _router.stoppe();
    _db.schliesse();
    _ordner.deleteSync(recursive: true);
  }
}

/// 20 Sitzungen machen gleichzeitig je eine Bedienrunde: drei
/// Berechnungen, Entwurf, SPEICHERN, LADEN (120 Aufrufe je Durchlauf).
class GleichzeitigBenchmark extends LasttestBenchmark {
  GleichzeitigBenchmark() : super('server.Lasttest.gleichzeitig20', 20);

  final _inhalt = Lastdaten.typisch().zuBytes();

  @override
  Future<void> run() =>
      Future.wait([for (var i = 0; i < sitzungen; i++) _runde(kunden[i], i)]);

  Future<void> _runde(Session s, int nummer) async {
    for (var i = 0; i < 3; i++) {
      await Lastlauf.berechne(s, _inhalt);
    }
    await s.callSingle(
      WampNamen.entwurfSpeichern,
      arguments: [nummer.toRadixString(16).padLeft(32, '0'), _inhalt],
    );
    final gespeichert = await s.callSingle(
      WampNamen.konfigurationSpeichern,
      arguments: [_inhalt],
    );
    final [kennung as String, version as int] = gespeichert.arguments!;
    final geladen = await s.callSingle(
      WampNamen.konfigurationLaden,
      arguments: [kennung, version],
    );
    if ((geladen.arguments!.first! as Uint8List).length != _inhalt.length) {
      throw StateError('geladen ≠ gespeichert');
    }
  }
}

/// Großes Projekt ([Lastdaten.gross], rund 8 600 m² mit
/// Verschnittoptimierung) über den Router berechnen.
class GrossesProjektBenchmark extends LasttestBenchmark {
  GrossesProjektBenchmark() : super('server.Lasttest.grossesProjekt', 1);

  final _inhalt = Lastdaten.gross().zuBytes();

  @override
  Future<void> run() async {
    final b = await Lastlauf.berechne(kunden.single, _inhalt);
    if (b.materialliste.positionen.isEmpty) throw StateError('leer');
  }
}

Future<void> main() async {
  await GleichzeitigBenchmark().report();
  await GrossesProjektBenchmark().report();
}
