@Timeout(Duration(minutes: 2))
library;

import 'dart:typed_data';

import 'package:connectanum_client/connectanum.dart';
import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

import 'hilfen.dart';

void main() {
  late PlanerRouter router;
  late PlanungsDienst dienst;
  late Session kunde;

  setUp(() async {
    router = PlanerRouter.starte(await testEinstellungen());
    dienst = await PlanungsDienst.starte(router);
    kunde = await Client(
      realm: WampNamen.realm,
      transport: WebSocketTransport.withFlatBuffersSerializer(
        'ws://127.0.0.1:${router.webSocketPort}/ws',
      ),
    ).connect().first.timeout(const Duration(seconds: 20));
  });

  tearDown(() async {
    await kunde.close();
    await dienst.stoppe();
    await router.stoppe();
  });

  final ppt = CallOptions(
    pptScheme: WampNamen.pptSchema,
    pptSerializer: WampNamen.pptSerializer,
  );

  Future<LazyResultPayload> rufe(Uint8List bytes) => kunde
      .callSingleLazyPayloadView(
        WampNamen.planungBerechnen,
        payload: PlanungsDienst.verpacke(bytes),
        options: ppt,
      )
      .timeout(const Duration(seconds: 5));

  Matcher fehler(String text) => throwsA(
    isA<Object>()
        .having(
          (e) => (e as dynamic).error,
          'error',
          WampNamen.planungUngueltig,
        )
        .having(
          (e) => ((e as dynamic).arguments as List).single,
          'arguments',
          contains(text),
        ),
  );

  test('Kennung', () {
    expect(PlanungsDienst.sitzungId, 'planungs-dienst');
    expect(PlanungsDienst.ppt.pptScheme, WampNamen.pptSchema);
    expect(PlanungsDienst.ppt.pptSerializer, WampNamen.pptSerializer);
    final bytes = Uint8List.fromList([1, 2, 3]);
    expect(PlanungsDienst.verpacke(bytes).arguments, [bytes]);
  });

  test('Rechteck: Umriss A–D und Fläche (M4-02)', () {
    final b = PlanungsDienst.berechne(
      Planungsstand(
        grundriss: RechteckGrundriss(
          const Millimeter(5400),
          const Millimeter(3600),
        ),
      ),
    );
    expect(b.umriss, const [
      Punkt(0, 0),
      Punkt(5400, 0),
      Punkt(5400, 3600),
      Punkt(0, 3600),
    ]);
    expect(b.flaecheQuadratmeter, 19.44);
    expect(b.ausschnitte, isEmpty);
  });

  test('O-Form: Ausschnitt in der Zeichnung, Fläche außen (M4-06)', () {
    final b = PlanungsDienst.berechne(
      Planungsstand.start.mitForm(Terrassenform.oForm),
    );
    expect(b.flaecheQuadratmeter, 19.44);
    expect(b.ausschnitte.single, Ausschnitt.oForm.kontur.punkte);
    expect(b.ecken, b.umriss);
  });

  test('offene Freiform: Linienzug ohne Fläche (M4-08)', () {
    final offen = FreiformGrundriss(const [Punkt(0, 0), Punkt(1000, 0)]);
    final b = PlanungsDienst.berechne(Planungsstand(grundriss: offen));
    expect(b.geschlossen, isFalse);
    expect(b.flaeche, 0);
    expect(b.umriss, offen.punkte);
    final zu = PlanungsDienst.berechne(
      Planungsstand(
        grundriss: offen.mitPunkt(const Punkt(0, 1000)).geschlossene(),
      ),
    );
    expect(zu.geschlossen, isTrue);
    expect(zu.flaeche, 500000);
  });

  test('Kreis: Fläche exakt, Umriss als Sehnenzug ohne Ecken (M4-07)', () {
    final b = PlanungsDienst.berechne(
      Planungsstand.start.mitForm(Terrassenform.kreis),
    );
    expect(b.flaecheQuadratmeter, closeTo(10.179, 0.0005));
    expect(b.ecken, isEmpty);
    expect(b.umriss.length, greaterThan(100));
    for (final p in b.umriss) {
      expect(p.abstand(const Punkt(1800, 1800)), closeTo(1800, 1e-6));
    }
  });

  test('typisiert hin und zurück über den Router', () async {
    final antwort = await rufe(Planungsstand.start.zuBytes());
    expect(antwort.pptScheme, WampNamen.pptSchema);
    final b = Berechnung.ausBytes(antwort.payload.packedPayloadBytes!);
    expect(b.flaecheQuadratmeter, 14.832);
    expect(b.umriss, hasLength(4));
    expect(b.umriss[2], const Punkt(4800, 3090));
  });

  test('ungültige Maße sind ein Fehler', () async {
    final fbb = fb.Builder();
    final masse = fbb.writeListInt32([4800, 100]);
    fbb
      ..startTable(2)
      ..addUint8(0, 0)
      ..addOffset(1, masse);
    final grundriss = fbb.endTable();
    fbb
      ..startTable(2)
      ..addOffset(1, grundriss);
    fbb.finish(fbb.endTable());
    await expectLater(
      rufe(fbb.buffer),
      fehler('muss zwischen 50 und 3000 cm liegen'),
    );
  });

  test('ohne Grundriss oder ohne typisierte Nutzlast ein Fehler', () async {
    final fbb = fb.Builder()..startTable(2);
    fbb.finish(fbb.endTable());
    await expectLater(rufe(fbb.buffer), fehler('Planungsstand ohne Grundriss'));
    await expectLater(
      kunde
          .callSingle(WampNamen.planungBerechnen, arguments: [1, 2])
          .timeout(const Duration(seconds: 5)),
      fehler('kein typisierter Planungsstand'),
    );
  });
}
