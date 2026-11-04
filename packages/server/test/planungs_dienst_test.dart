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

    test('Zubehör (M8-02): Clips aus der Befestigung, Eingaben '
        '„Tatsächlich“ gehen vor', () {
      Map<String, (int, int)> zeilen(Berechnung b) => {
        for (final z in b.zubehoer) z.nummer.wert: (z.berechnet, z.menge),
      };
      final stand = Planungsstand.start
          .mitZubehoermenge(const Artikelnummer('80-10-001-250'), 3)
          .mitZubehoermenge(const Artikelnummer('50-80-006'), 2);
      expect(zeilen(PlanungsDienst.berechne(stand, diele, regelwerk)), {
        '80-10-001-50': (1, 1),
        '80-10-001-100': (1, 1),
        '80-10-001-250': (2, 3),
        '50-80-006': (0, 2),
      });
      // ohne Regelwerk und ohne Belag: nur die Eingaben
      for (final b in [
        PlanungsDienst.berechne(stand, diele),
        PlanungsDienst.berechne(stand),
      ]) {
        expect(zeilen(b), {'80-10-001-250': (0, 3), '50-80-006': (0, 2)});
      }
      expect(
        PlanungsDienst.berechnePlanung(
          Planung([Terrassenflaeche(stand)]),
          (_) => diele,
          regelwerk,
        ).zubehoer,
        hasLength(4),
      );
    });

    test('Pflichtzubehör (M8-03): je Diele, je Befestigung, je Eingabe, '
        'nicht abwählbar', () {
      Artikel teil(String nummer) => Artikel(
        nummer: Artikelnummer(nummer),
        titel: 'Teil $nummer',
        art: Artikelart.sonstiges,
        einheit: Verkaufseinheit(Mengeneinheit.stueck),
      );
      final pflichtig = Regelwerk(
        Artikeldatei(
          quelle: 'test',
          version: '2',
          eintraege: [
            Artikeleintrag(
              artikel: diele,
              verweise: {
                Beziehung.befestigung.spalte: [for (final c in clips) c.nummer],
              },
              angaben: const {'Abstand_UK': 400},
              benoetigt: const {Artikelnummer('p-diele'): 1},
            ),
            for (final c in clips)
              Artikeleintrag(
                artikel: c,
                benoetigt: const {Artikelnummer('p-clip'): 2},
              ),
            Artikeleintrag(
              artikel: teil('vlies'),
              benoetigt: const {Artikelnummer('p-vlies'): 3},
            ),
            for (final n in ['p-diele', 'p-clip', 'p-vlies'])
              Artikeleintrag(artikel: teil(n)),
          ],
        ),
      );
      Map<String, (int, int, int)> zeilen(Berechnung b) => {
        for (final z in b.zubehoer)
          z.nummer.wert: (z.berechnet, z.menge, z.pflicht),
      };
      final stand = Planungsstand.start
          .mitZubehoermenge(const Artikelnummer('vlies'), 2)
          .mitZubehoermenge(const Artikelnummer('p-clip'), 1);
      // F01: 48 Dielen; 4 Clip-Packungen à 2; 2 × Vlies à 3
      expect(zeilen(PlanungsDienst.berechne(stand, diele, pflichtig)), {
        '80-10-001-50': (1, 1, 0),
        '80-10-001-100': (1, 1, 0),
        '80-10-001-250': (2, 2, 0),
        'p-diele': (48, 48, 48),
        'p-clip': (8, 8, 8),
        'p-vlies': (6, 6, 6),
        'vlies': (0, 2, 0),
      });
      // ohne Verlegung: nur das Pflichtzubehör der Eingaben
      expect(zeilen(PlanungsDienst.berechne(stand, null, pflichtig)), {
        'p-vlies': (6, 6, 6),
        'p-clip': (0, 1, 0),
        'vlies': (0, 2, 0),
      });
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

      test('Zubehör (M8-02/M8-03): Tatsächlich in Verkaufseinheiten, '
          'Werkzeug einmal je Planung, geänderte Clips aus dem Zubehör', () {
        Artikel zubehoer(String nummer, Artikelart art, {int inhalt = 1}) =>
            Artikel(
              nummer: Artikelnummer(nummer),
              titel: 'Zubehör $nummer',
              art: art,
              einheit: Verkaufseinheit(Mengeneinheit.karton, inhalt: inhalt),
            );
        final vlies = zubehoer('vlies', Artikelart.sonstiges, inhalt: 10);
        final bit = zubehoer('bit', Artikelart.werkzeug);
        final mitZubehoer = Regelwerk(
          Artikeldatei(
            quelle: 'test',
            version: '3',
            eintraege: [
              ...regelwerk.datei.eintraege,
              Artikeleintrag(artikel: vlies),
              Artikeleintrag(artikel: bit),
            ],
          ),
        );
        var stand = Planungsstand.start
            .mitZubehoermenge(vlies.nummer, 3)
            .mitZubehoermenge(bit.nummer, 1)
            .mitZubehoermenge(const Artikelnummer('unbekannt'), 4);
        final zweimal = Planung([Terrassenflaeche(stand, haeufigkeit: 2)]);
        expect(
          zeilen(
            PlanungsDienst.berechnePlanung(
              zweimal,
              (_) => diele,
              mitZubehoer,
            ).materialliste,
          ),
          {
            ('10-10-073-R', 5000): 96,
            // 2 × 637 Clips zusammen verpackt: 5 × 250 + 50
            ('80-10-001-250', null): 5,
            ('80-10-001-50', null): 1,
            // 3 Kartons je Fläche, das Bit nur einmal
            ('vlies', null): 6,
            ('bit', null): 1,
          },
        );
        // Clips im Zubehör geändert: die Zubehörmengen gelten, je Fläche
        stand = stand.mitZubehoermenge(const Artikelnummer('80-10-001-250'), 3);
        expect(
          zeilen(
            PlanungsDienst.berechnePlanung(
              Planung([Terrassenflaeche(stand, haeufigkeit: 2)]),
              (_) => diele,
              mitZubehoer,
            ).materialliste,
          ),
          {
            ('10-10-073-R', 5000): 96,
            ('80-10-001-50', null): 2,
            ('80-10-001-100', null): 2,
            ('80-10-001-250', null): 6,
            ('vlies', null): 6,
            ('bit', null): 1,
          },
        );
        // Abgewählt (0) fehlt in der Materialliste
        expect(
          zeilen(
            PlanungsDienst.berechnePlanung(
              Planung([
                Terrassenflaeche(stand.mitZubehoermenge(vlies.nummer, 0)),
              ]),
              (_) => diele,
              mitZubehoer,
            ).materialliste,
          ).keys,
          isNot(contains(('vlies', null))),
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
