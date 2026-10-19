import 'dart:io';
import 'dart:typed_data';

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:connectanum_client/connectanum.dart';
import 'package:connectanum_client/flatbuffers.dart' as fb_kodierung;
import 'package:connectanum_client/json.dart' as json_kodierung;
import 'package:connectanum_router/connectanum_router.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// Anzahl der Änderungsdatensätze je Aufruf.
const anzahl = 500;

/// #110 Schritt 2: dieselben 500 Änderungen hin und zurück über den Router –
/// als JSON-Maps gegen einen typisierten FlatBuffers-Stapel (Packed PPT).
/// Gemessen wird Bauen, Rundlauf und Lesen aller Felder beim Aufrufer.
abstract class StapelRpcBenchmark extends AsyncBenchmarkBase {
  StapelRpcBenchmark(String variante)
    : super('server.Router.stapelRundlauf.$variante');

  late PlanerRouter _router;
  late RouterSession _dienst;
  late Session kunde;

  static const prozedur = '${Rollen.kundeUri}bench.stapel';

  AbstractSerializer get serializer;
  String get protokoll;
  void beantworte(Registered registrierung);

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
    beantworte(await _dienst.register(prozedur));
    kunde = await Client(
      realm: RouterEinstellungen.standardRealm,
      transport: WebSocketTransport(
        'ws://127.0.0.1:${_router.webSocketPort}/ws',
        serializer,
        protokoll,
      ),
    ).connect().first;
  }

  @override
  Future<void> teardown() async {
    await kunde.close();
    await _dienst.close();
    await _router.stoppe();
  }
}

/// JSON: jede Änderung als Map mit denselben acht Feldern.
class JsonStapel extends StapelRpcBenchmark {
  JsonStapel() : super('json');

  @override
  AbstractSerializer get serializer => json_kodierung.Serializer();

  @override
  String get protokoll => WebSocketSerialization.serializationJson;

  @override
  void beantworte(Registered registrierung) => registrierung.onInvoke(
    (aufruf) => aufruf.respondWith(arguments: aufruf.arguments),
  );

  @override
  Future<void> run() async {
    final antwort = await kunde.callSingle(
      StapelRpcBenchmark.prozedur,
      arguments: [
        for (var i = 0; i < anzahl; i++)
          {
            'schluessel': 'k:$i',
            'knoten': 'k',
            'seq': i,
            'entitaet': 'Benutzer',
            'uid': 'u-$i',
            'partition': 'global',
            'hlc': 'h-$i',
            'art': 'anlegen',
          },
      ],
    );
    var summe = 0;
    for (final eintrag in antwort.arguments!) {
      final e = eintrag as Map<String, dynamic>;
      summe +=
          (e['seq'] as int) +
          [
            e['schluessel'],
            e['knoten'],
            e['entitaet'],
            e['uid'],
            e['partition'],
            e['hlc'],
            e['art'],
          ].fold(0, (s, t) => s + (t as String).length);
    }
    if (summe == 0) throw StateError('leer');
  }
}

/// FlatBuffers: ein Stapel aus ObjectBox-kompatiblen Datensätzen, der Dienst
/// reicht die Bytes unverändert zurück.
class TypisierterStapel extends StapelRpcBenchmark {
  TypisierterStapel() : super('flatbuffersTypisiert');

  static final _optionen = CallOptions(
    pptScheme: WampNamen.pptSchema,
    pptSerializer: WampNamen.pptSerializer,
  );

  static LazyMessagePayload _packe(Uint8List bytes) =>
      LazyMessagePayload.packed(
        encoding: LazyPayloadEncoding.flatbuffers,
        packedPayloadBytes: bytes,
        packedPayloadDecoder: (b) => (arguments: [b], argumentsKeywords: null),
      );

  @override
  AbstractSerializer get serializer => fb_kodierung.Serializer();

  @override
  String get protokoll => WebSocketSerialization.serializationFlatBuffers;

  @override
  void beantworte(Registered registrierung) =>
      registrierung.onLazyInvokePayload(
        (aufruf) => aufruf.respondWith(
          lazyPayload: _packe(aufruf.payload.packedPayloadBytes!),
          options: YieldOptions(
            pptScheme: WampNamen.pptSchema,
            pptSerializer: WampNamen.pptSerializer,
          ),
        ),
      );

  @override
  Future<void> run() async {
    final stapel = Stapel.baue(AenderungSicht.schemaName, [
      for (var i = 0; i < anzahl; i++)
        baueAenderung(
          schluessel: 'k:$i',
          knoten: 'k',
          seq: i,
          entitaet: 'Benutzer',
          uid: 'u-$i',
          partition: 'global',
          hlc: 'h-$i',
          art: 'anlegen',
        ),
    ]);
    final antwort = await kunde.callSingleLazyPayloadView(
      StapelRpcBenchmark.prozedur,
      payload: _packe(stapel),
      options: _optionen,
    );
    var summe = 0;
    for (final eintrag in Stapel(
      antwort.payload.packedPayloadBytes!,
    ).eintraege) {
      final e = AenderungSicht(eintrag);
      summe +=
          e.seq +
          [
            e.schluessel,
            e.knoten,
            e.entitaet,
            e.uid,
            e.partition,
            e.hlc,
            e.art,
          ].fold(0, (s, t) => s + t.length);
    }
    if (summe == 0) throw StateError('leer');
  }
}

Future<void> main() async {
  await JsonStapel().report();
  await TypisierterStapel().report();
}
