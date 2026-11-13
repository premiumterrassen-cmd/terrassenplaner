import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'auflagerdaten.dart';

const _f01 = Planungsstand.start;
const _aufbau = Millimeter(82);

/// Ecken des Rechtecks 480 × 309 cm (A oben links, im Uhrzeigersinn).
final _ecken = _f01.grundriss.ecken;

List<Millimeter> _mm(List<int> werte) => [for (final w in werte) Millimeter(w)];

UkVerlegung _verlegung(Planungsstand s) =>
    ukVerlegung(s, ukArtikel, abstand: const Millimeter(400));

Auflagerbedarf _bedarf(
  Planungsstand s, {
  List<int> hoehen = const [86],
  Millimeter abstand = const Millimeter(600),
  bool mitRegelwerk = true,
}) => auflagerbedarf(
  s,
  _verlegung(s),
  uk: ukArtikel,
  abstand: abstand,
  flaeche: Hoehenflaeche(s.grundriss.ecken, _mm(hoehen)),
  aufbauhoehe: _aufbau,
  bereiche: auflagerbereiche(
    auflagerRegelwerk,
    ukArtikel,
    gewerblich: s.gewerblich,
    auflagen: s.auflagen,
  ),
  regelwerk: mitRegelwerk ? auflagerRegelwerk : null,
);

Planungsstand _rechteck8000() => _f01.mitGrundriss(
  RechteckGrundriss(const Millimeter(8000), const Millimeter(3090)),
);

Map<String, int> _zeilen(Auflagerbedarf b) => {
  for (final z in b.zeilen) z.titel: z.anzahl,
};

