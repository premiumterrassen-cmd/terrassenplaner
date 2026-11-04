import 'dart:io';
import 'dart:typed_data';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:connectanum_client/connectanum.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// Typische Planung: drei Flächen (O-Form mit Ausschnitt, L-Form, Rechteck
/// zweifach gebaut).
Planung typischePlanung(int laenge) => Planung([
  Terrassenflaeche(Planungsstand.start.mitForm(Terrassenform.oForm)),
  Terrassenflaeche(Planungsstand.start.mitForm(Terrassenform.lForm)),
  Terrassenflaeche(
    Planungsstand(
      grundriss: RechteckGrundriss(Millimeter(laenge), const Millimeter(3000)),
    ),
    haeufigkeit: 2,
  ),
], aktiv: 2);

/// M9-05: SPEICHERN einer neuen Version und LADEN derselben Version über
/// den Planer-Router (FlatBuffers-Transport, ObjectBox auf der Platte) –
/// ein Rundlauf je Richtung. Zwei abwechselnde Planungen, damit jedes
/// Speichern wirklich eine Version anlegt.
class KonfigurationBenchmark extends AsyncBenchmarkBase {
  KonfigurationBenchmark() : super('server.Konfiguration.speichernLaden');

  late Directory _ordner;
  late Datenbank _db;
  late PlanerRouter _router;
  late KonfigurationsDienst _dienst;
  late Session _kunde;
  late final List<Uint8List> _planungen = [
    typischePlanung(5400).zuBytes(),
    typischePlanung(5500).zuBytes(),
  ];
  String? _nummer;
  var _lauf = 0;

  @override
  Future<void> setup() async {
    _ordner = Directory.systemTemp.createTempSync('planer-bench-konfig-');
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
    _dienst = await KonfigurationsDienst.starte(
      _router,
      Konfigurationsablage(_db),
    );
    _kunde = await Client(
      realm: WampNamen.realm,
      transport: WebSocketTransport.withFlatBuffersSerializer(
        'ws://127.0.0.1:${_router.webSocketPort}/ws',
      ),
    ).connect().first;
  }

  @override
  Future<void> run() async {
    final inhalt = _planungen[_lauf++ % 2];
    final gespeichert = await _kunde.callSingle(
      WampNamen.konfigurationSpeichern,
      arguments: [inhalt, ?_nummer],
    );
    final [nummer as String, version as int] = gespeichert.arguments!;
    _nummer = nummer;
    final geladen = await _kunde.callSingle(
      WampNamen.konfigurationLaden,
      arguments: [nummer, version],
    );
    if ((geladen.arguments!.single! as Uint8List).length != inhalt.length) {
      throw StateError('geladen ≠ gespeichert');
    }
  }

  @override
  Future<void> teardown() async {
    await _kunde.close();
    await _dienst.stoppe();
    await _router.stoppe();
    _db.schliesse();
    _ordner.deleteSync(recursive: true);
  }
}

Future<void> main() async {
  await KonfigurationBenchmark().report();
}
