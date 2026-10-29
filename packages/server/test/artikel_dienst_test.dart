@Timeout(Duration(minutes: 2))
library;

import 'dart:async';

import 'package:connectanum_client/connectanum.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

import 'hilfen.dart';

Artikeleintrag _diele(String nummer, Profil profil) => Artikeleintrag(
  artikel: Artikel(
    nummer: Artikelnummer(nummer),
    titel: 'Diele $nummer',
    art: Artikelart.diele,
    einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
    abmessungen: Abmessungen(
      breite: const Millimeter(60),
      staerke: const Millimeter(23),
    ),
    preisBrutto: const Cent(1250),
    holzart: robinie,
    serie: premiumSelect,
    profil: profil,
  ),
  verweise: {
    'moeglicheBefestigungDeck': const [Artikelnummer('80-10-001')],
  },
  angaben: const {'Abstand_UK': 400},
  benoetigt: const {Artikelnummer('80-10-001'): 3},
);

final _clip = Artikeleintrag(
  artikel: Artikel(
    nummer: const Artikelnummer('80-10-001'),
    titel: 'CLIP-FIXX',
    art: Artikelart.clip,
    einheit: Verkaufseinheit(Mengeneinheit.stueck),
  ),
);

Artikeldatei _datei(String version, List<Artikeleintrag> eintraege) =>
    Artikeldatei(quelle: 'test.xlsx', version: version, eintraege: eintraege);

/// Erwartet einen WAMP-Fehler mit dieser URI und diesen Argumenten.
Matcher _wampFehler(String uri, List<Object?> argumente) => throwsA(
  isA<Object>()
      .having((e) => (e as dynamic).error, 'error', uri)
      .having((e) => (e as dynamic).arguments, 'arguments', argumente),
);

/// Aufruf mit Zeitgrenze: eine unbeantwortete Anfrage soll den Test schnell
/// scheitern lassen statt ihn hängen zu lassen.
Future<Result> _rufe(
  Session kunde,
  String prozedur, {
  List<Object?>? arguments,
  Map<String, Object?>? argumentsKeywords,
}) => kunde
    .callSingle(
      prozedur,
      arguments: arguments,
      argumentsKeywords: argumentsKeywords,
    )
    .timeout(const Duration(seconds: 5));

void main() {
  late PlanerRouter router;
  late ArtikelDienst dienst;
  late Session kunde;

  setUp(() async {
    router = PlanerRouter.starte(await testEinstellungen());
    dienst = await ArtikelDienst.starte(
      router,
      _datei('v1', [
        _diele('10-10-073-R', Profil.genutet),
        _diele('10-10-080-R', Profil.glattkant),
        _clip,
      ]),
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
  });

  test('Kennung der Dienst-Sitzung', () {
    expect(ArtikelDienst.sitzungId, 'artikel-dienst');
  });

  test('Version der Artikeldaten', () async {
    final antwort = await _rufe(kunde, WampNamen.artikelVersion);
    expect(antwort.arguments, ['v1']);
    expect(dienst.datei.version, 'v1');
  });

  test('Liste je Filter in Datenreihenfolge', () async {
    Future<List<Object?>> nummern(Map<String, Object?> filter) async {
      final antwort = await _rufe(
        kunde,
        WampNamen.artikelListe,
        argumentsKeywords: filter,
      );
      final daten = antwort.arguments!.single as Map;
      expect(daten['version'], 'v1');
      return [for (final a in daten['artikel'] as List) (a as Map)['nummer']];
    }

    expect(await nummern(const {}), [
      '10-10-073-R',
      '10-10-080-R',
      '80-10-001',
    ]);
    expect(
      await nummern(const Artikelfilter(bereich: Bereich.belag).alsJson()),
      ['10-10-073-R', '10-10-080-R'],
    );
    expect(
      await nummern(const Artikelfilter(profil: Profil.glattkant).alsJson()),
      ['10-10-080-R'],
    );
    final ohneKeywords = await _rufe(kunde, WampNamen.artikelListe);
    expect(
      ((ohneKeywords.arguments!.single as Map)['artikel'] as List).length,
      3,
    );
  });

  test('Belagauswahl mit Preisen, erster Belag ist die Vorgabe', () async {
    final antwort = await _rufe(kunde, WampNamen.belagAuswahl);
    final auswahl = Belagauswahl.ausJson(
      alsJsonObjekt(antwort.arguments!.single),
      {robinie.id: robinie},
    );
    expect(auswahl.version, 'v1');
    expect(auswahl.belaege.map((b) => b.artikel.nummer.wert), [
      '10-10-073-R',
      '10-10-080-R',
    ]);
    expect(auswahl.vorgabe!.artikel.nummer.wert, '10-10-073-R');
    expect(auswahl.belaege.first.preisJeLfm, const Cent(1250));
    expect(auswahl.belaege.first.preisJeM2, const Cent(19231));
    expect(dienst.belagauswahl.belaege, hasLength(2));
  });

  test('ungültiger Filter ist ein Fehler', () async {
    await expectLater(
      _rufe(
        kunde,
        WampNamen.artikelListe,
        argumentsKeywords: {'profil': 'rund'},
      ),
      _wampFehler(WampNamen.artikelFilterUngueltig, [
        'Invalid argument (name): No enum value with that name: "rund"',
      ]),
    );
    await expectLater(
      _rufe(kunde, WampNamen.artikelListe, argumentsKeywords: {'art': 5}),
      throwsA(
        isA<Object>().having(
          (e) => (e as dynamic).error,
          'error',
          WampNamen.artikelFilterUngueltig,
        ),
      ),
    );
  });

  test('Regeln je Artikel', () async {
    final antwort = await _rufe(
      kunde,
      WampNamen.artikelRegeln,
      arguments: ['10-10-073-R'],
    );
    final regeln = Artikelregeln.ausJson(
      alsJsonObjekt(antwort.arguments!.single),
      {robinie.id: robinie},
    );
    expect(regeln.version, 'v1');
    expect(regeln.moeglich.keys, [Beziehung.befestigung]);
    expect(regeln.moeglich[Beziehung.befestigung]!.single.titel, 'CLIP-FIXX');
    expect(regeln.pflichtzubehoer.values, [3]);
    expect(regeln.abstaende.uk, const Millimeter(400));
  });

  test('unbekannter Artikel und falsche Argumente sind Fehler', () async {
    await expectLater(
      _rufe(kunde, WampNamen.artikelRegeln, arguments: ['99-99-999']),
      _wampFehler(WampNamen.artikelUnbekannt, ['99-99-999']),
    );
    await expectLater(
      _rufe(kunde, WampNamen.artikelRegeln, arguments: [1, 2]),
      _wampFehler(WampNamen.artikelUnbekannt, [1, 2]),
    );
    await expectLater(
      _rufe(kunde, WampNamen.artikelRegeln),
      _wampFehler(WampNamen.artikelUnbekannt, []),
    );
  });

  test('neue Artikeldaten wirken sofort und werden gemeldet', () async {
    final abo = await kunde.subscribe(WampNamen.artikelGeaendert);
    final gemeldet = abo.eventStream!.first;
    await dienst.ersetze(_datei('v2', [_clip]));
    expect((await gemeldet.timeout(const Duration(seconds: 10))).arguments, [
      'v2',
    ]);
    final version = await _rufe(kunde, WampNamen.artikelVersion);
    expect(version.arguments, ['v2']);
    await expectLater(
      _rufe(kunde, WampNamen.artikelRegeln, arguments: ['10-10-073-R']),
      _wampFehler(WampNamen.artikelUnbekannt, ['10-10-073-R']),
    );
  });
}
