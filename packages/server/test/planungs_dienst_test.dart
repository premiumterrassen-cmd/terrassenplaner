@Timeout(Duration(minutes: 2))
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
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

  /// Planung mit einer Fläche aus einem rohen Planungsstand-Puffer.
  Uint8List alsPlanung(Uint8List stand) {
    final fbb = fb.Builder();
    final standOrt = fbb.writeListUint8(stand);
    fbb
      ..startTable(2)
      ..addOffset(0, standOrt);
    final flaeche = fbb.endTable();
    final liste = fbb.writeList([flaeche]);
    fbb
      ..startTable(3)
      ..addOffset(1, liste);
    fbb.finish(fbb.endTable());
    return fbb.buffer;
  }

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

  test('Rundungen fließen in Umriss und Fläche ein (M4-11)', () {
    final b = PlanungsDienst.berechne(
      Planungsstand(
        grundriss: RechteckGrundriss(
          const Millimeter(5400),
          const Millimeter(3600),
        ),
        rundungen: Rundungen.keine.mitEcke(0, const Millimeter(1261)),
      ),
    );
    expect(b.flaecheQuadratmeter, closeTo(19.099, 0.001));
    expect(b.umriss.length, greaterThan(10));
    expect(b.ecken, hasLength(4));
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
    final antwort = await rufe(Planung.start.zuBytes());
    expect(antwort.pptScheme, WampNamen.pptSchema);
    final b = Berechnung.ausBytes(antwort.payload.packedPayloadBytes!);
    expect(b.flaecheQuadratmeter, 14.832);
    expect(b.gesamtflaecheQuadratmeter, 14.832);
    expect(b.umriss, hasLength(4));
    expect(b.umriss[2], const Punkt(4800, 3090));
  });

  test('mehrere Flächen: bearbeitete Fläche, Gesamtfläche mal Häufigkeit '
      '(M4-14)', () async {
    final planung = Planung([
      Terrassenflaeche(Planungsstand.start, haeufigkeit: 2),
      Terrassenflaeche(
        Planungsstand(
          grundriss: RechteckGrundriss(
            const Millimeter(2000),
            const Millimeter(1000),
          ),
        ),
        haeufigkeit: 3,
      ),
      // offene Freiform zählt nicht
      Terrassenflaeche(
        Planungsstand(
          grundriss: FreiformGrundriss(const [Punkt(0, 0), Punkt(1000, 0)]),
        ),
      ),
    ], aktiv: 1);
    final b = PlanungsDienst.berechnePlanung(planung);
    expect(b.flaeche, 2e6);
    expect(b.gesamtflaeche, 2 * 14832000 + 3 * 2e6);
    expect(b.umriss, PlanungsDienst.berechne(planung.aktuell).umriss);
    expect(b.ecken, hasLength(4));
    expect(b.geschlossen, isTrue);
    final offen = PlanungsDienst.berechnePlanung(planung.gewaehlt(2));
    expect(offen.geschlossen, isFalse);
    expect(offen.flaeche, 0);
    expect(offen.gesamtflaeche, 2 * 14832000 + 3 * 2e6);
    final o = PlanungsDienst.berechnePlanung(
      Planung.start.mitStand(Planungsstand.start.mitForm(Terrassenform.oForm)),
    );
    expect(o.ausschnitte, hasLength(1));
    final antwort = await rufe(planung.zuBytes());
    expect(
      Berechnung.ausBytes(antwort.payload.packedPayloadBytes!).gesamtflaeche,
      b.gesamtflaeche,
    );
  });

  group('Dielenstücke (M5-05)', () {
    Artikel belag(
      Artikelart art, {
      Millimeter? breite,
      List<int>? laengen,
      String nummer = '10-10-073-R',
    }) => Artikel(
      nummer: Artikelnummer(nummer),
      titel: 'Diele',
      art: art,
      einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
      abmessungen: Abmessungen(
        breite: breite,
        laengen: [for (final l in laengen ?? const <int>[]) Millimeter(l)],
      ),
      holzart: art.istHolz ? robinie : null,
      serie: art.istHolz ? premiumSelect : null,
    );
    final diele = belag(
      Artikelart.diele,
      breite: const Millimeter(60),
      laengen: const [4000, 5000, 6000],
    );

    test('je Richtung, Verlegeart und Länge aus Belag und Planung', () {
      expect(PlanungsDienst.berechne(Planungsstand.start).dielen, isEmpty);
      final f01 = PlanungsDienst.berechne(Planungsstand.start, diele);
      expect(f01.dielen, hasLength(48));
      expect(f01.dielen.first, hasLength(4));
      final f02 = PlanungsDienst.berechne(
        Planungsstand.start.mitVerlegerichtung(Verlegerichtung.senkrecht),
        diele,
      );
      expect(f02.dielen, hasLength(74));
      final f04 = PlanungsDienst.berechne(
        Planungsstand.start.mitVerlegerichtung(Verlegerichtung.diagonal135),
        diele,
      );
      expect(f04.dielen, hasLength(154));
      final f05 = PlanungsDienst.berechne(
        Planungsstand.start.mitVerlegerichtung(Verlegerichtung.individuell),
        diele,
      );
      expect(f05.dielen, hasLength(78));
      // 800 cm: Stoß bei 600 cm, fest 400 cm: bei 400 cm (F09, F13)
      final lang = Planungsstand.start.mitGrundriss(
        RechteckGrundriss(const Millimeter(8000), const Millimeter(3090)),
      );
      expect(PlanungsDienst.berechne(lang, diele).dielen, hasLength(96));
      final fest = lang.mitDielenlaenge(const Millimeter(4000));
      final f13 = PlanungsDienst.berechne(fest, diele).dielen;
      expect(f13, hasLength(96));
      expect(f13.first.map((p) => p.x).reduce(math.max), closeTo(4000, 1e-6));
      // Länge, die der Belag nicht liefert: wieder automatisch
      final fremd = lang.mitDielenlaenge(const Millimeter(4500));
      final auto = PlanungsDienst.berechne(fremd, diele).dielen;
      expect(auto.first.map((p) => p.x).reduce(math.max), closeTo(6000, 1e-6));
      // Halbverband: zweite Reihe bei 300 cm gestoßen (F10)
      final halb = PlanungsDienst.berechne(
        lang.mitVerlegeart(Verlegeart.halbverband),
        diele,
      ).dielen;
      expect(halb[2].map((p) => p.x).reduce(math.max), closeTo(3000, 1e-6));
      // kurze Stücke verbinden bei Ausgangspunkt A ohne Wirkung (F13)
      expect(
        PlanungsDienst.berechne(
          fest.mitKurzeStueckeVerbinden(true),
          diele,
        ).dielen,
        hasLength(96),
      );
    });

    test('ohne Dielen keine Stücke', () {
      for (final b in [
        belag(
          Artikelart.systemdiele,
          breite: const Millimeter(60),
          laengen: const [800],
        ),
        belag(Artikelart.diele, laengen: const [6000]),
        belag(Artikelart.diele, breite: const Millimeter(60)),
      ]) {
        expect(PlanungsDienst.berechne(Planungsstand.start, b).dielen, isEmpty);
      }
      final offen = FreiformGrundriss(const [Punkt(0, 0), Punkt(1000, 0)]);
      expect(
        PlanungsDienst.berechne(Planungsstand(grundriss: offen), diele).dielen,
        isEmpty,
      );
    });

    test('Ausgangspunkt: Ecke plus Verschiebung, Grenzen und kurze '
        'Zuschnitte (M5-07)', () {
      final start = PlanungsDienst.berechne(Planungsstand.start, diele);
      expect(start.ausgangspunkt, Punkt.ursprung);
      expect(start.grenzeLinksRechts, const Millimeter(4800));
      expect(start.grenzeObenUnten, const Millimeter(65));
      // 3090 = 47 × 65 + 35: die letzte Reihe ist schmaler als 5 cm
      expect(start.kurzeZuschnitte, isTrue);
      Berechnung verschoben({int ecke = 0, int x = 0, int y = 0}) =>
          PlanungsDienst.berechne(
            Planungsstand.start.mitAusgangspunkt(
              ecke: ecke,
              x: Millimeter(x),
              y: Millimeter(y),
            ),
            diele,
          );
      // 50 mm nach unten: Randreihen oben und unten je 50 mm
      final unten = verschoben(y: 50);
      expect(unten.ausgangspunkt, const Punkt(0, 50));
      expect(unten.kurzeZuschnitte, isFalse);
      expect(unten.dielen, hasLength(48));
      // 30 mm nach rechts: Stoß bei 30 mm, Stück zu kurz
      final rechts = verschoben(y: 50, x: 30);
      expect(rechts.kurzeZuschnitte, isTrue);
      expect(rechts.dielen, hasLength(96));
      expect(verschoben(y: 50, x: 1000).kurzeZuschnitte, isFalse);
      // Ecke C: Reihen ab C, der schmale Rest liegt jetzt bei A–B
      final c = verschoben(ecke: 2);
      expect(c.ausgangspunkt, const Punkt(4800, 3090));
      expect(c.dielen.last.map((p) => p.y).reduce(math.min), 3025);
      expect(c.dielen.last.map((p) => p.y).reduce(math.max), 3090);
      expect(c.dielen.first.map((p) => p.y).reduce(math.max), 35);
      expect(c.kurzeZuschnitte, isTrue);
      // über die Grenze hinaus: auf die Grenze begrenzt
      final weit = verschoben(x: -9000, y: 500);
      expect(weit.ausgangspunkt, const Punkt(-4800, 65));
      expect(
        verschoben(x: 9000, y: -500).ausgangspunkt,
        const Punkt(4800, -65),
      );
      // senkrecht: links/rechts um Breite plus Fuge, oben/unten um die Länge
      final senkrecht = PlanungsDienst.berechne(
        Planungsstand.start.mitVerlegerichtung(Verlegerichtung.senkrecht),
        diele,
      );
      expect(senkrecht.grenzeLinksRechts, const Millimeter(65));
      expect(senkrecht.grenzeObenUnten, const Millimeter(3090));
      // Kreis: nur A, der Anfang der Kontur
      final kreis = Planungsstand.start.mitForm(Terrassenform.kreis);
      expect(
        PlanungsDienst.berechne(kreis, diele).ausgangspunkt,
        kreis.kontur.punkte.first,
      );
      // ohne Dielen kein Ausgangspunkt und keine Grenzen
      final ohne = PlanungsDienst.berechne(Planungsstand.start);
      expect(ohne.ausgangspunkt, isNull);
      expect(ohne.grenzeLinksRechts, const Millimeter(0));
      expect(ohne.kurzeZuschnitte, isFalse);
      // Gesamtfläche behält die Werte der bearbeiteten Fläche
      final planung = PlanungsDienst.berechnePlanung(
        Planung.start.mitStand(
          Planungsstand.start.mitAusgangspunkt(y: const Millimeter(50)),
        ),
        (_) => diele,
      );
      expect(planung.ausgangspunkt, const Punkt(0, 50));
      expect(planung.grenzeObenUnten, const Millimeter(65));
      expect(planung.kurzeZuschnitte, isFalse);
    });

    test('Nummern, Teilflächen und Holzfliesen (M5-08)', () {
      final f01 = PlanungsDienst.berechne(Planungsstand.start, diele);
      expect(f01.nummern, [...List.filled(47, 1), 2]);
      final fliese = belag(
        Artikelart.holzfliese,
        breite: const Millimeter(606),
        laengen: const [606],
      );
      // F25: 8 × 6 Fliesen
      final f25 = PlanungsDienst.berechne(Planungsstand.start, fliese);
      expect(f25.dielen, hasLength(48));
      expect(f25.grenzeLinksRechts, const Millimeter(606));
      // Ausschnitt mit anderem Belag: eigene Stücke, eigene Nummern ab 1
      final anders = Planungsstand.start.mitNeuemAusschnitt();
      final mitTeil = anders.mitAusschnitt(
        0,
        anders.ausschnitte.single.mitFunktion(Ausschnittfunktion.andererBelag),
      );
      final ohneTeil = PlanungsDienst.berechne(anders, diele);
      final teil = PlanungsDienst.berechne(mitTeil, diele);
      final zusatz = teil.dielen.length - ohneTeil.dielen.length;
      // 180 × 120 cm: 18 Reihen + 3 cm
      expect(zusatz, 19);
      expect(teil.nummern, hasLength(teil.dielen.length));
      expect(teil.nummern.skip(ohneTeil.dielen.length), [
        ...List.filled(18, 1),
        2,
      ]);
    });

    test('Dielenliste und Verschnitt der ganzen Planung (M5-08)', () {
      final f01 = Planungsstand.start.mitBelag(const Artikelnummer('d'));
      final planung = Planung([
        Terrassenflaeche(f01, haeufigkeit: 2),
        Terrassenflaeche(f01.mitBelag(const Artikelnummer('f'))),
        // ohne Belag und offen: zählen nicht
        Terrassenflaeche(f01.mitBelag(const Artikelnummer('x'))),
        Terrassenflaeche(
          Planungsstand(
            grundriss: FreiformGrundriss(const [Punkt(0, 0), Punkt(1000, 0)]),
          ).mitBelag(const Artikelnummer('d')),
        ),
        Terrassenflaeche(f01.mitVerlegerichtung(Verlegerichtung.senkrecht)),
      ], aktiv: 1);
      final d = belag(
        Artikelart.diele,
        breite: const Millimeter(60),
        laengen: const [4000, 5000, 6000],
        nummer: 'd',
      );
      final f = belag(
        Artikelart.holzfliese,
        breite: const Millimeter(606),
        laengen: const [606],
        nummer: 'f',
      );
      Artikel? suche(Artikelnummer? n) => switch (n?.wert) {
        'd' => d,
        'f' => f,
        _ => null,
      };
      final b = PlanungsDienst.berechnePlanung(planung, suche);
      // bearbeitet ist die Fliesenfläche
      expect(b.dielen, hasLength(48));
      expect(b.dielenliste, [
        (
          belag: const Artikelnummer('d'),
          laenge: const Millimeter(4000),
          anzahl: 74,
        ),
        (
          belag: const Artikelnummer('d'),
          laenge: const Millimeter(5000),
          anzahl: 96,
        ),
        (
          belag: const Artikelnummer('f'),
          laenge: const Millimeter(606),
          anzahl: 48,
        ),
      ]);
      // geliefert: 2 × 48 × 5000 + 74 × 4000 + 48 × 606 mm
      const geliefert = 2 * 48 * 5000 + 74 * 4000 + 48 * 606;
      const geplant = 2 * 48 * 4800 + 74 * 3090 + 6 * 4800;
      expect(b.verschnitt, closeTo((geliefert - geplant) / geliefert, 1e-12));
      // ohne verlegte Fläche kein Verschnitt
      final ohne = PlanungsDienst.berechnePlanung(Planung.start);
      expect(ohne.verschnitt, isNull);
      expect(ohne.dielenliste, isEmpty);
      // eine Fläche: wie der alte Planer F01 4 %
      expect(
        PlanungsDienst.berechnePlanung(Planung.start, (_) => diele).verschnitt,
        closeTo(0.04, 1e-12),
      );
    });

    test('Stückliste und Farben im Plan (M9-04)', () {
      // F01: 48 Stücke à 4800 mm aus 5000 mm, längste Lieferlänge 6000 mm
      final f01 = PlanungsDienst.berechne(Planungsstand.start, diele);
      expect(f01.stueckliste.zeilen, [
        const Stuecklistenzeile(
          nummer: Artikelnummer('10-10-073-R'),
          titel: 'Diele',
          laenge: Millimeter(4800),
          stueck: 48,
          farbe: Stueckfarbe.blau,
        ),
      ]);
      expect(f01.stueckfarben, List.filled(48, Stueckfarbe.blau));
      // F09 (800 cm): 600 rot in ganzer Länge, 200 blau; jede Farbe gehört
      // zu genau dem Stück der Zeichnung
      final f09 = PlanungsDienst.berechne(
        Planungsstand.start.mitGrundriss(
          RechteckGrundriss(const Millimeter(8000), const Millimeter(3090)),
        ),
        diele,
      );
      expect(
        [
          for (final z in f09.stueckliste.zeilen)
            (z.laenge.mm, z.stueck, z.farbe),
        ],
        [(6000, 48, Stueckfarbe.rot), (2000, 48, Stueckfarbe.blau)],
      );
      expect(f09.stueckfarben, hasLength(f09.dielen.length));
      for (final (i, d) in f09.dielen.indexed) {
        final xs = [for (final p in d) p.x];
        final laenge = xs.reduce(math.max) - xs.reduce(math.min);
        expect(
          f09.stueckfarben[i],
          laenge > 5999 ? Stueckfarbe.rot : Stueckfarbe.blau,
        );
      }
      // erzwungene Länge 4000: zwei ganze Dielen je Reihe, rot (F13)
      final f13 = PlanungsDienst.berechne(
        Planungsstand.start
            .mitGrundriss(
              RechteckGrundriss(const Millimeter(8000), const Millimeter(3090)),
            )
            .mitDielenlaenge(const Millimeter(4000)),
        diele,
      );
      expect(f13.stueckliste.zeilen.single.farbe, Stueckfarbe.rot);
      expect(f13.stueckliste.zeilen.single.stueck, 96);
      // ohne Dielen keine Stückliste; über die Planung die bearbeitete Fläche
      expect(
        PlanungsDienst.berechne(Planungsstand.start).stueckliste.istLeer,
        isTrue,
      );
      expect(
        PlanungsDienst.berechnePlanung(
          Planung.start.mitHaeufigkeit(3),
          (_) => diele,
        ).stueckliste.zeilen.single.stueck,
        48,
      );
    });

    test('über den Router mit der Belagsuche', () async {
      await dienst.stoppe();
      final gefragt = <Artikelnummer?>[];
      dienst = await PlanungsDienst.starte(
        router,
        belag: (nummer) {
          gefragt.add(nummer);
          return diele;
        },
      );
      final planung = Planung.start.mitStand(
        Planungsstand.start
            .mitBelag(const Artikelnummer('10-10-073-R'))
            .mitVerlegerichtung(Verlegerichtung.diagonal45),
      );
      final antwort = await rufe(planung.zuBytes());
      final b = Berechnung.ausBytes(antwort.payload.packedPayloadBytes!);
      expect(b.dielen, hasLength(86));
      expect(gefragt, [const Artikelnummer('10-10-073-R')]);
      expect(
        PlanungsDienst.berechnePlanung(planung, (_) => diele).dielen,
        b.dielen,
      );
    });
  });

  group('Befestigung (M5-09)', () {
    Artikel clip(String vpe, int inhalt) => Artikel(
      nummer: Artikelnummer('80-10-001-$vpe'),
      titel: 'CLIP-FIXX® "BLACK EDITION" - VPE $vpe',
      art: Artikelart.clip,
      einheit: Verkaufseinheit(Mengeneinheit.stueck, inhalt: inhalt),
    );
    final clips = [clip('50', 50), clip('100', 100), clip('250', 250)];
    final diele = Artikel(
      nummer: const Artikelnummer('10-10-073-R'),
      titel: 'Terrassendiele Robinie PREMIUM SELECT 60 x 23 mm, genutet',
      art: Artikelart.diele,
      einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
      abmessungen: Abmessungen(
        breite: const Millimeter(60),
        staerke: const Millimeter(23),
        laengen: const [Millimeter(4000), Millimeter(5000), Millimeter(6000)],
      ),
      holzart: robinie,
      serie: premiumSelect,
      profil: Profil.genutet,
    );
    final regelwerk = Regelwerk(
      Artikeldatei(
        quelle: 'test',
        version: '1',
        eintraege: [
          Artikeleintrag(
            artikel: diele,
            verweise: {
              Beziehung.befestigung.spalte: [for (final c in clips) c.nummer],
            },
            angaben: const {'Abstand_UK': 400},
          ),
          for (final c in clips) Artikeleintrag(artikel: c),
        ],
      ),
    );

    test('F01: 637 CLIP-FIXX als 2 × 250 + 100 + 50 (B-094)', () {
      final b = PlanungsDienst.berechne(
        Planungsstand.start,
        diele,
        regelwerk,
      ).befestigung;
      expect(b.art, Befestigungsart.clips);
      expect(b.arten, [Befestigungsart.clips]);
      expect(b.punkte, 624);
      expect(
        {for (final m in b.mittel) m.nummer.wert: m.anzahl},
        {'80-10-001-50': 1, '80-10-001-100': 1, '80-10-001-250': 2},
      );
      // ohne Regelwerk oder mit einem, das den Belag nicht kennt: keine
      expect(
        PlanungsDienst.berechne(Planungsstand.start, diele).befestigung,
        same(Befestigungsbedarf.keiner),
      );
      final fremd = Regelwerk(
        Artikeldatei(quelle: 't', version: '2', eintraege: const []),
      );
      expect(
        PlanungsDienst.berechne(Planungsstand.start, diele, fremd).befestigung,
        same(Befestigungsbedarf.keiner),
      );
      expect(
        PlanungsDienst.berechnePlanung(
          Planung.start,
          (_) => diele,
          regelwerk,
        ).befestigung.punkte,
        624,
      );
    });

    test('über den Router mit dem Regelwerk', () async {
      await dienst.stoppe();
      dienst = await PlanungsDienst.starte(
        router,
        belag: (_) => diele,
        regelwerk: () => regelwerk,
      );
      final antwort = await rufe(Planung.start.zuBytes());
      final b = Berechnung.ausBytes(antwort.payload.packedPayloadBytes!);
      expect(b.befestigung.punkte, 624);
      expect(b.befestigung.mittel, hasLength(3));
    });

    group('Materialliste (M9-03)', () {
      Map<(String, int?), int> zeilen(Materialliste m) => {
        for (final p in m.positionen) (p.nummer.wert, p.laenge?.mm): p.anzahl,
      };

      test('F01 gegen die Materialliste des alten Planers', () {
        final m = PlanungsDienst.berechnePlanung(
          Planung.start,
          (_) => diele,
          regelwerk,
        ).materialliste;
        final alt = Referenzkonfiguration.ausJson(
          jsonDecode(
            File('../domain/test/referenzkonfigurationen/F01.json')
                .readAsStringSync(),
          ) as Map<String, Object?>,
        );
        int altAnzahl(bool Function(String typ, String text) passt) => alt
            .materialliste
            .where((p) => passt(p.typ, p.bezeichnung))
            .fold(0, (n, p) => n + p.anzahl);
        // Deckbelag samt Anfangsdielen ohne Freidiele: 48 × 5000 mm (die
        // einseitig genuteten Anfangsdielen gibt es nicht mehr, B-033)
        expect(
          altAnzahl(
            (typ, text) =>
                (typ == 'Deckbelag' || typ == 'Anfangsdiele') &&
                !text.contains('Freidiele'),
          ),
          48,
        );
        // Clips wie im alten Planer; keine Terrassenschrauben für Randdielen
        // (B-033), UK und Auflager folgen mit M6, Zubehör und Freidiele mit M8
        expect(zeilen(m), {
          ('10-10-073-R', 5000): 48,
          ('80-10-001-250', null): 2,
          ('80-10-001-100', null): 1,
          ('80-10-001-50', null): 1,
        });
        for (final vpe in ['50', '100', '250']) {
          expect(
            altAnzahl((_, text) => text.endsWith('VPE $vpe')),
            zeilen(m)[('80-10-001-$vpe', null)],
          );
        }
        expect([for (final p in m.positionen) p.position], [1, 2, 3, 4]);
        // die Testartikel haben keine Preise
        expect(m.vollstaendig, isFalse);
        expect(m.summe, const Cent(0));
      });

      test('alle Flächen mal Häufigkeit, Clips erst in der Summe verpackt', () {
        final planung = Planung.start.mitHaeufigkeit(2).mitNeuerFlaeche();
        final m = PlanungsDienst.berechnePlanung(
          planung,
          (_) => diele,
          regelwerk,
        ).materialliste;
        // 3 × 637 = 1911 Clips → 7 × 250 + 2 × 100: 9 Packungen statt
        // 3 × (2 × 250 + 100 + 50) = 12, wenn jede Fläche verpackt würde
        expect(zeilen(m), {
          ('10-10-073-R', 5000): 144,
          ('80-10-001-250', null): 7,
          ('80-10-001-100', null): 2,
        });
        // ohne Belag oder Regelwerk: keine bzw. nur Dielen
        expect(
          PlanungsDienst.berechnePlanung(planung).materialliste.istLeer,
          isTrue,
        );
        expect(
          zeilen(
            PlanungsDienst.berechnePlanung(planung, (_) => diele).materialliste,
          ),
          {('10-10-073-R', 5000): 144},
        );
      });

      test('geänderte Mengen nur mit Freigabe (Mitarbeiter, M9-10)', () async {
        const schluessel = (
          nummer: Artikelnummer('10-10-073-R'),
          laenge: Millimeter(5000),
          zusatz: null,
        );
        final planung = Planung.start.mitMenge(schluessel, 50);
        final mit = PlanungsDienst.berechnePlanung(
          planung,
          (_) => diele,
          regelwerk,
          true,
        ).materialliste.positionen.first;
        expect((mit.anzahl, mit.berechnet), (50, 48));
        expect(
          PlanungsDienst.berechnePlanung(
            planung,
            (_) => diele,
            regelwerk,
          ).materialliste.positionen.first.anzahl,
          48,
        );
        // über den Router: bis zur Anmeldung für niemanden
        await dienst.stoppe();
        dienst = await PlanungsDienst.starte(
          router,
          belag: (_) => diele,
          regelwerk: () => regelwerk,
        );
        final antwort = await rufe(planung.zuBytes());
        final b = Berechnung.ausBytes(antwort.payload.packedPayloadBytes!);
        expect(zeilen(b.materialliste)[('10-10-073-R', 5000)], 48);
        expect(b.materialliste.positionen.first.berechnet, isNull);
      });
    });
  });

  group('Meldungen zum Belag (M5-10)', () {
    final diele = Artikel(
      nummer: const Artikelnummer('10-10-073-R'),
      titel: 'Diele',
      art: Artikelart.diele,
      einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
      abmessungen: Abmessungen(
        breite: const Millimeter(60),
        staerke: const Millimeter(23),
        laengen: const [Millimeter(4000), Millimeter(5000), Millimeter(6000)],
      ),
      holzart: robinie,
      serie: premiumSelect,
      profil: Profil.genutet,
    );
    final systemdiele = Artikel(
      nummer: const Artikelnummer('10-15-001'),
      titel: 'Systemdiele',
      art: Artikelart.systemdiele,
      einheit: Verkaufseinheit(Mengeneinheit.quadratmeter),
      abmessungen: Abmessungen(
        breite: const Millimeter(60),
        laengen: const [Millimeter(800)],
      ),
      holzart: robinie,
      serie: massiv,
    );
    final regelwerk = Regelwerk(
      Artikeldatei(
        quelle: 'test',
        version: '1',
        eintraege: [Artikeleintrag(artikel: diele)],
      ),
    );

    test('mit Verlegung: Länge und Befestigung (B-035, B-094)', () {
      final stand = Planungsstand.start
          .mitDielenlaenge(const Millimeter(7000))
          .mitBefestigungsart(Befestigungsart.verschraubt);
      expect(PlanungsDienst.berechne(stand, diele, regelwerk).belagmeldungen, [
        Belagmeldung.laengeNichtLieferbar,
        Belagmeldung.befestigungsartNichtMoeglich,
        Belagmeldung.befestigungOhneArtikel,
      ]);
      expect(
        PlanungsDienst.berechne(Planungsstand.start, diele).belagmeldungen,
        isEmpty,
      );
    });

    test('ohne Verlegung: Systemdiele, Umriss und Fläche bleiben', () {
      final b = PlanungsDienst.berechne(Planungsstand.start, systemdiele);
      expect(b.belagmeldungen, [Belagmeldung.systemdieleOhneVerlegung]);
      expect(b.dielen, isEmpty);
      expect(b.flaeche, closeTo(4800 * 3090, 1e-6));
      expect(b.umriss, hasLength(4));
      expect(b.ecken, hasLength(4));
      expect(b.geschlossen, isTrue);
      final o = PlanungsDienst.berechne(
        Planungsstand.start.mitForm(Terrassenform.oForm),
        systemdiele,
      );
      expect(o.ausschnitte, hasLength(1));
      final offen = PlanungsDienst.berechne(
        Planungsstand(
          grundriss: FreiformGrundriss(const [Punkt(0, 0), Punkt(1000, 0)]),
        ),
        systemdiele,
      );
      expect(offen.geschlossen, isFalse);
      expect(
        PlanungsDienst.berechne(Planungsstand.start).belagmeldungen,
        isEmpty,
      );
    });

    test('Belag nicht mehr in den Artikeldaten über die Planung', () {
      final planung = Planung.start.mitStand(
        Planungsstand.start.mitBelag(const Artikelnummer('10-10-999')),
      );
      expect(
        PlanungsDienst.berechnePlanung(planung, (_) => diele).belagmeldungen,
        [Belagmeldung.belagErsetzt],
      );
    });

    test('über den Router', () async {
      await dienst.stoppe();
      dienst = await PlanungsDienst.starte(router, belag: (_) => systemdiele);
      final antwort = await rufe(Planung.start.zuBytes());
      expect(
        Berechnung.ausBytes(antwort.payload.packedPayloadBytes!).belagmeldungen,
        [Belagmeldung.systemdieleOhneVerlegung],
      );
    });
  });

  group('Höhenpunkte (M6-02)', () {
    Artikel holz(String nummer, Artikelart art, int breite, int staerke) =>
        Artikel(
          nummer: Artikelnummer(nummer),
          titel: nummer,
          art: art,
          einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
          abmessungen: Abmessungen(
            breite: Millimeter(breite),
            staerke: Millimeter(staerke),
            laengen: const [Millimeter(4000)],
          ),
          holzart: robinie,
          serie: premiumSelect,
          profil: art == Artikelart.diele ? Profil.genutet : null,
        );
    final diele = holz('10-10-073-R', Artikelart.diele, 60, 23);
    final uk = holz('10-10-031-R', Artikelart.unterkonstruktion, 45, 60);

    test('ohne Belag ungeprüft, je Ecke die eingegebene Höhe', () {
      final b = PlanungsDienst.berechne(Planungsstand.start);
      expect(b.hoehenpunkte.hoehen, List.filled(4, const Millimeter(86)));
      expect(b.hoehenpunkte.aufbauhoehe, isNull);
      // offene Freiform: keine Höhenpunkte
      final offen = PlanungsDienst.berechne(
        Planungsstand(
          grundriss: FreiformGrundriss(const [Punkt(0, 0), Punkt(1000, 0)]),
        ),
      );
      expect(offen.hoehenpunkte.hoehen, isEmpty);
    });

    test('mit Belag und UK geprüft: gedreht und korrigiert', () {
      final stand = Planungsstand.start
          .mitGefaelle(true)
          .mitEckhoehe(0, const Millimeter(150))
          .mitEckhoehe(2, const Millimeter(70))
          .mitEckhoehe(3, const Millimeter(50));
      final b = PlanungsDienst.berechne(stand, diele, null, uk);
      final p = b.hoehenpunkte;
      expect(p.hoehen, [
        const Millimeter(150),
        const Millimeter(86),
        const Millimeter(70),
        const Millimeter(68),
      ]);
      expect(p.aufbauhoehe, const Millimeter(68));
      expect(p.mindesthoehe, const Millimeter(68));
      expect(p.gedreht, isTrue);
      expect(p.korrigiert, isTrue);
      expect(b.dielen, isNotEmpty);
      // Holzfliese ohne Dielen: Höhen trotzdem geprüft
      final fliese = Artikel(
        nummer: const Artikelnummer('10-20-001'),
        titel: 'Fliese',
        art: Artikelart.holzfliese,
        einheit: Verkaufseinheit(Mengeneinheit.stueck),
        abmessungen: Abmessungen(staerke: const Millimeter(40)),
      );
      final f = PlanungsDienst.berechne(stand, fliese, null, uk);
      expect(f.dielen, isEmpty);
      expect(f.hoehenpunkte.mindesthoehe, const Millimeter(85));
    });

    test('UK-Maße: Breite und Stärke, sonst keine', () {
      expect(PlanungsDienst.ukMasse(uk), (
        a: const Millimeter(45),
        b: const Millimeter(60),
      ));
      expect(PlanungsDienst.ukMasse(null), isNull);
      final alu = Artikel(
        nummer: const Artikelnummer('50-20-007'),
        titel: 'Alu-Schiene',
        art: Artikelart.aluUnterkonstruktion,
        einheit: Verkaufseinheit(Mengeneinheit.stueck),
        abmessungen: Abmessungen(breite: const Millimeter(56)),
      );
      expect(PlanungsDienst.ukMasse(alu), isNull);
    });

    test('über den Router mit der UK-Suche', () async {
      await dienst.stoppe();
      final gefragt = <Planungsstand>[];
      dienst = await PlanungsDienst.starte(
        router,
        belag: (_) => diele,
        unterkonstruktion: (stand) {
          gefragt.add(stand);
          return uk;
        },
      );
      final stand = Planungsstand.start.mitHoehe(const Millimeter(60));
      final antwort = await rufe(Planung.start.mitStand(stand).zuBytes());
      final b = Berechnung.ausBytes(antwort.payload.packedPayloadBytes!);
      expect(b.hoehenpunkte.hoehen, List.filled(4, const Millimeter(68)));
      expect(b.hoehenpunkte.korrigiert, isTrue);
      expect(gefragt, [stand]);
    });
  });

  group('Art der Terrassennutzung (M6-05)', () {
    Artikel holz(String nummer, Artikelart art, int breite, int staerke) =>
        Artikel(
          nummer: Artikelnummer(nummer),
          titel: nummer,
          art: art,
          einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
          abmessungen: Abmessungen(
            breite: Millimeter(breite),
            staerke: Millimeter(staerke),
            laengen: const [Millimeter(4000), Millimeter(5000)],
          ),
          holzart: robinie,
          serie: basic,
          profil: art == Artikelart.diele ? Profil.genutet : null,
        );
    final diele = holz('10-10-073', Artikelart.diele, 60, 21);
    final uk = holz('10-10-031', Artikelart.unterkonstruktion, 40, 60);
    Map<(String, int?), int> zeilen(Materialliste m) => {
      for (final p in m.positionen) (p.nummer.wert, p.laenge?.mm): p.anzahl,
    };
    Berechnung rechne(
      Planung planung, {
      Artikel? mitUk,
      Regelwerk? regelwerk,
      Artikel? belag,
    }) => PlanungsDienst.berechnePlanung(
      planung,
      (_) => belag ?? diele,
      regelwerk,
      false,
      (_) => mitUk,
    );

    test('Rahmen: 2 × 5000 mm in Material- und Stückliste (F32)', () {
      final stand = Planungsstand.start.mitNutzungsart(Nutzungsart.rahmen);
      final b = rechne(Planung.start.mitStand(stand), mitUk: uk);
      expect(zeilen(b.materialliste)[('10-10-031', 5000)], 2);
      // dazu die UK-Verlegung (M6-10): 13 Hölzer à 309 cm aus 4000 mm
      expect(zeilen(b.materialliste)[('10-10-031', 4000)], 13);
      expect(b.stueckliste.zeilen.where((z) => z.nummer == uk.nummer), [
        const Stuecklistenzeile(
          nummer: Artikelnummer('10-10-031'),
          titel: '10-10-031',
          laenge: Millimeter(4800),
          stueck: 2,
          farbe: Stueckfarbe.blau,
        ),
        const Stuecklistenzeile(
          nummer: Artikelnummer('10-10-031'),
          titel: '10-10-031',
          laenge: Millimeter(3090),
          stueck: 13,
          farbe: Stueckfarbe.blau,
        ),
      ]);
      // die Farben im Plan bleiben die der Dielen
      expect(b.stueckfarben, hasLength(b.dielen.length));
      // schwimmend (F01): nur die UK-Hölzer, kein zusätzliches Holz
      final f01 = rechne(Planung.start, mitUk: uk);
      expect(
        zeilen(f01.materialliste).keys
            .where((k) => k.$1 == '10-10-031')
            .toList(),
        [('10-10-031', 4000)],
      );
    });

    test('alle Flächen mal Häufigkeit; ohne UK, ohne Holzbelag oder ohne '
        'Dielen keins', () {
      final stand = Planungsstand.start.mitNutzungsart(Nutzungsart.rahmen);
      final planung = Planung.start
          .mitStand(stand)
          .mitHaeufigkeit(2)
          .mitNeuerFlaeche()
          .mitStand(stand);
      expect(
        zeilen(rechne(planung, mitUk: uk).materialliste)[('10-10-031', 5000)],
        6,
      );
      expect(
        zeilen(rechne(planung).materialliste).keys.map((k) => k.$1),
        isNot(contains('10-10-031')),
      );
      final fliese = Artikel(
        nummer: const Artikelnummer('10-20-001'),
        titel: 'Fliese',
        art: Artikelart.holzfliese,
        einheit: Verkaufseinheit(Mengeneinheit.stueck),
        abmessungen: Abmessungen(staerke: const Millimeter(40)),
      );
      expect(
        rechne(planung, mitUk: uk, belag: fliese).materialliste.istLeer,
        isTrue,
      );
      final offen = Planung.start.mitStand(
        Planungsstand(
          grundriss: FreiformGrundriss(const [Punkt(0, 0), Punkt(1000, 0)]),
        ).mitNutzungsart(Nutzungsart.rahmen),
      );
      expect(rechne(offen, mitUk: uk).materialliste.istLeer, isTrue);
    });

    test('Querstreben (M6-06): Zeichnung, Anzahl und Mengen der '
        'bearbeiteten Fläche', () {
      final stand = Planungsstand.start.mitQuerstreben(true);
      final b = rechne(Planung.start.mitStand(stand), mitUk: uk);
      expect(b.querstreben, hasLength(60));
      // zwischen den UK-Hölzern der Verlegung (M6-10): Achsen 20 mm vom Rand,
      // 4760 / 12 = 396,7 mm auseinander, Strebe 356,7 mm
      expect(b.querstreben.first.von, const Punkt(40, 515));
      expect(b.querstrebenReihen, 5);
      expect(
        b.stueckliste.zeilen.singleWhere((z) => z.farbe == Stueckfarbe.gruen),
        const Stuecklistenzeile(
          nummer: Artikelnummer('10-10-031'),
          titel: '10-10-031',
          laenge: Millimeter(357),
          stueck: 60,
          farbe: Stueckfarbe.gruen,
        ),
      );
      final drei = rechne(
        Planung.start.mitStand(stand.mitQuerstrebenReihen(3)),
        mitUk: uk,
      );
      expect(drei.querstreben, hasLength(36));
      expect(drei.querstrebenReihen, 3);
      // ohne Querstreben und ohne Rahmen keine; mit Rahmen keine Reihen
      final ohne = rechne(Planung.start, mitUk: uk);
      expect(ohne.querstreben, isEmpty);
      expect(ohne.querstrebenReihen, isNull);
      final rahmen = rechne(
        Planung.start.mitStand(
          Planungsstand.start.mitNutzungsart(Nutzungsart.rahmen),
        ),
        mitUk: uk,
      );
      expect(rahmen.querstrebenReihen, isNull);
      // im Transportformat zur App
      expect(Berechnung.ausBytes(b.zuBytes()).querstreben, b.querstreben);
    });

    test('doppelte UK im Achsabstand des Belags (Regelwerk) und mit zwei '
        'Lagen in der Höhenprüfung', () {
      final stand = Planungsstand.start.mitNutzungsart(Nutzungsart.doppelteUk);
      // ohne Regelwerk: Achsabstand der Holzart, 9 Lagen à 480 cm (F34)
      expect(
        zeilen(rechne(Planung.start.mitStand(stand), mitUk: uk).materialliste)[(
          '10-10-031',
          5000,
        )],
        9,
      );
      final regelwerk = Regelwerk(
        Artikeldatei(
          quelle: 'test',
          version: '1',
          eintraege: [
            Artikeleintrag(artikel: diele, angaben: const {'Abstand_UK': 350}),
          ],
        ),
      );
      final b = rechne(
        Planung.start.mitStand(stand),
        mitUk: uk,
        regelwerk: regelwerk,
      );
      // 309 cm mit 35 cm: 9 Felder, 10 Lagen
      expect(zeilen(b.materialliste)[('10-10-031', 5000)], 10);
      // Belag 21 mm + 2 × 40 mm: 8,6 cm wird auf 10,1 cm korrigiert
      expect(b.hoehenpunkte.mindesthoehe, const Millimeter(101));
      expect(b.hoehenpunkte.korrigiert, isTrue);
      // ein Regelwerk, das den Belag nicht kennt: Achsabstand der Holzart
      final fremd = Regelwerk(
        Artikeldatei(quelle: 't', version: '2', eintraege: const []),
      );
      expect(
        zeilen(
          rechne(
            Planung.start.mitStand(stand),
            mitUk: uk,
            regelwerk: fremd,
          ).materialliste,
        )[('10-10-031', 5000)],
        9,
      );
    });
  });

  group('Nutzung privat oder gewerblich (M6-07)', () {
    Artikel artikel(String nummer, Artikelart art) => Artikel(
      nummer: Artikelnummer(nummer),
      titel: 'Artikel $nummer',
      art: art,
      einheit: Verkaufseinheit(Mengeneinheit.stueck),
    );
    final uk = Artikel(
      nummer: const Artikelnummer('10-10-031'),
      titel: 'UK',
      art: Artikelart.unterkonstruktion,
      einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
      abmessungen: Abmessungen(
        breite: const Millimeter(40),
        staerke: const Millimeter(60),
      ),
      holzart: robinie,
      serie: basic,
    );
    final privat = artikel('70-10-001', Artikelart.stellfuss);
    final gewerblich = artikel('70-10-002', Artikelart.stellfuss);
    final regelwerk = Regelwerk(
      Artikeldatei(
        quelle: 'test',
        version: '1',
        eintraege: [
          Artikeleintrag(
            artikel: uk,
            verweise: {
              Beziehung.stellfussPrivat.spalte: [privat.nummer],
              Beziehung.stellfussGewerblich.spalte: [
                gewerblich.nummer,
                privat.nummer,
              ],
            },
          ),
          Artikeleintrag(artikel: privat),
          Artikeleintrag(artikel: gewerblich),
        ],
      ),
    );
    List<String> fuesse(Planungsstand stand, {Regelwerk? mit, Artikel? zu}) => [
      for (final f in PlanungsDienst.berechnePlanung(
        Planung.start.mitStand(stand),
        (_) => null,
        mit,
        false,
        (_) => zu,
      ).stellfuesse)
        f.nummer.wert,
    ];

    test('Stellfußauswahl folgt dem Regelwerk der UK', () {
      expect(fuesse(Planungsstand.start, mit: regelwerk, zu: uk), [
        '70-10-001',
      ]);
      expect(
        fuesse(Planungsstand.start.mitGewerblich(true), mit: regelwerk, zu: uk),
        ['70-10-002', '70-10-001'],
      );
      final b = PlanungsDienst.berechnePlanung(
        Planung.start,
        (_) => null,
        regelwerk,
        false,
        (_) => uk,
      );
      expect(b.stellfuesse.single.titel, 'Artikel 70-10-001');
      expect(Berechnung.ausBytes(b.zuBytes()).stellfuesse, b.stellfuesse);
    });

    test('mit Belag und Dielen ebenso; ohne UK oder unbekannt: keine', () {
      final diele = Artikel(
        nummer: const Artikelnummer('10-10-073'),
        titel: 'Diele',
        art: Artikelart.diele,
        einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
        abmessungen: Abmessungen(
          breite: const Millimeter(60),
          staerke: const Millimeter(21),
          laengen: const [Millimeter(5000)],
        ),
        holzart: robinie,
        serie: basic,
        profil: Profil.genutet,
      );
      final mitDielen = PlanungsDienst.berechnePlanung(
        Planung.start,
        (_) => diele,
        regelwerk,
        false,
        (_) => uk,
      );
      expect(mitDielen.dielen, isNotEmpty);
      expect(mitDielen.stellfuesse, hasLength(1));
      expect(fuesse(Planungsstand.start, mit: regelwerk), isEmpty);
      expect(fuesse(Planungsstand.start, zu: uk), isEmpty);
      final fremd = Regelwerk(
        Artikeldatei(quelle: 't', version: '2', eintraege: const []),
      );
      expect(fuesse(Planungsstand.start, mit: fremd, zu: uk), isEmpty);
    });
  });

  group('Auflagen: Stelzfüße und Pads (M6-08)', () {
    Artikel artikel(String nummer, Artikelart art) => Artikel(
      nummer: Artikelnummer(nummer),
      titel: 'Artikel $nummer',
      art: art,
      einheit: Verkaufseinheit(Mengeneinheit.stueck),
    );
    final uk = Artikel(
      nummer: const Artikelnummer('10-10-031'),
      titel: 'UK',
      art: Artikelart.unterkonstruktion,
      einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
      abmessungen: Abmessungen(
        breite: const Millimeter(40),
        staerke: const Millimeter(60),
      ),
      holzart: robinie,
      serie: basic,
    );
    final diele = Artikel(
      nummer: const Artikelnummer('10-10-073'),
      titel: 'Diele',
      art: Artikelart.diele,
      einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
      abmessungen: Abmessungen(
        breite: const Millimeter(60),
        staerke: const Millimeter(21),
        laengen: const [Millimeter(5000)],
      ),
      holzart: robinie,
      serie: basic,
      profil: Profil.genutet,
    );
    final pad = artikel('50-60-005', Artikelart.pad);
    final fuss = artikel('60-55-110', Artikelart.stellfuss);
    final regelwerk = Regelwerk(
      Artikeldatei(
        quelle: 'test',
        version: '1',
        eintraege: [
          Artikeleintrag(
            artikel: uk,
            verweise: {
              Beziehung.stellfussPrivat.spalte: [fuss.nummer],
              Beziehung.unterlegpads.spalte: [pad.nummer],
            },
            angaben: const {'Abstand_Stelzfuesse': 500},
          ),
          Artikeleintrag(
            artikel: pad,
            angaben: const {'MinHoehe': 5, 'MaxHoehe': 5},
          ),
          Artikeleintrag(
            artikel: fuss,
            angaben: const {'MinHoehe': 35, 'MaxHoehe': 55},
          ),
        ],
      ),
    );
    Unterbau unterbau(Planungsstand stand, {Artikel? belag}) =>
        Berechnung.ausBytes(
          PlanungsDienst.berechnePlanung(
            Planung.start.mitStand(stand),
            (_) => belag,
            regelwerk,
            false,
            (_) => uk,
          ).zuBytes(),
        ).unterbau;

    test('Abstand und Höhenbereiche aus dem Regelwerk der UK', () {
      final u = unterbau(Planungsstand.start, belag: diele);
      expect(u.auflagerabstand, const Millimeter(500));
      expect(
        [for (final a in u.auflager) a.titel],
        ['Artikel 50-60-005', 'Artikel 60-55-110'],
      );
      // Belag 21 mm + UK 60 mm = 81 mm; Pads ab 0, Füße bis 55 mm
      expect(u.hoeheVon, const Millimeter(81));
      expect(u.hoeheBis, const Millimeter(136));
      expect(u.meldungen, isEmpty);
    });

    test('Höhengrenzen mit Meldung: ohne Pads zu niedrig, zu hoch', () {
      final nurFuesse = Planungsstand.start.mitAuflagen(Auflagen.stelzfuesse);
      expect(unterbau(nurFuesse, belag: diele).meldungen, [
        Auflagermeldung.unterMindesthoehe,
      ]);
      expect(
        unterbau(
          Planungsstand.start.mitHoehe(const Millimeter(200)),
          belag: diele,
        ).meldungen,
        [Auflagermeldung.ueberHoechsthoehe],
      );
      // ohne Belag ungeprüft: keine Grenzen, keine Meldung
      final ohne = unterbau(nurFuesse);
      expect(ohne.auflager, hasLength(1));
      expect(ohne.hoeheVon, isNull);
      expect(ohne.meldungen, isEmpty);
    });
  });

  group('Maximale Feldbreite (M6-09)', () {
    final clip = Artikel(
      nummer: const Artikelnummer('80-10-001-250'),
      titel: 'CLIP-FIXX - VPE 250',
      art: Artikelart.clip,
      einheit: Verkaufseinheit(Mengeneinheit.verpackungseinheit, inhalt: 250),
    );
    final diele = Artikel(
      nummer: const Artikelnummer('10-10-073'),
      titel: 'Diele',
      art: Artikelart.diele,
      einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
      abmessungen: Abmessungen(
        breite: const Millimeter(60),
        staerke: const Millimeter(21),
        laengen: const [Millimeter(5000)],
      ),
      holzart: robinie,
      serie: basic,
      profil: Profil.genutet,
    );
    final uk = Artikel(
      nummer: const Artikelnummer('10-10-031'),
      titel: 'UK',
      art: Artikelart.unterkonstruktion,
      einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
      abmessungen: Abmessungen(
        breite: const Millimeter(40),
        staerke: const Millimeter(60),
      ),
      holzart: robinie,
      serie: basic,
    );
    final regelwerk = Regelwerk(
      Artikeldatei(
        quelle: 'test',
        version: '1',
        eintraege: [
          Artikeleintrag(
            artikel: diele,
            verweise: {
              Beziehung.befestigung.spalte: [clip.nummer],
            },
          ),
          Artikeleintrag(artikel: clip),
          Artikeleintrag(artikel: uk),
        ],
      ),
    );
    Berechnung rechne(Planungsstand stand) => Berechnung.ausBytes(
      PlanungsDienst.berechnePlanung(
        Planung.start.mitStand(stand),
        (_) => diele,
        regelwerk,
        false,
        (_) => uk,
      ).zuBytes(),
    );

    test('Auswahl und wirksame Feldbreite; 30 cm: mehr UK-Linien für '
        'Befestigung und zusätzliches UK-Holz', () {
      final auto = rechne(
        Planungsstand.start.mitNutzungsart(Nutzungsart.doppelteUk),
      );
      expect(auto.unterbau.feldbreiten, const [
        Millimeter(300),
        Millimeter(350),
        Millimeter(400),
      ]);
      expect(auto.unterbau.feldbreite, const Millimeter(400));
      expect(auto.befestigung.punkte, 624);
      final eng = rechne(
        Planungsstand.start
            .mitNutzungsart(Nutzungsart.doppelteUk)
            .mitFeldbreite(const Millimeter(300)),
      );
      expect(eng.unterbau.feldbreite, const Millimeter(300));
      expect(eng.unterbau.feldbreiteBegrenzt, isFalse);
      expect(eng.befestigung.punkte, 48 * 17);
      int laengs(Berechnung b) =>
          b.stueckliste.zeilen.fold(0, (n, z) => n + z.stueck);
      // UK-Verlegung 17 statt 13 Hölzer (M6-10), zweite Lage: 309 cm mit
      // 30 cm → 12 statt 9 Hölzer
      expect(laengs(eng) - laengs(auto), 4 + 3);
      final zuBreit = rechne(
        Planungsstand.start.mitFeldbreite(const Millimeter(600)),
      );
      expect(zuBreit.unterbau.feldbreite, const Millimeter(400));
      expect(zuBreit.unterbau.feldbreiteBegrenzt, isTrue);
      expect(zuBreit.befestigung.punkte, 624);
    });
  });

  group('UK-Verlegung (M6-10)', () {
    final clip = Artikel(
      nummer: const Artikelnummer('80-10-001-250'),
      titel: 'CLIP-FIXX - VPE 250',
      art: Artikelart.clip,
      einheit: Verkaufseinheit(Mengeneinheit.verpackungseinheit, inhalt: 250),
    );
    final diele = Artikel(
      nummer: const Artikelnummer('10-10-073'),
      titel: 'Diele',
      art: Artikelart.diele,
      einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
      abmessungen: Abmessungen(
        breite: const Millimeter(60),
        staerke: const Millimeter(21),
        laengen: const [Millimeter(5000)],
      ),
      holzart: robinie,
      serie: basic,
      profil: Profil.genutet,
    );
    final uk = Artikel(
      nummer: const Artikelnummer('10-10-031'),
      titel: 'UK',
      art: Artikelart.unterkonstruktion,
      einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
      abmessungen: Abmessungen(
        breite: const Millimeter(40),
        staerke: const Millimeter(60),
      ),
      holzart: robinie,
      serie: basic,
    );
    final regelwerk = Regelwerk(
      Artikeldatei(
        quelle: 'test',
        version: '1',
        eintraege: [
          Artikeleintrag(
            artikel: diele,
            verweise: {
              Beziehung.befestigung.spalte: [clip.nummer],
            },
          ),
          Artikeleintrag(artikel: clip),
          Artikeleintrag(artikel: uk),
        ],
      ),
    );
    Berechnung rechne(Planung planung, {Artikel? mitUk}) => Berechnung.ausBytes(
      PlanungsDienst.berechnePlanung(
        planung,
        (_) => diele,
        regelwerk,
        false,
        (_) => mitUk,
      ).zuBytes(),
    );
    int? anzahl(Berechnung b, String nummer, int laenge) => b
        .materialliste
        .positionen
        .where((p) => p.nummer.wert == nummer && p.laenge?.mm == laenge)
        .firstOrNull
        ?.anzahl;

    test('F01: 13 × 4000 mm in Material- und Stückliste, Hölzer in der '
        'Zeichnung, Befestigung auf den Hölzern, Holzvolumen', () {
      final b = rechne(Planung.start, mitUk: uk);
      expect(anzahl(b, '10-10-031', 4000), 13);
      expect(b.stueckliste.zeilen.where((z) => z.nummer == uk.nummer), [
        const Stuecklistenzeile(
          nummer: Artikelnummer('10-10-031'),
          titel: 'UK',
          laenge: Millimeter(3090),
          stueck: 13,
          farbe: Stueckfarbe.blau,
        ),
      ]);
      expect(b.unterbau.hoelzer, hasLength(13));
      expect(b.unterbau.holzbreite, const Millimeter(40));
      expect(b.befestigung.punkte, 624);
      // 48 Dielen à 5 m 60 × 21 + 13 UK à 4 m 40 × 60
      expect(b.volumen, closeTo(0.3024 + 0.1248, 1e-9));
      // ohne UK: Dielen allein, Befestigung auf gleichmäßigen Linien
      final ohne = rechne(Planung.start);
      expect(ohne.volumen, closeTo(0.3024, 1e-9));
      expect(ohne.unterbau.hoelzer, isEmpty);
      expect(ohne.befestigung.punkte, 624);
      // ohne Grundriss mit Fläche kein Volumen
      final offen = rechne(
        Planung.start.mitStand(
          Planungsstand(
            grundriss: FreiformGrundriss(const [Punkt(0, 0), Punkt(1000, 0)]),
          ),
        ),
        mitUk: uk,
      );
      expect(offen.volumen, isNull);
    });

    test('alle Flächen mal Häufigkeit; die UK dreht mit (M6-02, B-034)', () {
      final planung = Planung.start.mitHaeufigkeit(2);
      final b = rechne(planung, mitUk: uk);
      expect(anzahl(b, '10-10-031', 4000), 26);
      expect(b.volumen, closeTo(2 * (0.3024 + 0.1248), 1e-9));
      // 7 cm: UK flach, in der Draufsicht 60 mm breit
      final flach = rechne(
        Planung.start.mitStand(
          Planungsstand.start.mitHoehe(const Millimeter(70)),
        ),
        mitUk: uk,
      );
      expect(flach.unterbau.holzbreite, const Millimeter(60));
    });

    test('einzelne Fläche (berechne) mit UK-Verlegung', () {
      final b = PlanungsDienst.berechne(
        Planungsstand.start,
        diele,
        regelwerk,
        uk,
      );
      expect(b.unterbau.hoelzer, hasLength(13));
      expect(b.befestigung.punkte, 624);
      expect(
        b.stueckliste.zeilen.where((z) => z.nummer == uk.nummer),
        hasLength(1),
      );
    });
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
      rufe(alsPlanung(fbb.buffer)),
      fehler('muss zwischen 50 und 3000 cm liegen'),
    );
  });

  test('ohne Grundriss oder ohne typisierte Nutzlast ein Fehler', () async {
    final fbb = fb.Builder()..startTable(2);
    fbb.finish(fbb.endTable());
    await expectLater(
      rufe(alsPlanung(fbb.buffer)),
      fehler('Planungsstand ohne Grundriss'),
    );
    await expectLater(rufe(fbb.buffer), fehler('mindestens eine Fläche'));
    await expectLater(
      kunde
          .callSingle(WampNamen.planungBerechnen, arguments: [1, 2])
          .timeout(const Duration(seconds: 5)),
      fehler('keine typisierte Planung'),
    );
  });
}
