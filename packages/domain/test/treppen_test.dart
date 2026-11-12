import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'argument_fehler.dart';

final _belag = Artikel(
  nummer: const Artikelnummer('10-10-073'),
  titel: 'Diele',
  art: Artikelart.diele,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: const Millimeter(60),
    staerke: const Millimeter(21),
    laengen: const [Millimeter(4000), Millimeter(5000)],
  ),
  holzart: robinie,
  serie: basic,
);

final _uk = Artikel(
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

/// F39: Treppe an C — D (Seite 2), Vorgaben.
final _f39 = Planungsstand.start.mitNeuerTreppe().mitTreppe(
  0,
  const Treppe(seite: 2),
);

const _mm = Millimeter.new;

List<int> _laengen(List<Planstueck> stuecke, Artikelnummer nummer) => [
  for (final s in stuecke)
    if (s.nummer == nummer) s.laenge.mm,
];

void main() {
  group('Treppe (M7-05)', () {
    test('Vorgaben und Treppenmaße L × B × H je Art (F39, F41, F42)', () {
      const t = Treppe();
      expect(t.seite, 0);
      expect(t.abstand, _mm(0));
      expect(t.breite, _mm(1000));
      expect(t.bau, Treppenbau.konstruktion);
      expect(t.art, Treppenart.regulaer);
      expect(t.individuell, isFalse);
      expect(t.anzahl, 2);
      expect(t.stufe, (tiefe: _mm(270), hoehe: _mm(156)));
      expect(t.podest, (tiefe: _mm(500), breite: _mm(540), hoehe: _mm(156)));
      expect(t.masse, (laenge: _mm(1000), breite: _mm(540), hoehe: _mm(312)));
      expect(t.mit(art: Treppenart.zweiteilig).masse, (
        laenge: _mm(1040),
        breite: _mm(1080),
        hoehe: _mm(468),
      ));
      expect(t.mit(art: Treppenart.dreiteilig).masse, (
        laenge: _mm(1580),
        breite: _mm(1080),
        hoehe: _mm(468),
      ));
      expect(Treppenart.regulaer.mitPodest, isFalse);
      expect(Treppenart.zweiteilig.mitPodest, isTrue);
    });

    test('individuelle Stufenmaße: je Stufe, fehlende wie das gemeinsame', () {
      const t = Treppe(anzahl: 3);
      final eigen = t.mitStufe(1, (tiefe: _mm(300), hoehe: _mm(170)));
      expect(eigen.individuell, isTrue);
      expect(eigen.stufenmasse, [
        t.stufe,
        (tiefe: _mm(300), hoehe: _mm(170)),
        t.stufe,
      ]);
      expect(eigen.masse.hoehe, _mm(156 + 170 + 156));
      // ausgeschaltet gilt wieder das gemeinsame Maß, die Maße bleiben
      final aus = eigen.mit(individuell: false);
      expect(aus.stufenmasse, List.filled(3, t.stufe));
      expect(aus.stufen, hasLength(3));
      // mehr Stufen als individuelle Maße
      expect(eigen.mit(anzahl: 4).stufenmasse.last, t.stufe);
      expect(() => t.mitStufe(3, t.stufe), throwsRangeError);
      expect(eigen.stufen.clear, throwsUnsupportedError);
    });

    test('Grenzen der Eingaben', () {
      const t = Treppe();
      expect(
        () => t.mit(abstand: _mm(-1)),
        wirftArgumentFehler('abstand', -1, 'außerhalb der Grenzen'),
      );
      expect(() => t.mit(abstand: _mm(300001)), throwsArgumentError);
      expect(t.mit(abstand: _mm(300000)).abstand, _mm(300000));
      expect(
        () => t.mit(breite: _mm(99)),
        wirftArgumentFehler('breite', 99, 'außerhalb der Grenzen'),
      );
      expect(() => t.mit(breite: _mm(10001)), throwsArgumentError);
      expect(t.mit(breite: _mm(100)).breite, _mm(100));
      expect(t.mit(breite: _mm(10000)).breite, _mm(10000));
      expect(
        () => t.mit(anzahl: 0),
        wirftArgumentFehler('anzahl', 0, 'außerhalb der Grenzen'),
      );
      expect(() => t.mit(anzahl: 21), throwsArgumentError);
      expect(t.mit(anzahl: 20).anzahl, 20);
      expect(t.mit(anzahl: 1).anzahl, 1);
      expect(
        () => t.mit(stufe: (tiefe: _mm(49), hoehe: _mm(156))),
        wirftArgumentFehler('tiefe', 49, 'außerhalb der Grenzen'),
      );
      expect(
        () => t.mit(stufe: (tiefe: _mm(1001), hoehe: _mm(156))),
        throwsArgumentError,
      );
      expect(
        () => t.mit(stufen: [(tiefe: _mm(270), hoehe: _mm(9))]),
        wirftArgumentFehler('hoehe', 9, 'außerhalb der Grenzen'),
      );
      expect(
        () => t.mit(stufen: [(tiefe: _mm(270), hoehe: _mm(501))]),
        throwsArgumentError,
      );
      expect(t.mit(stufe: (tiefe: _mm(50), hoehe: _mm(10))).stufe, (
        tiefe: _mm(50),
        hoehe: _mm(10),
      ));
      expect(t.mit(stufe: (tiefe: _mm(1000), hoehe: _mm(500))).stufe, (
        tiefe: _mm(1000),
        hoehe: _mm(500),
      ));
      for (final podest in [
        (tiefe: _mm(99), breite: _mm(540), hoehe: _mm(156)),
        (tiefe: _mm(500), breite: _mm(10001), hoehe: _mm(156)),
        (tiefe: _mm(500), breite: _mm(540), hoehe: _mm(9)),
      ]) {
        expect(
          () => t.mit(podest: podest),
          throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'podest')),
        );
      }
      expect(
        t.mit(podest: (tiefe: _mm(100), breite: _mm(100), hoehe: _mm(10))),
        isA<Treppe>(),
      );
    });

    test('Gleichheit, Hash und Nummern', () {
      const t = Treppe();
      expect(t, const Treppe());
      expect(t.hashCode, const Treppe().hashCode);
      for (final anders in [
        t.mit(seite: 1),
        t.mit(abstand: _mm(10)),
        t.mit(breite: _mm(900)),
        t.mit(bau: Treppenbau.fundament),
        t.mit(art: Treppenart.zweiteilig),
        t.mit(individuell: true),
        t.mit(anzahl: 3),
        t.mit(stufe: (tiefe: _mm(280), hoehe: _mm(156))),
        t.mit(stufen: [t.stufe]),
        t.mit(podest: (tiefe: _mm(600), breite: _mm(540), hoehe: _mm(156))),
      ]) {
        expect(anders == t, isFalse, reason: '$anders');
        expect(anders.hashCode == t.hashCode, isFalse);
      }
      expect(t.mit(stufen: [t.stufe]) == t.mit(stufen: [t.stufe]), isTrue);
      expect(
        t.mit(stufen: [t.stufe]) ==
            t.mit(stufen: [(tiefe: _mm(270), hoehe: _mm(157))]),
        isFalse,
      );
      expect(t == Object(), isFalse);
      for (final a in Treppenart.values) {
        expect(Treppenart.ausNummer(a.nummer), a);
      }
      for (final b in Treppenbau.values) {
        expect(Treppenbau.ausNummer(b.nummer), b);
      }
      expect([for (final a in Treppenart.values) a.nummer], [0, 1, 2]);
      expect([for (final b in Treppenbau.values) b.nummer], [0, 1]);
      expect(() => Treppenart.ausNummer(3), throwsFormatException);
      expect(() => Treppenbau.ausNummer(2), throwsFormatException);
    });
  });

  group('Treppen im Planungsstand (M7-05)', () {
    const f01 = Planungsstand.start;

    test('neue Treppe an der ersten freien Seite', () {
      expect(f01.treppen, isEmpty);
      expect(f01.mitNeuerTreppe().treppen.single, const Treppe());
      final belegt = f01
          .mitAngrenzend(0, an: true)
          .mitRinne(1, Rinnenlage.gesamteSeite);
      expect(belegt.mitNeuerTreppe().treppen.single.seite, 2);
      // alles belegt: die letzte Seite
      final voll = belegt.mitAngrenzend(2, an: true).mitAngrenzend(3, an: true);
      expect(voll.mitNeuerTreppe().treppen.single.seite, 3);
      expect(f01.mitNeuerTreppe().mitNeuerTreppe().treppen, hasLength(2));
      expect(f01.mitNeuerTreppe().treppen.clear, throwsUnsupportedError);
    });

    test('ändern, entfernen, Transportformat, Gleichheit', () {
      final t = f01.mitNeuerTreppe();
      final geaendert = t.mitTreppe(
        0,
        const Treppe(seite: 3, art: Treppenart.dreiteilig),
      );
      expect(geaendert.treppen.single.seite, 3);
      expect(() => t.mitTreppe(1, const Treppe()), throwsRangeError);
      expect(() => t.mitTreppe(0, const Treppe(seite: 4)), throwsRangeError);
      expect(geaendert.ohneTreppe(0), f01);
      expect(geaendert == t, isFalse);
      expect(geaendert.hashCode == t.hashCode, isFalse);
      expect(t == t.mitNeuerTreppe(), isFalse);
      final voll = geaendert.mitTreppe(
        0,
        geaendert.treppen.single
            .mit(
              abstand: _mm(500),
              breite: _mm(1200),
              bau: Treppenbau.fundament,
              anzahl: 3,
              podest: (tiefe: _mm(600), breite: _mm(700), hoehe: _mm(170)),
            )
            .mitStufe(2, (tiefe: _mm(300), hoehe: _mm(180))),
      );
      expect(Planungsstand.ausBytes(voll.zuBytes()), voll);
      expect(Planungsstand.ausBytes(f01.zuBytes()).treppen, isEmpty);
    });

    test('bleibt bei neuen Maßen, beginnt bei neuer Form neu', () {
      final t = f01.mitNeuerTreppe();
      expect(
        t
            .mitGrundriss(
              RechteckGrundriss(const Millimeter(5000), const Millimeter(3000)),
            )
            .treppen,
        hasLength(1),
      );
      expect(t.mitForm(Terrassenform.rechteck).treppen, isEmpty);
      expect(t.mitForm(Terrassenform.lForm).treppen, isEmpty);
    });
  });

  group('Teile und Zeichnung (M7-05)', () {
    test('reguläre Treppe: Stufen von oben, Oberkanten, Stirnkanten', () {
      final teile = treppenteile(const Treppe());
      expect(teile, hasLength(2));
      expect(teile[0].umriss, const [
        Punkt(0, 0),
        Punkt(1000, 0),
        Punkt(1000, 270),
        Punkt(0, 270),
      ]);
      expect(teile[1].umriss.last, const Punkt(0, 540));
      expect(teile[0].auftritte, [(1000.0, 270.0)]);
      expect(teile[0].stirnkanten, [1000.0]);
      expect(teile[0].steigung, _mm(156));
      expect([for (final t in teile) t.oberkante.mm], [312, 156]);
    });

    test('2-teilige Fächertreppe: Podest und Stufen als L', () {
      final teile = treppenteile(const Treppe(art: Treppenart.zweiteilig));
      expect(teile, hasLength(3));
      expect(teile[0].umriss.last, const Punkt(0, 540));
      expect(teile[0].auftritte, [(500.0, 540.0)]);
      expect(teile[0].stirnkanten, [500.0, 540.0]);
      expect([for (final t in teile) t.oberkante.mm], [468, 312, 156]);
      expect(teile[1].umriss, const [
        Punkt(0, 540),
        Punkt(500, 540),
        Punkt(500, 0),
        Punkt(770, 0),
        Punkt(770, 810),
        Punkt(0, 810),
      ]);
      expect(teile[2].auftritte, [(1040.0, 270.0), (810.0, 270.0)]);
      expect(teile[2].stirnkanten, [1040.0, 1080.0]);
    });

    test('3-teilige Fächertreppe: Podest in der Mitte, Stufen als U', () {
      final teile = treppenteile(const Treppe(art: Treppenart.dreiteilig));
      expect(teile[0].umriss.first, const Punkt(540, 0));
      expect(teile[0].stirnkanten, [500.0, 540.0, 540.0]);
      expect(teile[2].umriss.first, const Punkt(0, 0));
      expect(teile[2].umriss[5], const Punkt(1580, 0));
      expect(teile[1].auftritte, [
        (1040.0, 270.0),
        (540.0, 270.0),
        (540.0, 270.0),
      ]);
      expect(teile[1].stirnkanten, [1040.0, 810.0, 810.0]);
      expect(teile[1].steigung, _mm(156));
    });

    test('F39: an C — D außen vor der Seite, frei; an Bauelement oder '
        'Rinne nicht', () {
      final [erste, zweite] = treppenumrisse(_f39, _f39.treppen.single);
      expect(erste, const [
        Punkt(4800, 3090),
        Punkt(3800, 3090),
        Punkt(3800, 3360),
        Punkt(4800, 3360),
      ]);
      expect(zweite.last, const Punkt(4800, 3630));
      // im Uhrzeigersinn umlaufen: außen bleibt außen
      final rechtsherum = Planungsstand.start
          .mitGrundriss(
            FreiformGrundriss(const [
              Punkt(0, 0),
              Punkt(0, 3000),
              Punkt(4000, 3000),
              Punkt(4000, 0),
            ], geschlossen: true),
          )
          .mitNeuerTreppe();
      expect(
        treppenumrisse(rechtsherum, rechtsherum.treppen.single).first[2],
        const Punkt(-270, 1000),
      );
      final versetzt = _f39.mitTreppe(
        0,
        const Treppe(seite: 2, abstand: Millimeter(200)),
      );
      expect(
        treppenumrisse(versetzt, versetzt.treppen.single).first.first,
        const Punkt(4600, 3090),
      );
      expect(treppeErlaubt(_f39, _f39.treppen.single), isTrue);
      expect(
        treppeErlaubt(_f39.mitAngrenzend(2, an: true), _f39.treppen.single),
        isFalse,
      );
      expect(
        treppeErlaubt(
          _f39.mitRinne(2, Rinnenlage.gesamteSeite),
          _f39.treppen.single,
        ),
        isFalse,
      );
      expect(
        treppeErlaubt(_f39.mitVerblendet(2, an: true), _f39.treppen.single),
        isTrue,
      );
      final [bild] = treppenbilder(_f39.mitAngrenzend(2, an: true));
      expect(bild.frei, isFalse);
      expect(bild.masse, _f39.treppen.single.masse);
      expect(bild.teile, hasLength(2));
      final ergebnis = anschlussergebnis(_f39);
      expect(ergebnis.treppen.single.frei, isTrue);
      final zurueck = Berechnung.ausBytes(
        Berechnung(umriss: const [], flaeche: 0, anschluss: ergebnis).zuBytes(),
      ).anschluss.treppen.single;
      expect(zurueck.teile, ergebnis.treppen.single.teile);
      expect(zurueck.masse, ergebnis.treppen.single.masse);
      expect(zurueck.frei, isTrue);
      expect(
        Berechnung.ausBytes(
          Berechnung(
            umriss: const [],
            flaeche: 0,
            anschluss: anschlussergebnis(_f39.mitAngrenzend(2, an: true)),
          ).zuBytes(),
        ).anschluss.treppen.single.frei,
        isFalse,
      );
    });
  });

  group('Material der Treppen (M7-05)', () {
    test('F39: 16 Dielen à 100 cm, UK je Stufe 4 × 27 cm und Stützen', () {
      final stuecke = treppenstuecke(
        const Treppe(),
        belag: _belag,
        uk: _uk,
        ukAbstand: _mm(400),
      );
      expect(_laengen(stuecke, _belag.nummer), List.filled(16, 1000));
      expect(_laengen(stuecke, _uk.nummer), [
        ...List.filled(4, 270),
        ...List.filled(4, 231),
        ...List.filled(4, 270),
        ...List.filled(4, 75),
      ]);
      expect(stuecke.first.ganzeLaenge, _mm(5000));
      expect(
        stuecke.firstWhere((s) => s.nummer == _uk.nummer).ganzeLaenge,
        _mm(6000),
      );
      // Fundament: ohne Stützen
      expect(
        _laengen(
          treppenstuecke(
            const Treppe(bau: Treppenbau.fundament),
            belag: _belag,
            uk: _uk,
            ukAbstand: _mm(400),
          ),
          _uk.nummer,
        ),
        List.filled(8, 270),
      );
      // ohne UK oder Abstand nur Dielen
      expect(
        treppenstuecke(const Treppe(), belag: _belag, uk: _uk),
        hasLength(16),
      );
      expect(treppenstuecke(const Treppe(), belag: _belag), hasLength(16));
      // UK ohne Maße: ohne UK
      expect(
        treppenstuecke(
          const Treppe(),
          belag: _belag,
          uk: Artikel(
            nummer: const Artikelnummer('70-10-001'),
            titel: 'Alu',
            art: Artikelart.aluUnterkonstruktion,
            einheit: Verkaufseinheit(Mengeneinheit.stueck),
          ),
          ukAbstand: _mm(400),
        ),
        hasLength(16),
      );
    });

    test('Stütze nur über dem Boden; Belag ohne Maße; ohne Längen', () {
      final niedrig = treppenstuecke(
        const Treppe(
          anzahl: 1,
          stufe: (tiefe: Millimeter(270), hoehe: Millimeter(81)),
        ),
        belag: _belag,
        uk: _uk,
        ukAbstand: _mm(400),
      );
      // 81 − 21 − 60 = 0: keine Stütze
      expect(_laengen(niedrig, _uk.nummer), List.filled(4, 270));
      final ohneLaengen = Artikel(
        nummer: const Artikelnummer('10-10-999'),
        titel: 'Diele',
        art: Artikelart.holzfliese,
        einheit: Verkaufseinheit(Mengeneinheit.stueck),
        abmessungen: Abmessungen(
          breite: const Millimeter(60),
          staerke: const Millimeter(21),
        ),
      );
      final ohne = treppenstuecke(const Treppe(), belag: ohneLaengen);
      expect(ohne.first.ganzeLaenge, _mm(1000));
      final alu = Artikel(
        nummer: const Artikelnummer('70-10-002'),
        titel: 'UK ohne Längen',
        art: Artikelart.aluUnterkonstruktion,
        einheit: Verkaufseinheit(Mengeneinheit.stueck),
        abmessungen: Abmessungen(
          breite: const Millimeter(40),
          staerke: const Millimeter(60),
        ),
      );
      expect(
        treppenstuecke(
          const Treppe(),
          belag: _belag,
          uk: alu,
          ukAbstand: _mm(400),
        ).where((s) => s.nummer == alu.nummer).last.ganzeLaenge,
        _mm(75),
      );
      expect(
        treppenstuecke(
          const Treppe(),
          belag: Artikel(
            nummer: const Artikelnummer('x'),
            titel: 'ohne Maße',
            art: Artikelart.verblendung,
            einheit: Verkaufseinheit(Mengeneinheit.stueck),
          ),
        ),
        isEmpty,
      );
    });

    test('Bedarf: Dielen als Lieferstücke, UK aus den Resten, nur freie '
        'Treppen', () {
      final b = treppenbedarf(
        _f39,
        belag: _belag,
        uk: _uk,
        ukAbstand: _mm(400),
      );
      expect(b.meldungen, isEmpty);
      // 16 × 100 cm aus 4000/5000 mm
      expect(
        b.bedarf.fold(0, (s, m) => s + m.laenge!.mm * m.stueck),
        greaterThanOrEqualTo(16000),
      );
      expect(b.bedarf.every((m) => m.einheiten.single == _belag), isTrue);
      expect(b.stuecke, hasLength(32));
      // feste Dielenlänge
      final fest = treppenbedarf(
        _f39.mitDielenlaenge(_mm(4000)),
        belag: _belag,
      );
      expect(fest.bedarf.every((m) => m.laenge == _mm(4000)), isTrue);
      // nicht frei: kein Material, Hinweis
      final belegt = treppenbedarf(
        _f39.mitAngrenzend(2, an: true),
        belag: _belag,
      );
      expect(belegt.bedarf, isEmpty);
      expect(belegt.meldungen, [Anschlussmeldung.treppeNichtFrei]);
      expect(treppenbedarf(_f39).meldungen, isEmpty);
      expect(treppenbedarf(_f39).stuecke, isEmpty);
      // zusammen mit der UK-Verlegung (F01: 13 × 309 cm): keine weitere UK
      final alles = anschlussbedarf(
        _f39,
        hoehen: const [_mm86, _mm86, _mm86, _mm86],
        belag: _belag,
        uk: _uk,
        ukAbstand: _mm(400),
        ukStuecke: List.filled(13, _mm(3090)),
      );
      expect(alles.bedarf.where((m) => m.einheiten.single == _uk), isEmpty);
      expect(
        anschlussbedarf(
          _f39,
          hoehen: const [_mm86, _mm86, _mm86, _mm86],
          belag: _belag,
          uk: _uk,
          ukAbstand: _mm(400),
        ).bedarf.where((m) => m.einheiten.single == _uk),
        isNotEmpty,
      );
    });
  });
  group('Treppe nach dem Planungskern v7 (Regel 9.5)', () {
    Artikel diele(String nummer, Profil profil, {int breite = 140}) => Artikel(
      nummer: Artikelnummer(nummer),
      titel: 'Diele $nummer',
      art: Artikelart.diele,
      einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
      abmessungen: Abmessungen(
        breite: Millimeter(breite),
        staerke: const Millimeter(21),
        laengen: const [Millimeter(4000)],
      ),
      holzart: robinie,
      serie: basic,
      profil: profil,
    );
    final genutet = diele('10-10-100', Profil.genutet);
    final glatt = diele('10-10-101', Profil.glattkant);
    final regelwerk = Regelwerk(
      Artikeldatei(
        quelle: 'test',
        version: '1',
        eintraege: [
          Artikeleintrag(artikel: genutet),
          Artikeleintrag(artikel: glatt),
        ],
      ),
    );

    test('Prüfliste: Steigung, Schrittmaß, Breite, Seite', () {
      expect(treppenUkAbstand, _mm(400));
      expect(treppenSteigung, (von: _mm(150), bis: _mm(190)));
      expect(treppenSchrittmass, (von: _mm(590), bis: _mm(670)));
      expect(treppenMindestbreite, _mm(500));
      // Vorgabe des alten Planers 27 × 15,6: Schrittmaß 58,2 cm
      expect(treppenpruefung(_f39, _f39.treppen.single), [
        Treppenmeldung.schrittmass,
      ]);
      Treppe stufe(int tiefe, int hoehe) => Treppe(
        seite: 2,
        stufe: (tiefe: Millimeter(tiefe), hoehe: Millimeter(hoehe)),
      );
      // Grenzen selbst ohne Hinweis: 15 cm + 29 cm = 59, 19 + 29 = 67
      expect(treppenpruefung(_f39, stufe(290, 150)), isEmpty);
      expect(treppenpruefung(_f39, stufe(290, 190)), isEmpty);
      expect(treppenpruefung(_f39, stufe(290, 149)), [
        Treppenmeldung.steigung,
        Treppenmeldung.schrittmass,
      ]);
      expect(treppenpruefung(_f39, stufe(300, 191)), [
        Treppenmeldung.steigung,
        Treppenmeldung.schrittmass,
      ]);
      expect(treppenpruefung(_f39, stufe(291, 190)), [
        Treppenmeldung.schrittmass,
      ]);
      // Podest der Fächertreppe zählt als Steigung
      final faecher = stufe(290, 170).mit(
        art: Treppenart.zweiteilig,
        podest: (tiefe: _mm(500), breite: _mm(540), hoehe: _mm(140)),
      );
      expect(treppenpruefung(_f39, faecher), [Treppenmeldung.steigung]);
      // schmaler als 50 cm, über das Ende der Seite (C — D 480 cm)
      final eng = stufe(290, 170).mit(breite: _mm(499));
      expect(treppenpruefung(_f39, eng), [Treppenmeldung.zuSchmal]);
      expect(
        treppenpruefung(_f39, eng.mit(breite: _mm(500), abstand: _mm(4300))),
        isEmpty,
      );
      expect(
        treppenpruefung(_f39, eng.mit(breite: _mm(500), abstand: _mm(4301))),
        [Treppenmeldung.ueberSeite],
      );
      // Seite gibt es nicht (mehr): ohne Prüfung der Länge
      expect(
        treppenpruefung(_f39, Treppe(seite: 9, stufe: stufe(290, 170).stufe)),
        isEmpty,
      );
      expect(Treppenmeldung.ausNummer(4), Treppenmeldung.ueberSeite);
      expect(() => Treppenmeldung.ausNummer(0), throwsFormatException);
    });

    test('Meldungen im Treppenbild und im Transportformat', () {
      final [bild] = treppenbilder(_f39);
      expect(bild.meldungen, [Treppenmeldung.schrittmass]);
      final zurueck = Berechnung.ausBytes(
        Berechnung(
          umriss: const [],
          flaeche: 0,
          anschluss: anschlussergebnis(_f39),
        ).zuBytes(),
      ).anschluss.treppen.single;
      expect(zurueck.meldungen, [Treppenmeldung.schrittmass]);
      final ohne = _f39.mitTreppe(
        0,
        const Treppe(
          seite: 2,
          stufe: (tiefe: Millimeter(290), hoehe: Millimeter(170)),
        ),
      );
      expect(
        Berechnung.ausBytes(
          Berechnung(
            umriss: const [],
            flaeche: 0,
            anschluss: anschlussergebnis(ohne),
          ).zuBytes(),
        ).anschluss.treppen.single.meldungen,
        isEmpty,
      );
    });

    test('UK unter dem Auftritt höchstens 40 cm Achsabstand', () {
      int ukLinien(Millimeter abstand) => _laengen(
        treppenstuecke(
          const Treppe(bau: Treppenbau.fundament, anzahl: 1),
          belag: _belag,
          uk: _uk,
          ukAbstand: abstand,
        ),
        _uk.nummer,
      ).length;
      // 100 cm: mit 40 cm 4 Linien, mit 50 cm wären es 3
      expect(ukLinien(_mm(500)), 4);
      expect(ukLinien(_mm(400)), 4);
      expect(ukLinien(_mm(300)), 5);
    });

    test('Setzstufen aus dem glattkanten Brett der Serie', () {
      expect(setzstufenbrett(genutet, regelwerk), glatt);
      expect(setzstufenbrett(genutet, null), genutet);
      expect(setzstufenbrett(glatt, regelwerk), glatt);
      expect(
        setzstufenbrett(
          genutet,
          Regelwerk(
            Artikeldatei(
              quelle: 'test',
              version: '1',
              eintraege: [Artikeleintrag(artikel: genutet)],
            ),
          ),
        ),
        genutet,
      );
      expect(setzstufenbrett(_belag, regelwerk), _belag);
      // 2 Stufen 27 × 15,6 cm: Auftritt 2 Reihen genutet (14 cm + 6 mm),
      // Setzstufe 2 Reihen glattkant (14 cm)
      final stuecke = treppenstuecke(
        const Treppe(),
        belag: genutet,
        setzstufe: glatt,
      );
      expect(_laengen(stuecke, genutet.nummer), List.filled(4, 1000));
      expect(_laengen(stuecke, glatt.nummer), List.filled(4, 1000));
      expect(
        treppenstuecke(
          const Treppe(),
          belag: genutet,
          setzstufe: Artikel(
            nummer: const Artikelnummer('x'),
            titel: 'ohne Maße',
            art: Artikelart.verblendung,
            einheit: Verkaufseinheit(Mengeneinheit.stueck),
          ),
        ),
        isEmpty,
      );
      final bedarf = treppenbedarf(_f39, belag: genutet, regelwerk: regelwerk);
      expect(
        {for (final b in bedarf.bedarf) b.einheiten.single},
        {genutet, glatt},
      );
      final ohneRegelwerk = treppenbedarf(_f39, belag: genutet);
      expect(
        {for (final b in ohneRegelwerk.bedarf) b.einheiten.single},
        {genutet},
      );
      // über den ganzen Anschluss
      expect({
        for (final b in anschlussbedarf(
          _f39,
          hoehen: const [_mm86, _mm86, _mm86, _mm86],
          belag: genutet,
          regelwerk: regelwerk,
        ).bedarf)
          b.einheiten.single,
      }, containsAll([genutet, glatt]));
    });
  });
}

const _mm86 = Millimeter(86);
