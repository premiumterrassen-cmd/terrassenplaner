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

    test('Dreiecke der Ecken (Ohrenschnitt) bei nicht ebenen Höhen: L und U '
        'in beiden Umlaufrichtungen, Dreieck', () {
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
      expect(werte(Hoehenflaeche(l, hl), innenL), [
        86,
        117,
        101,
        106,
        101,
        117,
      ]);
      expect(
        werte(Hoehenflaeche(l.reversed.toList(), hl.reversed.toList()), innenL),
        [86, 117, 101, 106, 101, 117],
      );
      // Kerbe von oben: die Spitze liegt genau auf der Diagonale des
      // Dreiecks unten links – es ist kein Ohr, die Höhe der Spitze zählt
      const kerbe = [
        Punkt(0, 0),
        Punkt(4000, 0),
        Punkt(4000, 4000),
        Punkt(2000, 2000),
        Punkt(0, 4000),
      ];
      final k = Hoehenflaeche(kerbe, _mm([100, 100, 100, 300, 100]));
      expect(k.bei(const Punkt(2000, 500)), const Millimeter(150));
      final u = UGrundriss.vorgabe.ecken;
      final hu = _mm([80, 133, 172, 197, 88, 85, 188, 157]);
      expect(
        werte(Hoehenflaeche(u, hu), const [
          Punkt(200, 200),
          Punkt(900, 900),
          Punkt(200, 2300),
          Punkt(1600, 1600),
          Punkt(3000, 1600),
          Punkt(3700, 900),
          Punkt(3700, 2300),
          Punkt(2300, 2300),
        ]),
        [94, 141, 153, 181, 192, 139, 190, 179],
      );
      // jedes Auflager der Fläche liegt zwischen der kleinsten und der
      // größten Eckhöhe (keine Hochrechnung über ein falsches Dreieck)
      for (var x = 100.0; x < 4000; x += 300) {
        for (var y = 950.0; y < 2700; y += 300) {
          final h = Hoehenflaeche(u, hu).bei(Punkt(x, y)).mm;
          expect(h, inInclusiveRange(80, 197), reason: '($x|$y)');
        }
      }
      // Dreieck: drei Ecken genügen
      const dreieck = [Punkt(0, 0), Punkt(3000, 0), Punkt(0, 3000)];
      final d = Hoehenflaeche(dreieck, _mm([100, 160, 220]));
      expect(d.bei(const Punkt(1000, 1000)), const Millimeter(160));
    });
  });

  group('Auflager mit Höhenzuordnung (M6-11)', () {
    test('F01: 13 Linien à 309 cm mit 60 cm → je 7, alle mit Pad 5 mm '
        '(Spalt 4 mm wie F30 an C/D)', () {
      final b = _bedarf(_f01);
      expect(b.punkte, hasLength(91));
      expect(b.punkte.first.ort, const Punkt(20, 0));
      expect(b.punkte[1].ort.y, closeTo(515, 1e-9));
      expect(b.punkte.first.spalt, const Millimeter(4));
      expect(b.punkte.first.zeile, 0);
      expect(b.zeilen, [
        (
          titel: 'Unterleger 5 mm',
          anzahl: 91,
          von: const Millimeter(4),
          bis: const Millimeter(4),
        ),
      ]);
      expect(b.bedarf.single.einheiten, [pad5]);
      expect(b.bedarf.single.stueck, 91);
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
      // je Linie von A–B (150) nach D–C (86): Spalt 68, 57, 47, 36, 25, 15, 4
      expect(
        [for (final p in b.punkte.take(7)) p.spalt.mm],
        [68, 57, 47, 36, 25, 15, 4],
      );
      expect(_zeilen(b), {
        'Unterleger 5 mm': 13,
        'Keil 14-22': 13,
        'Keil 18-32': 13,
        'Fuß 35-55 (10)': 26,
        'Fuß 55-95 (20)': 26,
      });
      final fuss = b.zeilen.firstWhere((z) => z.titel == 'Fuß 55-95 (20)');
      expect(fuss.von, const Millimeter(57));
      expect(fuss.bis, const Millimeter(68));
      // Zeile je Auflager zeigt in die Tabelle
      expect(b.zeilen[b.punkte.first.zeile!].titel, 'Fuß 55-95 (20)');
      final bedarf35 = b.bedarf.firstWhere((m) => m.einheiten.first == fuss35);
      expect(bedarf35.einheiten, [fuss35, fuss35gross]);
      expect(bedarf35.stueck, 26);
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
      // nach dem Stoß gleichmäßig bis zum Ende: 4000 / 7
      expect(b.punkte[11].ort.y, closeTo(6000 + 4000 / 7, 1e-6));
      expect(b.punkte[17].ort.y, 10000);
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
      expect(b.punkte.first.ort.x, closeTo(4800, 1e-6));
      expect(b.punkte.first.ort.y, closeTo(20, 1e-6));
      expect(b.punkte[1].ort.x, closeTo(4200, 1e-6));
      expect(b.punkte[1].ort.y, closeTo(20, 1e-6));
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
        expect(p.ort.x, closeTo(600 * i, 1e-6));
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
        for (var x = 0; x <= 6000; x += 600) closeTo(x, 1e-6),
        closeTo(6000 + 2000 / 4, 1e-6),
        closeTo(7000, 1e-6),
        closeTo(7500, 1e-6),
        closeTo(8000, 1e-6),
      ]);
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
      // 542 − 82 = 460 mm je Stütze
      expect(b.punkte.first.spalt, const Millimeter(460));
      expect(_zeilen(b), {'UK 40 x 60': 91, 'Bodenanker L': 91});
      expect(b.stuecke, hasLength(91));
      expect(b.stuecke.first.laenge, const Millimeter(460));
      expect(b.stuecke.first.farbe, Stueckfarbe.gruen);
      final holz = b.bedarf.where((m) => m.laenge != null);
      // 91 × 46 cm = 41,9 m aus 6-m-Hölzern (13 Stützen je Holz)
      expect(
        holz.fold(0, (n, m) => n + m.stueck * m.laenge!.mm),
        greaterThanOrEqualTo(91 * 460),
      );
      expect(b.bedarf.last.einheiten, [bodenanker]);
      expect(b.bedarf.last.stueck, 91);
      // ohne Regelwerk keine Bodenanker
      final ohne = _bedarf(s, hoehen: [542], mitRegelwerk: false);
      expect(_zeilen(ohne), {'UK 40 x 60': 91});
      expect(ohne.bedarf.every((m) => m.laenge != null), isTrue);
      // Spalt 0: keine Stütze
      final null0 = _bedarf(s, hoehen: [82]);
      expect(null0.stuecke, isEmpty);
    });

    test('vorhandene UK: je Auflager ein Bodenanker (F29: 13 × 5 = 65)', () {
      final s = _f01.mitTerrassenart(Terrassenart.vorhandeneUk);
      final b = _bedarf(s, hoehen: [142], abstand: s.spannweite);
      expect(b.punkte, hasLength(65));
      expect(_zeilen(b), {'Bodenanker L': 65});
      expect(b.punkte.first.zeile, 0);
      expect(b.zeilen.single.von, const Millimeter(60));
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
