@Timeout(Duration(minutes: 2))
library;

import 'dart:typed_data';

import 'package:connectanum_client/connectanum.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

import 'hilfen.dart';

void main() {
  late PlanerRouter router;
  late Modell3dDienst dienst;
  late Session kunde;

  setUp(() async {
    router = PlanerRouter.starte(await testEinstellungen());
    dienst = await Modell3dDienst.starte(router);
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

  Future<Result> rufe(List<Object?> argumente) => kunde
      .callSingle(WampNamen.modell3dRechteck, arguments: argumente)
      .timeout(const Duration(seconds: 5));

  test('Kennung und Grenzen', () {
    expect(Modell3dDienst.sitzungId, 'modell3d-dienst');
    expect(
      [Modell3dDienst.kleinsteSeite, Modell3dDienst.groessteSeite],
      [const Millimeter(500), const Millimeter(20000)],
    );
  });

  test('liefert das GLB als Binärdaten', () async {
    final antwort = await rufe([4000, 3000]);
    final glb = antwort.arguments!.single as Uint8List;
    expect(
      glb,
      Modell3dDienst.rechteck(const Millimeter(4000), const Millimeter(3000)),
    );
    expect(ByteData.sublistView(glb).getUint32(0, Endian.little), 0x46546C67);
  });

  test('Beispielaufbau: Diele 120 x 23, UK 70 x 45, empfohlener Abstand', () {
    final erwartet = glbAus(
      rechteckTerrasse(
        laenge: const Millimeter(4000),
        breite: const Millimeter(3000),
        dielenbreite: const Millimeter(120),
        dielenstaerke: const Millimeter(23),
        ukBreite: const Millimeter(70),
        ukHoehe: const Millimeter(45),
        ukAchsabstand: robinie.ukAchsabstandEmpfohlen,
      ),
    );
    expect(
      Modell3dDienst.rechteck(const Millimeter(4000), const Millimeter(3000)),
      erwartet,
    );
  });

  test('Grenzen gelten einschließlich', () async {
    for (final masse in [
      [500, 500],
      [20000, 500],
      [500, 20000],
    ]) {
      final antwort = await rufe(masse);
      expect(antwort.arguments!.single, isA<Uint8List>(), reason: '$masse');
    }
  });

  test('ungültige Maße sind ein Fehler', () async {
    for (final argumente in <List<Object?>>[
      [499, 3000],
      [3000, 499],
      [20001, 3000],
      [3000, 20001],
      ['4000', 3000],
      [4000],
      [],
    ]) {
      await expectLater(
        rufe(argumente),
        throwsA(
          isA<Object>()
              .having(
                (e) => (e as dynamic).error,
                'error',
                WampNamen.masseUngueltig,
              )
              .having((e) => (e as dynamic).arguments, 'arguments', argumente),
        ),
        reason: '$argumente',
      );
    }
  });
}
