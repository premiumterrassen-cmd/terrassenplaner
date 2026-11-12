import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

Artikel _diele(
  String nummer, {
  int? breite = 60,
  int? staerke = 21,
  Profil profil = Profil.genutet,
  Serie serie = basic,
}) => Artikel(
  nummer: Artikelnummer(nummer),
  titel: 'Diele $nummer',
  art: Artikelart.diele,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: breite == null ? null : Millimeter(breite),
    staerke: staerke == null ? null : Millimeter(staerke),
    laengen: const [Millimeter(4000), Millimeter(5000), Millimeter(6000)],
  ),
  holzart: robinie,
  serie: serie,
  profil: profil,
);

/// Glattkante Blende der Serie BASIC (Planungskern v6, 4a.1).
Artikel _blende(int breite, {int staerke = 21, Serie serie = basic}) => _diele(
  'blende-$breite-$staerke-${serie.name}',
  breite: breite,
  staerke: staerke,
  profil: Profil.glattkant,
  serie: serie,
);

Artikel _schraube(String nummer, int laenge) => Artikel(
  nummer: Artikelnummer(nummer),
  titel: 'Schraube $nummer',
  art: Artikelart.schraube,
  einheit: Verkaufseinheit(Mengeneinheit.stueck),
  abmessungen: Abmessungen(laengen: [Millimeter(laenge)]),
);

final _belag = _diele('10-10-073');
final _b60 = _blende(60);
final _b80 = _blende(80);
final _b100 = _blende(100);
final _schrauben = [
  _schraube('s50-100', 50),
  _schraube('s60-100', 60),
  _schraube('s50-250', 50),
];
final _uk = Artikel(
  nummer: const Artikelnummer('10-10-031'),
  titel: 'UK 40 x 60',
  art: Artikelart.unterkonstruktion,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: const Millimeter(40),
    staerke: const Millimeter(60),
    laengen: const [Millimeter(4000), Millimeter(5000), Millimeter(6000)],
  ),
  holzart: robinie,
  serie: basic,
);

/// Regelwerk mit dem [belag], den [blenden] (Befestigung: [schrauben])
/// und den Schrauben.
Regelwerk _regelwerk(
  Artikel belag, [
  List<Artikel> blenden = const [],
  List<Artikel> schrauben = const [],
]) => Regelwerk(
  Artikeldatei(
    quelle: 'test',
    version: '1',
    eintraege: [
      Artikeleintrag(artikel: belag),
      for (final b in blenden)
        Artikeleintrag(
          artikel: b,
          verweise: {
            Beziehung.befestigung.spalte: [for (final s in schrauben) s.nummer],
          },
        ),
      for (final s in schrauben) Artikeleintrag(artikel: s),
    ],
  ),
);

final _serie = _regelwerk(_belag, [_b100, _b60, _b80], _schrauben);

const _vier = [Millimeter(86), Millimeter(86), Millimeter(86), Millimeter(86)];

List<Millimeter> _ueberall(int mm) => List.filled(4, Millimeter(mm));

/// F37: A — B an Bauelement, B — C, C — D und D — A verblendet.
final _f37 = Planungsstand.start
    .mitAngrenzend(0, an: true)
    .mitVerblendet(1, an: true)
    .mitVerblendet(2, an: true)
    .mitVerblendet(3, an: true);

int _anzahl(Anschlussbedarf b, Artikel a, int laenge) => b.bedarf
    .where((m) => m.einheiten.first == a && m.laenge?.mm == laenge)
    .fold(0, (s, m) => s + m.stueck);

