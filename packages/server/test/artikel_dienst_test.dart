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
    zubehoergruppe: Zubehoergruppe.clipsSchrauben,
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
    // 12,50 € ÷ (60 + 6 mm Fuge, Planungskern v6)
    expect(auswahl.belaege.first.preisJeM2, const Cent(18939));
    expect(dienst.belagauswahl.belaege, hasLength(2));
  });

  test('Zubehörauswahl (M8-01): acht Gruppen, nur Zubehör', () async {
    final antwort = await _rufe(kunde, WampNamen.zubehoerAuswahl);
    final auswahl = Zubehoerauswahl.ausJson(
      alsJsonObjekt(antwort.arguments!.single),
      {robinie.id: robinie},
    );
    expect(auswahl.version, 'v1');
    expect(auswahl.gruppen.keys, Zubehoergruppe.values);
    expect(
      auswahl.gruppen[Zubehoergruppe.clipsSchrauben]!.map((a) => a.nummer.wert),
      ['80-10-001'],
    );
    expect([for (final l in auswahl.gruppen.values) ...l], hasLength(1));
    expect(
      dienst.zubehoerauswahl.gruppen[Zubehoergruppe.clipsSchrauben],
      hasLength(1),
    );
  });

  test('Belag für die Planung (M5-05): gewählt oder Vorgabe', () async {
    expect(dienst.belag(null)!.nummer.wert, '10-10-073-R');
    expect(
      dienst.belag(const Artikelnummer('10-10-080-R'))!.nummer.wert,
      '10-10-080-R',
    );
    // unbekannt oder kein Belag (Clip): die Vorgabe
    for (final nummer in ['10-10-999-R', '80-10-001']) {
      expect(dienst.belag(Artikelnummer(nummer))!.nummer.wert, '10-10-073-R');
    }
    await dienst.ersetze(_datei('v2', [_clip]));
    expect(dienst.belag(null), isNull);
    expect(dienst.regelwerk.datei.version, 'v2');
  });

  test('Unterkonstruktionen zum Belag (M6-03): nur passende Robinien-UK, '
      'gewählt oder Vorgabe, auch über WAMP', () async {
    Artikeleintrag uk(String nummer, Serie serie, int breite, int staerke) =>
        Artikeleintrag(
          artikel: Artikel(
            nummer: Artikelnummer(nummer),
            titel: 'UK $nummer',
            art: Artikelart.unterkonstruktion,
            einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
            abmessungen: Abmessungen(
              breite: Millimeter(breite),
              staerke: Millimeter(staerke),
              laengen: const [Millimeter(6000)],
            ),
            preisBrutto: const Cent(990),
            holzart: robinie,
            serie: serie,
          ),
        );
    final alu = Artikeleintrag(
      artikel: Artikel(
        nummer: const Artikelnummer('50-20-007'),
        titel: 'Alu',
        art: Artikelart.aluUnterkonstruktion,
        einheit: Verkaufseinheit(Mengeneinheit.stueck),
      ),
    );
    await dienst.ersetze(
      _datei('v2', [
        _diele('10-10-073-R', Profil.genutet),
        alu,
        uk('10-10-031-S', ecoSelect, 40, 60),
        uk('10-10-030-R', premiumSelect, 40, 60),
        uk('10-10-031-R', premiumSelect, 45, 60),
        uk('10-10-039-R', premiumSelect, 45, 70),
        _clip,
      ]),
    );
    expect(
      [for (final a in dienst.ukauswahl(null).angebote) a.artikel.nummer.wert],
      ['10-10-031-R', '10-10-039-R'],
    );
    expect(dienst.ukauswahl(null).version, 'v2');
    expect(dienst.unterkonstruktion(null, null)!.nummer.wert, '10-10-031-R');
    expect(
      dienst
          .unterkonstruktion(
            const Artikelnummer('10-10-073-R'),
            const Artikelnummer('10-10-039-R'),
          )!
          .nummer,
      const Artikelnummer('10-10-039-R'),
    );
    // nicht passende Wahl: die Vorgabe
    expect(
      dienst
          .unterkonstruktion(null, const Artikelnummer('10-10-031-S'))!
          .nummer,
      const Artikelnummer('10-10-031-R'),
    );
    for (final argumente in [
      <Object?>['10-10-073-R'],
      <Object?>[],
    ]) {
      final antwort = await _rufe(
        kunde,
        WampNamen.ukAuswahl,
        arguments: argumente,
      );
      final auswahl = Ukauswahl.ausJson(
        alsJsonObjekt(antwort.arguments!.single),
        {robinie.id: robinie},
      );
      expect(auswahl.vorgabe!.artikel.nummer.wert, '10-10-031-R');
      expect(auswahl.vorgabe!.preisJeLfm, const Cent(990));
      expect(auswahl.angebote, hasLength(2));
    }
    // ohne passenden Belag keine UK
    await dienst.ersetze(
      _datei('v3', [uk('10-10-031-R', premiumSelect, 45, 60)]),
    );
    expect(dienst.ukauswahl(null).angebote, isEmpty);
    expect(dienst.unterkonstruktion(null, null), isNull);
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