void main() {
  group('Höhe über der Fläche (M6-11)', () {
    test('ohne Gefälle überall dieselbe Höhe', () {
      final f = Hoehenflaeche(_ecken, _mm([86, 86, 86, 86]));
      expect(f.bei(const Punkt(1234, 567)), const Millimeter(86));
      expect(
        Hoehenflaeche(const [], _mm([120])).bei(Punkt.ursprung),
        const Millimeter(120),
      );
      // Ecken und Höhen passen nicht zusammen: die erste Höhe
      expect(
        Hoehenflaeche(_ecken, _mm([90, 150])).bei(const Punkt(4800, 3090)),
        const Millimeter(90),
      );
    });

    test('F30: A = B = 15, C = D = 8,6 cm – geneigte Ebene exakt, an den '
        'Ecken ihre Höhe', () {
      final f = Hoehenflaeche(_ecken, _mm([150, 150, 86, 86]));
      for (final (i, h) in [150, 150, 86, 86].indexed) {
        expect(f.bei(_ecken[i]), Millimeter(h));
      }
      expect(f.bei(const Punkt(2400, 1545)), const Millimeter(118));
      expect(f.bei(const Punkt(100, 515)), const Millimeter(139));
      expect(f.bei(const Punkt(4700, 2575)), const Millimeter(97));
      // je Ecke eine eigene Höhe: an jeder Ecke genau, dazwischen linear
      final schief = Hoehenflaeche(_ecken, _mm([100, 200, 300, 200]));
      expect(schief.bei(const Punkt(2400, 0)), const Millimeter(150));
      expect(schief.bei(const Punkt(4800, 1545)), const Millimeter(250));
      expect(schief.bei(const Punkt(2400, 1545)), const Millimeter(200));
    });

    test('L-Form (nicht konvex): Ecken genau, Punkte außerhalb aus dem '
        'nächsten Dreieck', () {
      final l = LGrundriss.vorgabe;
      final hoehen = [for (var i = 0; i < l.ecken.length; i++) 80 + 10 * i];
      final f = Hoehenflaeche(l.ecken, _mm(hoehen));
      for (final (i, e) in l.ecken.indexed) {
        expect(f.bei(e), Millimeter(hoehen[i]));
      }
      // knapp außerhalb (Rundung am Rand) liefert trotzdem eine Höhe
      final aussen = f.bei(Punkt(l.ecken.first.x - 1, l.ecken.first.y - 1));
      expect((aussen.mm - hoehen.first).abs(), lessThan(2));
    });

    test('Planungskern v7 (Regel 9.1): Ausgleichsebene, Abweichung nach '
        'Abstand verteilt – L und U in beiden Umlaufrichtungen, Dreieck', () {
      List<int> werte(Hoehenflaeche f, List<Punkt> punkte) => [
        for (final p in punkte) f.bei(p).mm,
      ];
      final l = LGrundriss.vorgabe.ecken;
      final hl = _mm([80, 117, 138, 143, 132, 105]);
      const innenL = [
        Punkt(300, 300),
        Punkt(2500, 300),
        Punkt(300, 2500),
        Punkt(1500, 800),
        Punkt(800, 1500),
        Punkt(1700, 1700),
      ];
      // vorher Dreiecke (Ohrenschnitt): 86, 117, 101, 106, 101, 117
      const sollL = [85, 117, 104, 110, 104, 121];
      expect(werte(Hoehenflaeche(l, hl), innenL), sollL);
      expect(
        werte(Hoehenflaeche(l.reversed.toList(), hl.reversed.toList()), innenL),
        sollL,
      );
      // Kerbe von oben: die Spitze zählt nach ihrem Abstand
      const kerbe = [
        Punkt(0, 0),
        Punkt(4000, 0),
        Punkt(4000, 4000),
        Punkt(2000, 2000),
        Punkt(0, 4000),
      ];
      final k = Hoehenflaeche(kerbe, _mm([100, 100, 100, 300, 100]));
      expect(k.bei(const Punkt(2000, 2000)), const Millimeter(300));
      expect(k.bei(const Punkt(2000, 500)), const Millimeter(186));
      final u = UGrundriss.vorgabe.ecken;
      final hu = _mm([80, 133, 172, 197, 88, 85, 188, 157]);
      for (final (i, e) in u.indexed) {
        expect(Hoehenflaeche(u, hu).bei(e), hu[i]);
      }
      // jedes Auflager der Fläche liegt zwischen der kleinsten und der
      // größten Eckhöhe
      for (var x = 100.0; x < 4000; x += 300) {
        for (var y = 950.0; y < 2700; y += 300) {
          final h = Hoehenflaeche(u, hu).bei(Punkt(x, y)).mm;
          expect(h, inInclusiveRange(80, 197), reason: '($x|$y)');
        }
      }
      // Dreieck: drei Ecken bilden die Ebene genau
      const dreieck = [Punkt(0, 0), Punkt(3000, 0), Punkt(0, 3000)];
      final d = Hoehenflaeche(dreieck, _mm([100, 160, 220]));
      expect(d.bei(const Punkt(1000, 1000)), const Millimeter(160));
    });

    test('Planungskern v7 (Regel 9.1): ein Punkt flach, zwei als Verlauf, '
        'alle auf einer Linie, doppelte Punkte', () {
      // ein Punkt (offener Linienzug mit einer Ecke)
      expect(
        Hoehenflaeche(const [Punkt(500, 500)], _mm([70])).bei(Punkt.ursprung),
        const Millimeter(70),
      );
      // zwei Punkte: Verlauf entlang der Verbindung, quer dazu gleich
      final zwei = Hoehenflaeche(const [
        Punkt(0, 0),
        Punkt(2000, 0),
      ], _mm([100, 200]));
      expect(zwei.bei(const Punkt(1000, 0)), const Millimeter(150));
      expect(zwei.bei(const Punkt(1000, 900)), const Millimeter(150));
      expect(zwei.bei(const Punkt(3000, 0)), const Millimeter(250));
      // zwei gleiche Punkte: flach im Mittel
      expect(
        Hoehenflaeche(const [
          Punkt(0, 0),
          Punkt(0.5, 0),
        ], _mm([100, 120])).bei(const Punkt(5000, 0)),
        const Millimeter(110),
      );
      // drei Punkte auf einer Linie (auch quer zur Diagonale): Verlauf
      // zwischen den äußeren, der mittlere stimmt genau
      final linie = Hoehenflaeche(const [
        Punkt(0, 2000),
        Punkt(1000, 1000),
        Punkt(2000, 0),
      ], _mm([100, 130, 200]));
      expect(linie.bei(const Punkt(0, 2000)), const Millimeter(100));
      expect(linie.bei(const Punkt(1000, 1000)), const Millimeter(130));
      expect(linie.bei(const Punkt(2000, 0)), const Millimeter(200));
      expect(linie.bei(const Punkt(1500, 500)), const Millimeter(166));
      // ein Punkt auf dem Rand zählt, einer knapp außerhalb nicht
      final rand = Hoehenflaeche(_ecken, _mm([100, 100, 100, 100, 40]), const [
        Punkt(2400, 0),
      ]);
      expect(rand.bei(const Punkt(2400, 0)), const Millimeter(40));
      final draussen = Hoehenflaeche(
        _ecken,
        _mm([100, 100, 100, 100, 40]),
        const [Punkt(2400, -2)],
      );
      expect(draussen.bei(const Punkt(2400, 0)), const Millimeter(100));
    });
  });

  group('Auflager mit Höhenzuordnung (M6-11)', () {
    test('F01: 13 Linien à 309 cm mit 60 cm → je 7, alle auf zwei Pads '
        '2 mm (Spalt 86 − 82 − 1 mm Gummiband = 3 mm, Planungskern v6 '
        'Regel 3a.2)', () {
      final b = _bedarf(_f01);
      expect(b.punkte, hasLength(91));
      // Planungskern v6 / Entscheidung 11.11.2026 (Regel 3.6): erstes und
      // letztes Auflager 5 cm vom UK-Ende (vorher 0 und 51,5 cm)
      expect(b.punkte.first.ort, const Punkt(20, 50));
      expect(b.punkte[1].ort.y, closeTo(50 + 2990 / 6, 1e-9));
      expect(b.punkte[6].ort.y, closeTo(3040, 1e-9));
      expect(b.punkte.first.spalt, const Millimeter(3));
      expect(b.punkte.first.zeile, 0);
      expect(b.zeilen, [
        (
          titel: '2 × Unterleger 2 mm',
          anzahl: 91,
          von: const Millimeter(3),
          bis: const Millimeter(3),
        ),
      ]);
      // zwei Pads je Auflager
      expect(b.bedarf.single.einheiten, [pad2]);
      expect(b.bedarf.single.stueck, 182);
      expect(b.stuecke, isEmpty);
      expect(b.punkte.clear, throwsUnsupportedError);
      expect(b.zeilen.clear, throwsUnsupportedError);
      expect(b.bedarf.clear, throwsUnsupportedError);
      expect(b.stuecke.clear, throwsUnsupportedError);
    });

    test('F30 Gefälle: Höhe je Auflager nachvollziehbar, Zuordnung je '
        'Bereich, Packungen über alle Größen', () {
      final s = _f01.mitGefaelle(true);
      final b = _bedarf(s, hoehen: [150, 150, 86, 86]);
      // je Linie von A–B (150) nach D–C (86), erstes und letztes Auflager
      // 5 cm vom Ende (Planungskern v6 / Entscheidung 11.11.2026; vorher
      // 68, 57, 47, 36, 25, 15, 4), abzüglich 1 mm Gummiband (Regel 3a.2.1;
      // vorher 67, 57, 46, 36, 26, 15, 5)
      expect(
        [for (final p in b.punkte.take(7)) p.spalt.mm],
        [66, 56, 45, 35, 25, 14, 4],
      );
      // bis 17 mm Pads, auch zwei übereinander (14 → 8 + 8, 4 → 2 + 2),
      // ab 18 mm Stelzfüße (Regel 3a.2.2/3a.2.3); vorher Unterleger 5 mm
      // und Keil 14-22
      expect(_zeilen(b), {
        '2 × Unterleger 2 mm': 13,
        '2 × Unterleger 8 mm': 13,
        'Keil 18-32': 13,
        'Fuß 35-55 (10)': 26,
        'Fuß 55-95 (20)': 26,
      });
      final fuss = b.zeilen.firstWhere((z) => z.titel == 'Fuß 55-95 (20)');
      expect(fuss.von, const Millimeter(56));
      expect(fuss.bis, const Millimeter(66));
      final pads = {for (final m in b.bedarf) m.einheiten.first: m.stueck};
      expect(pads[pad2], 26);
      expect(pads[pad8], 26);
      expect(pads.containsKey(pad5), isFalse);
      // Zeile je Auflager zeigt in die Tabelle
      expect(b.zeilen[b.punkte.first.zeile!].titel, 'Fuß 55-95 (20)');
      final bedarf35 = b.bedarf.firstWhere((m) => m.einheiten.first == fuss35);
      expect(bedarf35.einheiten, [fuss35, fuss35gross]);
      expect(bedarf35.stueck, 26);
    });

    test('Stellfüße an der Hauswand (Planungskern v6, Regel 3.11): die UK '
        'endet 1 cm vor der Wand, der erste Fuß steht 6 cm von ihr', () {
      final s = _f01.mitAngrenzend(0, an: true);
      final b = auflagerbedarf(
        s,
        ukVerlegung(
          s,
          ukArtikel,
          abstand: const Millimeter(400),
          stellfuesse: true,
        ),
        uk: ukArtikel,
        abstand: const Millimeter(600),
        flaeche: Hoehenflaeche(s.grundriss.ecken, _mm([150])),
        aufbauhoehe: _aufbau,
        bereiche: auflagerbereiche(
          auflagerRegelwerk,
          ukArtikel,
          gewerblich: false,
          auflagen: s.auflagen,
        ),
      );
      expect(b.punkte.first.ort, const Punkt(20, 60));
      expect(b.punkte[6].ort.y, closeTo(3040, 1e-9));
      expect(_zeilen(b), {'Fuß 55-95 (20)': 91});
    });

    test('Stöße der UK bekommen ein Auflager; gewerblich zwei Drittel des '
        'Abstands (F35)', () {
      final gross = _f01.mitGrundriss(
        RechteckGrundriss(const Millimeter(4800), const Millimeter(10000)),
      );
      final b = _bedarf(gross);
      // 6000 + 4000 mm: 10 + 7 Felder, der Stoß gemeinsam → 18 je Linie
      expect(b.punkte, hasLength(13 * 18));
      expect(b.punkte.map((p) => p.ort.y), contains(6000));
      // nach dem Stoß gleichmäßig bis 5 cm vor das Ende: 3950 / 7
      expect(b.punkte[11].ort.y, closeTo(6000 + 3950 / 7, 1e-6));
      expect(b.punkte[17].ort.y, 9950);
      final gewerblich = _bedarf(
        _f01.mitGewerblich(true),
        abstand: auflagerabstand(
          _f01.mitGewerblich(true),
          const Millimeter(600),
        ),
      );
      // 309 cm mit 40 cm: 8 Felder, 9 Auflager je Linie
      expect(gewerblich.punkte, hasLength(13 * 9));
    });

    test('senkrecht verlegt: Auflager längs der waagrechten Hölzer', () {
      final s = _f01.mitVerlegerichtung(Verlegerichtung.senkrecht);
      final b = _bedarf(s);
      // 9 Hölzer à 480 cm, je 9 Auflager (8 Felder à 60 cm)
      expect(b.punkte, hasLength(81));
      expect(b.punkte.first.ort.x, closeTo(4750, 1e-6));
      expect(b.punkte.first.ort.y, closeTo(20, 1e-6));
      expect(b.punkte[1].ort.x, closeTo(4750 - 4700 / 8, 1e-6));
      expect(b.punkte[1].ort.y, closeTo(20, 1e-6));
    });

    test('Stützholz unter der Rinne: ein Auflager in der Mitte '
        '(Planungskern v11, Regel 13.1.4)', () {
      Auflagerbedarf mit(double winkel) => auflagerbedarf(
        _f01,
        UkVerlegung(
          stuetzen: const [(von: Punkt(4643, 50), bis: Punkt(4800, 50))],
          winkel: winkel,
        ),
        uk: ukArtikel,
        abstand: const Millimeter(600),
        flaeche: Hoehenflaeche(_ecken, _mm(const [86])),
        aufbauhoehe: _aufbau,
      );
      final ort = mit(0).punkte.single.ort;
      expect(ort.x, closeTo(4721.5, 1e-9));
      expect(ort.y, closeTo(50, 1e-9));
      // gedreht wie die Linien
      final gedreht = mit(90).punkte.single.ort;
      expect(gedreht.x, closeTo(-50, 1e-9));
      expect(gedreht.y, closeTo(4721.5, 1e-9));
    });

    test('Rand-UK (Planungsregeln 3.3) trägt ihre Auflager wie eine Linie: '
        'diagonal je 480 cm 9, je 309 cm 7, an Stößen eins', () {
      final s = _f01.mitVerlegerichtung(Verlegerichtung.diagonal45);
      final v = _verlegung(s);
      final ohneRand = auflagerbedarf(
        s,
        UkVerlegung(linien: v.linien, winkel: v.winkel),
        uk: ukArtikel,
        abstand: const Millimeter(600),
        flaeche: Hoehenflaeche(s.grundriss.ecken, _mm(const [86])),
        aufbauhoehe: _aufbau,
      );
      final b = _bedarf(s);
      expect(b.punkte, hasLength(ohneRand.punkte.length + 2 * 9 + 2 * 7));
      // die erste Rand-UK (Kante A–B, 2 cm innen) von x = 0 bis 4800
      final rand = b.punkte.skip(ohneRand.punkte.length).take(9).toList();
      for (final (i, p) in rand.indexed) {
        expect(p.ort.x, closeTo(50 + 4700 * i / 8, 1e-6));
        expect(p.ort.y, closeTo(20, 1e-6));
      }
      // 800 × 309 cm diagonal: die lange Rand-UK mit Stoß bei 600 cm
      final lang = _rechteck8000().mitVerlegerichtung(
        Verlegerichtung.diagonal45,
      );
      final orte = [
        for (final p in _bedarf(lang).punkte)
          if ((p.ort.y - 20).abs() < 1e-6) p.ort.x,
      ];
      expect(orte, [
        for (var i = 0; i <= 10; i++) closeTo(50 + 5950 * i / 10, 1e-6),
        for (var k = 1; k <= 4; k++) closeTo(6000 + 1950 * k / 4, 1e-6),
      ]);
    });

    test('kurze UK (Planungsregeln Alexander (Planungskern v6, 11.11.2026), '
        'Regel 3.6): bis 12 cm ein Auflager in der Mitte, darüber 5 cm vom '
        'Ende', () {
      List<double> stellen(double laenge) => [
        for (final p in auflagerbedarf(
          _f01,
          UkVerlegung(
            linien: [
              (x: 0, abschnitte: [(100, 100 + laenge)], stoesse: const []),
            ],
          ),
          uk: ukArtikel,
          abstand: const Millimeter(600),
          flaeche: Hoehenflaeche(_f01.grundriss.ecken, _mm(const [86])),
          aufbauhoehe: _aufbau,
        ).punkte)
          p.ort.y,
      ];
      expect(stellen(100), [150]);
      expect(stellen(120), [160]);
      expect(stellen(121), [150, 171]);
      expect(stellen(700), [150, 450, 750]);
      expect(auflagerRandabstand, const Millimeter(50));
      expect(auflagerEinzelnBis, const Millimeter(120));
    });

    test('Rand-UK am Bogen (Planungskern v12, Regel 14.2.2): am Ende auf '
        'einer Latte kein eigenes Auflager, solange das Stück mehr als eins '
        'hat; Riegel ohne Auflager', () {
      List<double> stellen(
        double laenge, {
        bool von = false,
        bool bis = false,
        List<Strecke> riegel = const [],
      }) => [
        for (final p in auflagerbedarf(
          _f01,
          UkVerlegung(
            rand: [
              (
                von: const Punkt(0, 100),
                bis: Punkt(0, 100 + laenge),
                stoesse: const [],
                ergaenzt: false,
                aufLatte: (von: von, bis: bis),
              ),
            ],
            riegel: riegel,
          ),
          uk: ukArtikel,
          abstand: const Millimeter(600),
          flaeche: Hoehenflaeche(_f01.grundriss.ecken, _mm(const [86])),
          aufbauhoehe: _aufbau,
        ).punkte)
          p.ort.y,
      ];
      expect(stellen(700), [150, 450, 750]);
      expect(stellen(700, von: true), [450, 750]);
      expect(stellen(700, bis: true), [150, 450]);
      expect(stellen(700, von: true, bis: true), [450]);
      expect(stellen(300, von: true, bis: true), isEmpty);
      // ein einzelnes Auflager bleibt
      expect(stellen(100, von: true, bis: true), [150]);
      expect(
        stellen(
          700,
          riegel: [(von: const Punkt(0, 0), bis: const Punkt(500, 0))],
        ),
        [150, 450, 750],
      );
    });

    test('ohne Pads (nur Stelzfüße): zu niedrig ohne Auflager, Zeile null; '
        'ohne Bereiche keine Zeilen', () {
      final b = _bedarf(_f01.mitAuflagen(Auflagen.stelzfuesse));
      expect(b.punkte, hasLength(91));
      expect(b.punkte.every((p) => p.zeile == null), isTrue);
      expect(b.zeilen, isEmpty);
      expect(b.bedarf, isEmpty);
    });

    test('Hochterrasse: Stützen aus UK-Holz in Spaltlänge und je ein '
        'Bodenanker (F28: 91)', () {
      final s = _f01.mitTerrassenart(Terrassenart.hochterrasse);
      final b = _bedarf(s, hoehen: [542]);
      expect(b.punkte, hasLength(91));
      // 542 − 82 − 1 mm Gummiband = 459 mm je Stütze
      expect(b.punkte.first.spalt, const Millimeter(459));
      expect(_zeilen(b), {'UK 40 x 60': 91, 'Bodenanker L': 91});
      expect(b.stuecke, hasLength(91));
      expect(b.stuecke.first.laenge, const Millimeter(459));
      expect(b.stuecke.first.farbe, Stueckfarbe.gruen);
      final holz = b.bedarf.where((m) => m.laenge != null);
      // 91 × 46 cm = 41,9 m aus 6-m-Hölzern (13 Stützen je Holz)
      expect(
        holz.fold(0, (n, m) => n + m.stueck * m.laenge!.mm),
        greaterThanOrEqualTo(91 * 459),
      );
      expect(b.bedarf.last.einheiten, [bodenanker]);
      expect(b.bedarf.last.stueck, 91);
      // ohne Regelwerk keine Bodenanker
      final ohne = _bedarf(s, hoehen: [542], mitRegelwerk: false);
      expect(_zeilen(ohne), {'UK 40 x 60': 91});
      expect(ohne.bedarf.every((m) => m.laenge != null), isTrue);
      // Spalt 0: keine Stütze
      final null0 = _bedarf(s, hoehen: [83]);
      expect(null0.stuecke, isEmpty);
    });

    test('vorhandene UK: je Auflager ein Bodenanker (F29: 13 × 5 = 65)', () {
      final s = _f01.mitTerrassenart(Terrassenart.vorhandeneUk);
      final b = _bedarf(s, hoehen: [142], abstand: s.spannweite);
      expect(b.punkte, hasLength(65));
      expect(_zeilen(b), {'Bodenanker L': 65});
      expect(b.punkte.first.zeile, 0);
      expect(b.zeilen.single.von, const Millimeter(59));
      expect(b.bedarf.single.stueck, 65);
      final ohne = _bedarf(
        s,
        hoehen: [142],
        abstand: s.spannweite,
        mitRegelwerk: false,
      );
      expect(ohne.zeilen, isEmpty);
      expect(ohne.bedarf, isEmpty);
      expect(ohne.punkte.first.zeile, isNull);
    });

    test('ohne Hölzer keine Auflager; feste Obergrenze', () {
      expect(
        auflagerbedarf(
          _f01,
          UkVerlegung.keine,
          uk: ukArtikel,
          abstand: const Millimeter(600),
          flaeche: Hoehenflaeche(const [], _mm([86])),
          aufbauhoehe: _aufbau,
        ),
        same(Auflagerbedarf.keiner),
      );
      final eng = _bedarf(_f01, abstand: const Millimeter(1));
      expect(eng.punkte, hasLength(13 * (hoechsteFelder + 1)));
    });

    test('Unterbau: Auflager und Zuordnung, Transport hin und zurück', () {
      final b = _bedarf(_f01.mitGefaelle(true), hoehen: [150, 150, 86, 86]);
      final u = unterbauFuer(
        _f01,
        hoehen: Hoehenpunkte(hoehen: _mm([86])),
        uk: ukArtikel,
        auflager: b,
      );
      expect(u.auflagerpunkte, b.punkte);
      expect(u.zuordnung, b.zeilen);
      final z = Berechnung.ausBytes(
        Berechnung(umriss: const [], flaeche: 0, unterbau: u).zuBytes(),
      ).unterbau;
      expect(z.auflagerpunkte, b.punkte);
      expect(z.zuordnung, b.zeilen);
      final ohneZeile = Unterbau(
        auflagerpunkte: const [
          (ort: Punkt(1, 2), spalt: Millimeter(300), zeile: null),
        ],
      );
      expect(
        Berechnung.ausBytes(
          Berechnung(
            umriss: const [],
            flaeche: 0,
            unterbau: ohneZeile,
          ).zuBytes(),
        ).unterbau.auflagerpunkte,
        ohneZeile.auflagerpunkte,
      );
      expect(u.auflagerpunkte.clear, throwsUnsupportedError);
      expect(u.zuordnung.clear, throwsUnsupportedError);
      final leer = unterbauFuer(
        _f01,
        hoehen: Hoehenpunkte(hoehen: _mm([86])),
        uk: ukArtikel,
      );
      expect(leer.auflagerpunkte, isEmpty);
      expect(leer.zuordnung, isEmpty);
      // ältere Unterbau-Tabelle ohne Auflager
      final fbb = fb.Builder();
      fbb.startTable(1);
      final ort = fbb.endTable();
      fbb
        ..startTable(111)
        ..addOffset(110, ort);
      fbb.finish(fbb.endTable());
      final alt = Berechnung.ausBytes(fbb.buffer).unterbau;
      expect(alt.auflagerpunkte, isEmpty);
      expect(alt.zuordnung, isEmpty);
    });
  });
}