void main() {
  group('Verblendete Seiten im Planungsstand (M7-02)', () {
    const f01 = Planungsstand.start;

    test('setzen und lösen; eine Seite hat nur eine Rolle', () {
      final b = f01.mitAngrenzend(1, an: true).mitVerblendet(1, an: true);
      expect(b.anschluss.verblendet, [1]);
      expect(b.anschluss.angrenzend, isEmpty);
      expect(b.anschluss.verblendetAn(1), isTrue);
      expect(b.anschluss.verblendetAn(0), isFalse);
      final zurueck = b.mitAngrenzend(1, an: true);
      expect(zurueck.anschluss.verblendet, isEmpty);
      expect(zurueck.anschluss.angrenzend, [1]);
      // abwählen nimmt die andere Rolle nicht weg
      expect(zurueck.mitVerblendet(1, an: false).anschluss.angrenzend, [1]);
      expect(b.mitAngrenzend(1, an: false).anschluss.verblendet, [1]);
      expect(b.mitVerblendet(1, an: false), f01);
      expect(b.anschluss.leer, isFalse);
    });

    test('Gleichheit, Hash und Transportformat', () {
      final b = f01.mitVerblendet(2, an: true);
      final a = f01.mitAngrenzend(2, an: true);
      expect(b == a, isFalse);
      expect(b.anschluss.hashCode == a.anschluss.hashCode, isFalse);
      expect(b.anschluss, const Anschluss(verblendet: [2]));
      expect(Planungsstand.ausBytes(b.zuBytes()), b);
      expect(Planungsstand.ausBytes(_f37.zuBytes()), _f37);
    });

    test('nur Seiten des Grundrisses; Kreis: Seite 0 = Fläche verblenden', () {
      expect(() => f01.mitVerblendet(4, an: true), throwsRangeError);
      expect(() => f01.mitVerblendet(-1, an: true), throwsRangeError);
      final kreis = f01.mitForm(Terrassenform.kreis);
      expect(kreis.mitVerblendet(0, an: true).anschluss.verblendet, [0]);
      expect(() => kreis.mitVerblendet(1, an: true), throwsRangeError);
    });
  });

  group('Anschlussergebnis mit Verblendung (M7-02)', () {
    test('verblendete Seiten gelb nach den grauen, Meldungen', () {
      final e = anschlussergebnis(
        _f37,
        meldungen: const [Anschlussmeldung.unterlueftung],
      );
      expect(
        [for (final s in e.seiten) (s.seite, s.rolle)],
        [
          (0, Seitenrolle.bauelement),
          (1, Seitenrolle.verblendung),
          (2, Seitenrolle.verblendung),
          (3, Seitenrolle.verblendung),
        ],
      );
      expect(e.seiten[2].von, const Punkt(4800, 3090));
      expect(e.seiten[2].bis, const Punkt(0, 3090));
      expect(e.meldungen, [Anschlussmeldung.unterlueftung]);
      expect(e.meldungen.clear, throwsUnsupportedError);
      final zurueck = Berechnung.ausBytes(
        Berechnung(umriss: const [], flaeche: 0, anschluss: e).zuBytes(),
      ).anschluss;
      expect(zurueck.seiten, e.seiten);
      expect(zurueck.meldungen, e.meldungen);
      expect(anschlussergebnis(_f37).meldungen, isEmpty);
    });

    test('Kreis: ganzer Umriss gelb, sonst nichts', () {
      final kreis = Planungsstand.start.mitForm(Terrassenform.kreis);
      expect(anschlussergebnis(kreis).seiten, isEmpty);
      final verblendet = anschlussergebnis(kreis.mitVerblendet(0, an: true));
      final umriss = kreis.kontur.vieleck();
      expect(verblendet.seiten, hasLength(umriss.length));
      expect(verblendet.seiten.first.von, umriss.first);
      expect(verblendet.seiten.last.bis, umriss.first);
      expect(
        verblendet.seiten.every(
          (s) => s.seite == 0 && s.rolle == Seitenrolle.verblendung,
        ),
        isTrue,
      );
    });

    test('Meldung und Rolle aus dem Transportformat', () {
      expect(Seitenrolle.ausNummer(2), Seitenrolle.verblendung);
      for (final m in Anschlussmeldung.values) {
        expect(Anschlussmeldung.ausNummer(m.nummer), m);
      }
      expect(
        [for (final m in Anschlussmeldung.values) m.nummer],
        [1, 2, 5, 6, 7],
      );
      expect(() => Anschlussmeldung.ausNummer(0), throwsFormatException);
      final fbb = fb.Builder()..startTable(1);
      fbb.finish(fbb.endTable());
      expect(
        Anschlussergebnis.lies(
          fb.BufferContext.fromBytes(fbb.buffer),
          fb.BufferContext.fromBytes(fbb.buffer).derefObject(0),
        ).meldungen,
        isEmpty,
      );
    });
  });

  group('Seitenblende (M7-02, Planungskern v6, 4a)', () {
    final ukStuecke = List.filled(13, const Millimeter(3090));

    test('4a.1: Blenden = glattkante Dielen der Serie in der Belagstärke', () {
      final ohneBreite = _diele(
        'ohne-breite',
        breite: null,
        profil: Profil.glattkant,
      );
      final kandidaten = [
        _b80,
        _diele('genutet-80', breite: 80),
        _blende(80, staerke: 23),
        _blende(80, serie: ecoSelect),
        ohneBreite,
        _uk,
        _schrauben.first,
        _b60,
      ];
      expect(blendenZumBelag(_belag, kandidaten), [_b80, _b60]);
      expect(blendenZumBelag(_belag, const []), isEmpty);
    });

    test('4a.2–4a.4: Breite unter der Höhe, höchstens 100 mm, über 13 cm '
        'zwei à 60 mm, sonst Rückfrage', () {
      final blenden = [_b100, _blende(50), _blende(120), _b80, _b60];
      int? breite(int hoehe) {
        final reihen = blendenreihen(Millimeter(hoehe), blenden);
        return reihen?.single.abmessungen.breite!.mm;
      }

      expect(breite(86), 80);
      expect(breite(95), 80, reason: '90 mm gibt es nicht → 80');
      expect(breite(125), 100, reason: 'bei 12,5 cm 100 mm');
      expect(breite(130), 100);
      expect(breite(101), 100);
      expect(breite(100), 80, reason: 'steht nicht auf dem Boden auf');
      expect(breite(81), 80);
      expect(breite(80), 60);
      expect(breite(51), 50);
      expect(breite(50), isNull);
      expect(blendenreihen(const Millimeter(131), blenden), [_b60, _b60]);
      expect(blendenreihen(const Millimeter(400), [_b80, _b100]), isNull);
      expect(blendenreihen(const Millimeter(86), const []), isNull);
      expect(
        [blendeBreiteMax, blendeZweiReihenUeber, blendeZweiReihenBreite],
        const [Millimeter(100), Millimeter(130), Millimeter(60)],
      );
    });

    test('F37: 2 × 4000 + 1 × 5000 mm Blende 80 mm mit Gehrung, 31 Träger '
        'à 4,5 cm aus den Resten der UK, 62 Schrauben, Unterlüftung', () {
      final b = verblendungsbedarf(
        _f37,
        hoehen: _vier,
        belag: _belag,
        regelwerk: _serie,
        uk: _uk,
      );
      expect(_anzahl(b, _b80, 4000), 2);
      expect(_anzahl(b, _b80, 5000), 1);
      final blenden = b.bedarf.where((m) => m.laenge != null).toList();
      expect(blenden, hasLength(2));
      expect(
        blenden.every((m) => m.zusatz == Materialzusatz.verblendung),
        isTrue,
      );
      expect(b.stuecke, hasLength(31));
      // 86 − 20 − 21 mm
      expect(b.stuecke.first.laenge, const Millimeter(45));
      expect(b.stuecke.first.nummer, _uk.nummer);
      expect(b.stuecke.first.titel, _uk.titel);
      expect(b.stuecke.first.ganzeLaenge, const Millimeter(6000));
      // 2 Schrauben je Träger, alle Verpackungen der ersten Länge
      final schrauben = b.bedarf.last;
      expect(schrauben.stueck, 62);
      expect(schrauben.einheiten, [_schrauben[0], _schrauben[2]]);
      expect(schrauben.zusatz, isNull);
      expect(b.meldungen, [Anschlussmeldung.unterlueftung]);
      expect(b.bedarf.clear, throwsUnsupportedError);
      expect(b.stuecke.clear, throwsUnsupportedError);
      expect(b.meldungen.clear, throwsUnsupportedError);
      // Zuschnitte der Blende samt Gehrung für die Ölfläche (R-D10)
      expect(b.blenden, [
        (_b80, const Millimeter(3140)),
        (_b80, const Millimeter(4850)),
        (_b80, const Millimeter(3140)),
      ]);
      expect(b.blenden.clear, throwsUnsupportedError);
      // Volumen der Blenden: 13 m × 80 × 21 mm
      expect(holzvolumen(b.bedarf), closeTo(13 * 0.08 * 0.021, 1e-9));
      // zusammen (anschlussbedarf): aus den Resten der UK-Verlegung keine
      // weitere UK, ohne Reste eigene Hölzer
      Anschlussbedarf alles([List<Millimeter> reste = const []]) =>
          anschlussbedarf(
            _f37,
            hoehen: _vier,
            belag: _belag,
            regelwerk: _serie,
            uk: _uk,
            ukAbstand: const Millimeter(400),
            ukStuecke: reste,
          );
      expect(_anzahl(alles(ukStuecke), _uk, 4000), 0);
      expect(alles(ukStuecke).stuecke, hasLength(31));
      expect(_anzahl(alles(), _uk, 4000), 1);
      // feste UK-Länge 5000 mm
      expect(
        _anzahl(
          anschlussbedarf(
            _f37.mitUkLaenge(const Millimeter(5000)),
            hoehen: _vier,
            belag: _belag,
            regelwerk: _serie,
            uk: _uk,
            ukAbstand: const Millimeter(400),
          ),
          _uk,
          5000,
        ),
        1,
      );
      // ohne UK-Verlegung (kein Achsabstand) keine Träger, keine Schrauben
      final ohneVerlegung = anschlussbedarf(
        _f37,
        hoehen: _vier,
        belag: _belag,
        regelwerk: _serie,
        uk: _uk,
      );
      expect(ohneVerlegung.stuecke, isEmpty);
      expect(ohneVerlegung.bedarf, hasLength(2));
    });

    test('eine Seite: niedrigere Ecke zählt, über 13 cm zwei Reihen à '
        '60 mm, Träger höchstens 40 cm auseinander', () {
      final stand = Planungsstand.start.mitVerblendet(1, an: true);
      final b = verblendungsbedarf(
        stand,
        hoehen: const [
          Millimeter(300),
          Millimeter(86),
          Millimeter(200),
          Millimeter(300),
        ],
        belag: _belag,
        regelwerk: _serie,
        uk: _uk,
      );
      // B — C: 86 mm → eine Reihe 80 mm, 309 + 5 cm → 4000 mm
      expect(_anzahl(b, _b80, 4000), 1);
      expect(b.meldungen, isEmpty);
      // 309 cm / 40 cm → 8 Felder, 9 Träger à 4,5 cm
      expect(b.stuecke, hasLength(9));
      expect(b.stuecke.first.laenge, const Millimeter(45));
      final hoch = verblendungsbedarf(
        stand,
        hoehen: _ueberall(200),
        belag: _belag,
        regelwerk: _serie,
        uk: _uk,
      );
      expect(_anzahl(hoch, _b60, 4000), 2);
      expect(_anzahl(hoch, _b80, 4000), 0);
      expect(hoch.stuecke.first.laenge, const Millimeter(159));
      // genau 800 mm: zwei Felder, drei Träger
      final kurz = Planungsstand.start
          .mitGrundriss(
            RechteckGrundriss(const Millimeter(800), const Millimeter(800)),
          )
          .mitVerblendet(1, an: true);
      expect(
        verblendungsbedarf(
          kurz,
          hoehen: _vier,
          belag: _belag,
          regelwerk: _serie,
          uk: _uk,
        ).stuecke,
        hasLength(3),
      );
      expect(
        [blendentraegerAbstandMax, blendentraegerBodenabstand],
        const [Millimeter(400), Millimeter(20)],
      );
      expect(blendentraegerSchrauben, 2);
      expect(blendeGehrungszugabe, const Millimeter(50));
    });

    test('4a.5: Gehrung +5 cm je Kante – 395 cm passen nicht mehr in '
        '4000 mm', () {
      final stand = Planungsstand.start
          .mitGrundriss(
            RechteckGrundriss(const Millimeter(3960), const Millimeter(3000)),
          )
          .mitVerblendet(0, an: true);
      final b = verblendungsbedarf(
        stand,
        hoehen: _vier,
        belag: _belag,
        regelwerk: _serie,
      );
      expect(_anzahl(b, _b80, 4000), 0);
      expect(_anzahl(b, _b80, 5000), 1);
      expect(b.stuecke, isEmpty, reason: 'ohne UK keine Träger');
      expect(b.bedarf, hasLength(1), reason: 'ohne Träger keine Schrauben');
    });

    test('Kreis: Umfang ohne Gehrung, Träger ohne Endstück, kleinste '
        'Höhe', () {
      final kreis = Planungsstand.start
          .mitForm(Terrassenform.kreis)
          .mitVerblendet(0, an: true);
      final b = verblendungsbedarf(
        kreis,
        hoehen: const [Millimeter(86)],
        belag: _belag,
        regelwerk: _serie,
        uk: _uk,
      );
      // Umfang 2π · 180 cm = 1131 cm → 6000 + 6000 mm (lange Reihe)
      expect(_anzahl(b, _b80, 6000), 2);
      expect(b.stuecke, hasLength(29));
      expect(b.meldungen, [Anschlussmeldung.unterlueftung]);
      expect(blendenstrecken(kreis, const [Millimeter(200), Millimeter(86)]), [
        (laenge: kreis.kontur.umfang, hoehe: const Millimeter(86)),
      ]);
      expect(
        blendenstrecken(kreis.mitVerblendet(0, an: false), const [
          Millimeter(86),
        ]),
        isEmpty,
      );
    });

    test('Meldungen: Rückfrage ohne passende Blende, ohne Höhenunterschied; '
        'ohne Belag nur Unterlüftung', () {
      final seite = Planungsstand.start.mitVerblendet(1, an: true);
      // Serie ohne glattkante Blende in der Stärke (z. B. 26 mm genutet)
      final dick = _diele('10-10-200', staerke: 26);
      final b = verblendungsbedarf(
        _f37,
        hoehen: _vier,
        belag: dick,
        regelwerk: _regelwerk(dick, [_b80], _schrauben),
        uk: _uk,
      );
      expect(b.meldungen, [
        Anschlussmeldung.unterlueftung,
        Anschlussmeldung.blendeFehlt,
      ]);
      expect(b.bedarf, isEmpty);
      expect(b.stuecke, isEmpty);
      // nur 80 mm, Höhe 70 mm: keine Breite darunter
      expect(
        verblendungsbedarf(
          seite,
          hoehen: _ueberall(70),
          belag: _belag,
          regelwerk: _regelwerk(_belag, [_b80]),
        ).meldungen,
        [Anschlussmeldung.blendeFehlt],
      );
      // eine Seite passt, eine nicht: Material nur für die passende
      final gemischt = verblendungsbedarf(
        seite.mitVerblendet(2, an: true),
        hoehen: const [
          Millimeter(86),
          Millimeter(86),
          Millimeter(86),
          Millimeter(70),
        ],
        belag: _belag,
        regelwerk: _regelwerk(_belag, [_b80]),
        uk: _uk,
      );
      expect(gemischt.meldungen, [Anschlussmeldung.blendeFehlt]);
      expect(_anzahl(gemischt, _b80, 4000), 1);
      expect(gemischt.stuecke, hasLength(9));
      // ohne Schraube an der Blende keine Schrauben
      expect(gemischt.bedarf, hasLength(1));
      final flach = verblendungsbedarf(
        seite,
        hoehen: _ueberall(21),
        belag: _belag,
        regelwerk: _serie,
        uk: _uk,
      );
      expect(flach.meldungen, [Anschlussmeldung.keinHoehenunterschied]);
      expect(flach.bedarf, isEmpty);
      expect(flach.stuecke, isEmpty);
      // ohne Regelwerk und ohne Stärke: Rückfrage
      expect(
        verblendungsbedarf(seite, hoehen: _vier, belag: _belag).meldungen,
        [Anschlussmeldung.blendeFehlt],
      );
      expect(
        verblendungsbedarf(
          seite,
          hoehen: _vier,
          belag: _diele('x', staerke: null),
          regelwerk: _serie,
        ).meldungen,
        [Anschlussmeldung.blendeFehlt],
      );
      expect(verblendungsbedarf(_f37, hoehen: _vier).meldungen, [
        Anschlussmeldung.unterlueftung,
      ]);
      expect(
        verblendungsbedarf(
          Planungsstand.start,
          hoehen: _vier,
          belag: _belag,
          regelwerk: _serie,
        ).meldungen,
        isEmpty,
      );
    });

    test('Unterlüftung: nur wenn alle freien Seiten verblendet sind', () {
      expect(ohneUnterlueftung(Planungsstand.start), isFalse);
      expect(
        ohneUnterlueftung(Planungsstand.start.mitVerblendet(1, an: true)),
        isFalse,
      );
      expect(ohneUnterlueftung(_f37), isTrue);
      expect(ohneUnterlueftung(_f37.mitAngrenzend(2, an: true)), isTrue);
      expect(ohneUnterlueftung(_f37.mitVerblendet(3, an: false)), isFalse);
    });

    test('zusätzliche Lieferstücke: zuerst in die Reste, feste UK-Länge', () {
      const laengen = [Millimeter(4000), Millimeter(5000)];
      expect(
        zusaetzlicheLieferstuecke(
          List.filled(31, const Millimeter(86)),
          List.filled(13, const Millimeter(3090)),
          laengen,
        ),
        isEmpty,
      );
      // Reste zu klein: neue Hölzer; kurze vorhandene Stücke haben keine Reste
      expect(
        zusaetzlicheLieferstuecke(
          const [Millimeter(950), Millimeter(500)],
          const [Millimeter(3090), Millimeter(1000), Millimeter(4500)],
          laengen,
        ),
        {const Millimeter(4000): 1},
      );
      // ein Rest nimmt mehrere Stücke, bis er verbraucht ist: 910 mm für
      // 400 + 400, die 300 mm bekommen ein neues Holz
      expect(
        zusaetzlicheLieferstuecke(
          const [Millimeter(400), Millimeter(400), Millimeter(300)],
          const [Millimeter(3090)],
          laengen,
        ),
        {const Millimeter(4000): 1},
      );
      // Rest genau so groß wie das Stück
      expect(
        zusaetzlicheLieferstuecke(
          const [Millimeter(910)],
          const [Millimeter(3090)],
          laengen,
        ),
        isEmpty,
      );
      // feste Länge 5000: Rest 1910 nimmt beide
      expect(
        zusaetzlicheLieferstuecke(
          const [Millimeter(950), Millimeter(950)],
          const [Millimeter(3090)],
          laengen,
          fest: const Millimeter(5000),
        ),
        isEmpty,
      );
      expect(
        zusaetzlicheLieferstuecke(const [Millimeter(10)], const [], const []),
        isEmpty,
      );
      expect(
        zusaetzlicheLieferstuecke(
          const [Millimeter(10)],
          const [Millimeter(1990)],
          laengen,
        ),
        {const Millimeter(4000): 1},
        reason: 'unter der halben kürzesten Länge kein eigenes Holz',
      );
      expect(
        zusaetzlicheLieferstuecke(
          const [Millimeter(10)],
          const [Millimeter(2000)],
          laengen,
        ),
        isEmpty,
      );
    });
  });
}
