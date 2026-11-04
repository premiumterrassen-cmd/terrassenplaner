@Timeout(Duration(minutes: 2))
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:connectanum_client/connectanum.dart';
import 'package:connectanum_router/connectanum_router.dart'
    as router
    show Invocation;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

import 'hilfen.dart';

Uint8List _planung(int laenge) => Planung([
  Terrassenflaeche(
    Planungsstand(
      grundriss: RechteckGrundriss(Millimeter(laenge), const Millimeter(3000)),
    ),
  ),
]).zuBytes();

const _schluessel = '0123456789abcdef0123456789abcdef';

/// Kennung der ersten gespeicherten Konfiguration (`ZaehlZufall`).
const _erste = '2026-11-04-0001-ABCDE';

void main() {
  late Directory ordner;
  late Datenbank db;
  late PlanerRouter router;
  late KonfigurationsDienst dienst;
  late Session kunde;

  setUp(() async {
    ordner = Directory.systemTemp.createTempSync('planer-konfig-dienst-');
    db = Datenbank.oeffne('${ordner.path}/daten', knoten: 'k1');
    router = PlanerRouter.starte(await testEinstellungen());
    dienst = await KonfigurationsDienst.starte(
      router,
      Konfigurationsablage(
        db,
        uhr: () => DateTime(2026, 11, 4, 12),
        zufall: ZaehlZufall(),
      ),
    );
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
    db.schliesse();
    ordner.deleteSync(recursive: true);
  });

  Future<List<Object?>> rufe(String prozedur, List<Object?> argumente) async =>
      (await kunde
              .callSingle(prozedur, arguments: argumente)
              .timeout(const Duration(seconds: 5)))
          .arguments ??
      const [];

  Matcher fehler(String uri, [Object? argumente = isEmpty]) => throwsA(
    isA<Object>()
        .having((e) => (e as dynamic).error, 'error', uri)
        .having(
          (e) => (e as dynamic).arguments as List? ?? const [],
          'arguments',
          argumente,
        ),
  );

  test('Kennung und Grenzen', () {
    expect(KonfigurationsDienst.sitzungId, 'konfigurations-dienst');
    expect(KonfigurationsDienst.groessterInhalt, 1048576);
    expect(KonfigurationsDienst.schluesselMuster.hasMatch(_schluessel), isTrue);
  });

  test(
    'speichern vergibt Kennung und Versionen, laden liefert identisch',
    () async {
      expect(await rufe(WampNamen.konfigurationSpeichern, [_planung(4000)]), [
        _erste,
        1,
      ]);
      expect(
        await rufe(WampNamen.konfigurationSpeichern, [
          _planung(5000),
          // tolerant eingelesen
          '2026 11 04 0001 abcde',
        ]),
        [_erste, 2],
      );
      final v1 = await rufe(WampNamen.konfigurationLaden, [_erste, 1]);
      expect(v1, [_planung(4000)]);
      expect(
        Planung.ausBytes(v1.single! as Uint8List),
        Planung.ausBytes(_planung(4000)),
      );
      expect(await rufe(WampNamen.konfigurationLaden, [_erste, 2]), [
        _planung(5000),
      ]);
    },
  );

  test('unbekannte Nummer oder Version', () async {
    await rufe(WampNamen.konfigurationSpeichern, [_planung(4000)]);
    await expectLater(
      rufe(WampNamen.konfigurationLaden, [_erste, 2]),
      fehler(WampNamen.konfigurationUnbekannt, ['2026-11-04-0001', 2]),
    );
    await expectLater(
      rufe(WampNamen.konfigurationSpeichern, [
        _planung(4000),
        '2026-11-04-0002-ABCDE',
      ]),
      fehler(WampNamen.konfigurationUnbekannt, ['2026-11-04-0002']),
    );
  });

  test('falscher oder fehlender Prüfcode: wie unbekannt (M9-05b)', () async {
    await rufe(WampNamen.konfigurationSpeichern, [_planung(4000)]);
    for (final kennung in [
      '2026-11-04-0001-ABCDF',
      '2026-11-04-0001-FGHJK',
      '2026-11-04-0001',
      '2026-11-04-0001-ABCD',
      '2026-11-04-0001-ABC0E',
    ]) {
      await expectLater(
        rufe(WampNamen.konfigurationLaden, [kennung, 1]),
        fehler(WampNamen.konfigurationUnbekannt, ['2026-11-04-0001', 1]),
        reason: kennung,
      );
    }
    // gleiche Antwort wie für eine Nummer, die es nicht gibt
    await expectLater(
      rufe(WampNamen.konfigurationLaden, ['2026-11-04-0002-ABCDE', 1]),
      fehler(WampNamen.konfigurationUnbekannt, ['2026-11-04-0002', 1]),
    );
    await expectLater(
      rufe(WampNamen.konfigurationSpeichern, [
        _planung(5000),
        '2026-11-04-0001-FGHJK',
      ]),
      fehler(WampNamen.konfigurationUnbekannt, ['2026-11-04-0001']),
    );
    await expectLater(
      rufe(WampNamen.entwurfSpeichern, [
        _schluessel,
        _planung(5000),
        '2026-11-04-0001-FGHJK',
        1,
      ]),
      fehler(WampNamen.konfigurationUnbekannt, ['2026-11-04-0001', 1]),
    );
    expect(db.store.box<KonfigurationsVersion>().count(), 1);
    expect(db.store.box<Zwischenstand>().count(), 0);
  });

  test('Mitarbeiter ohne Prüfcode: noch nicht freigeschaltet (M9-10)', () {
    expect(KonfigurationsDienst.darfOhnePruefcodeLaden(_KeinAufruf()), isFalse);
  });

  test('ungültige Aufrufe', () async {
    for (final (prozedur, argumente) in <(String, List<Object?>)>[
      (WampNamen.konfigurationSpeichern, []),
      (WampNamen.konfigurationSpeichern, ['x']),
      (
        WampNamen.konfigurationSpeichern,
        [
          Uint8List.fromList([1, 2, 3]),
        ],
      ),
      (
        WampNamen.konfigurationSpeichern,
        [Uint8List(KonfigurationsDienst.groessterInhalt + 1)],
      ),
      (
        WampNamen.konfigurationSpeichern,
        [_planung(4000), '2026-13-01-0001-ABCDE'],
      ),
      (WampNamen.konfigurationSpeichern, [_planung(4000), '2026-11-04-0001']),
      (WampNamen.konfigurationSpeichern, [_planung(4000), _erste, 1]),
      (WampNamen.konfigurationLaden, [_erste]),
      (WampNamen.konfigurationLaden, [_erste, 0]),
      (WampNamen.konfigurationLaden, ['2026-13-01-0001-ABCDE', 1]),
      (WampNamen.konfigurationLaden, ['falsch', 1]),
      (WampNamen.entwurfSpeichern, [_schluessel]),
      (WampNamen.entwurfSpeichern, ['kurz', _planung(4000)]),
      (WampNamen.entwurfSpeichern, [_schluessel.toUpperCase(), _planung(4000)]),
      (WampNamen.entwurfSpeichern, [_schluessel, Uint8List(3)]),
      (WampNamen.entwurfSpeichern, [_schluessel, _planung(4000), _erste]),
      (
        WampNamen.entwurfSpeichern,
        [_schluessel, _planung(4000), '2026-11-04-0001', 1],
      ),
      (WampNamen.entwurfSpeichern, [_schluessel, _planung(4000), 'x', 1]),
      (WampNamen.entwurfLaden, []),
      (WampNamen.entwurfLaden, ['$_schluessel ']),
    ]) {
      await expectLater(
        rufe(prozedur, argumente),
        fehler(WampNamen.konfigurationUngueltig, hasLength(1)),
        reason: '$prozedur $argumente',
      );
    }
    // Ungültiges wird nicht gespeichert
    expect(db.letzteSequenz, 0);
  });

  test('Fehlertexte nennen Argument und Grund', () async {
    final zuGross = KonfigurationsDienst.groessterInhalt + 1;
    await expectLater(
      rufe(WampNamen.konfigurationSpeichern, [Uint8List(zuGross)]),
      fehler(WampNamen.konfigurationUngueltig, [
        'Invalid argument (inhalt): zu groß: $zuGross',
      ]),
    );
    await expectLater(
      rufe(WampNamen.entwurfLaden, ['kurz']),
      fehler(WampNamen.konfigurationUngueltig, [
        'Invalid argument (schluessel): kein Sitzungsschlüssel: "kurz"',
      ]),
    );
  });

  test('Entwurf: merken, laden, mit und ohne Bezug', () async {
    await expectLater(
      rufe(WampNamen.entwurfLaden, [_schluessel]),
      fehler(WampNamen.entwurfUnbekannt),
    );
    expect(
      await rufe(WampNamen.entwurfSpeichern, [_schluessel, _planung(4000)]),
      isEmpty,
    );
    expect(await rufe(WampNamen.entwurfLaden, [_schluessel]), [_planung(4000)]);
    await rufe(WampNamen.konfigurationSpeichern, [_planung(4000)]);
    await rufe(WampNamen.entwurfSpeichern, [
      _schluessel,
      _planung(4500),
      _erste.toLowerCase(),
      3,
    ]);
    // Bezug mit Prüfcode: der Sitzungsschlüssel ist selbst geheim
    expect(await rufe(WampNamen.entwurfLaden, [_schluessel]), [
      _planung(4500),
      _erste,
      3,
    ]);
    expect(db.store.box<Zwischenstand>().count(), 1);
  });
}

/// Für die Stelle ohne Prüfcode genügt irgendein Aufruf – sie fragt ihn
/// (noch) nicht.
final class _KeinAufruf implements router.Invocation {
  @override
  dynamic noSuchMethod(_) => throw UnimplementedError();
}
