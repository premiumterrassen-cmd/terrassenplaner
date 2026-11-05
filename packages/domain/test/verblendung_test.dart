import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

Artikel _diele(
  String nummer, {
  int breite = 60,
  int? staerke = 21,
  List<int> laengen = const [5000],
}) => Artikel(
  nummer: Artikelnummer(nummer),
  titel: 'Diele $nummer',
  art: Artikelart.diele,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: Millimeter(breite),
    staerke: staerke == null ? null : Millimeter(staerke),
    laengen: [for (final l in laengen) Millimeter(l)],
  ),
  holzart: robinie,
  serie: basic,
);

final _belag = _diele('10-10-073');
final _blende = _diele('10-10-044', breite: 80, laengen: [4000, 5000, 6000]);
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

Regelwerk _regelwerk(Artikel belag, [List<Artikel> blenden = const []]) =>
    Regelwerk(
      Artikeldatei(
        quelle: 'test',
        version: '1',
        eintraege: [
          Artikeleintrag(
            artikel: belag,
            verweise: {
              Beziehung.verblendung.spalte: [for (final b in blenden) b.nummer],
            },
          ),
          for (final b in blenden) Artikeleintrag(artikel: b),
        ],
      ),
    );

const _vier = [Millimeter(86), Millimeter(86), Millimeter(86), Millimeter(86)];

/// F37: A — B an Bauelement, B — C, C — D und D — A verblendet.
final _f37 = Planungsstand.start
    .mitAngrenzend(0, an: true)
    .mitVerblendet(1, an: true)
    .mitVerblendet(2, an: true)
    .mitVerblendet(3, an: true);

int _anzahl(Anschlussbedarf b, Artikel a, int laenge) => b.bedarf
    .where((m) => m.einheiten.single == a && m.laenge?.mm == laenge)
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
        [1, 2, 3, 4, 5],
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

  group('Verblendungsbedarf (M7-02)', () {
    final ukStuecke = List.filled(13, const Millimeter(3090));

    test('F37: 2 × 4000 + 1 × 5000 mm Verblendung, 31 Blendenhalter à '
        '8,6 cm aus den Resten der UK, Unterlüftung', () {
      final b = verblendungsbedarf(
        _f37,
        hoehen: _vier,
        belag: _belag,
        regelwerk: _regelwerk(_belag, [_blende]),
        uk: _uk,
        ukAbstand: const Millimeter(400),
        ukStuecke: ukStuecke,
      );
      expect(_anzahl(b, _blende, 4000), 2);
      expect(_anzahl(b, _blende, 5000), 1);
      expect(
        b.bedarf.every((m) => m.zusatz == Materialzusatz.verblendung),
        isTrue,
      );
      expect(b.stuecke, hasLength(31));
      expect(b.stuecke.first.laenge, const Millimeter(86));
      expect(b.stuecke.first.nummer, _uk.nummer);
      expect(b.stuecke.first.titel, _uk.titel);
      expect(b.stuecke.first.ganzeLaenge, const Millimeter(6000));
      expect(b.meldungen, [Anschlussmeldung.unterlueftung]);
      expect(b.bedarf.clear, throwsUnsupportedError);
      expect(b.stuecke.clear, throwsUnsupportedError);
      expect(b.meldungen.clear, throwsUnsupportedError);
      // Volumen der Verblendung wie F37 → F36: 13 m × 80 × 21 mm
      expect(holzvolumen(b.bedarf), closeTo(13 * 0.08 * 0.021, 1e-9));
      // ohne Reste der UK-Verlegung: eigene Hölzer
      final ohne = verblendungsbedarf(
        _f37,
        hoehen: _vier,
        belag: _belag,
        regelwerk: _regelwerk(_belag, [_blende]),
        uk: _uk,
        ukAbstand: const Millimeter(400),
      );
      expect(_anzahl(ohne, _uk, 4000), 1);
    });

    test('eine Seite: keine Unterlüftungs-Warnung, höhere Ecke zählt, '
        'Reihen nach Blendenhöhe', () {
      final stand = Planungsstand.start.mitVerblendet(1, an: true);
      final b = verblendungsbedarf(
        stand,
        hoehen: const [
          Millimeter(86),
          Millimeter(86),
          Millimeter(200),
          Millimeter(86),
        ],
        belag: _belag,
        regelwerk: _regelwerk(_belag, [_blende]),
        uk: _uk,
        ukAbstand: const Millimeter(400),
      );
      // 200 − 21 = 179 mm → 3 Reihen à 309 cm
      expect(_anzahl(b, _blende, 4000), 3);
      expect(b.meldungen, isEmpty);
      // 9 Halter à 20 cm
      expect(b.stuecke, hasLength(9));
      expect(b.stuecke.first.laenge, const Millimeter(200));
      // genau eine Reihe bei Blendenhöhe = Dielenbreite
      final eine = verblendungsbedarf(
        stand,
        hoehen: const [
          Millimeter(101),
          Millimeter(101),
          Millimeter(101),
          Millimeter(101),
        ],
        belag: _belag,
        regelwerk: _regelwerk(_belag, [_blende]),
      );
      expect(_anzahl(eine, _blende, 4000), 1);
      expect(eine.stuecke, isEmpty, reason: 'ohne UK keine Halter');
    });

    test('Kreis: Umfang, Halter ohne Endstück', () {
      final kreis = Planungsstand.start
          .mitForm(Terrassenform.kreis)
          .mitVerblendet(0, an: true);
      final b = verblendungsbedarf(
        kreis,
        hoehen: const [Millimeter(86)],
        belag: _belag,
        regelwerk: _regelwerk(_belag, [_blende]),
        uk: _uk,
        ukAbstand: const Millimeter(400),
      );
      // Umfang 2π · 180 cm = 1131 cm → 6000 + 6000 mm (lange Reihe)
      expect(_anzahl(b, _blende, 6000), 2);
      expect(b.stuecke, hasLength(29));
      expect(b.meldungen, [Anschlussmeldung.unterlueftung]);
      expect(
        blendenstrecken(kreis.mitVerblendet(0, an: false), const [
          Millimeter(86),
        ]),
        isEmpty,
      );
    });

    test('Meldungen: zu dick, ohne Höhenunterschied, ohne Artikel; ohne '
        'Belag oder Stärke nur Unterlüftung', () {
      final dick = _diele('10-10-200', staerke: 25);
      final b = verblendungsbedarf(
        _f37,
        hoehen: _vier,
        belag: dick,
        regelwerk: _regelwerk(dick, [_blende]),
      );
      expect(b.meldungen, [
        Anschlussmeldung.unterlueftung,
        Anschlussmeldung.belagstaerke,
      ]);
      expect(b.bedarf, isEmpty);
      final duenn = _diele('10-10-201', staerke: 18);
      expect(verblendungMoeglich(duenn), isFalse);
      expect(verblendungMoeglich(_diele('a', staerke: 19)), isTrue);
      expect(verblendungMoeglich(_diele('a', staerke: 23)), isTrue);
      expect(verblendungMoeglich(_diele('a', staerke: 24)), isFalse);
      expect(verblendungMoeglich(_diele('a', staerke: null)), isFalse);
      final flach = verblendungsbedarf(
        Planungsstand.start.mitVerblendet(1, an: true),
        hoehen: const [
          Millimeter(21),
          Millimeter(21),
          Millimeter(21),
          Millimeter(21),
        ],
        belag: _belag,
        regelwerk: _regelwerk(_belag),
        uk: _uk,
        ukAbstand: const Millimeter(400),
      );
      expect(flach.meldungen, [
        Anschlussmeldung.keinHoehenunterschied,
        Anschlussmeldung.ohneVerblendungsartikel,
      ]);
      expect(flach.bedarf, isEmpty);
      expect(flach.stuecke, isEmpty);
      // Regelwerk ohne den Belag: kein Artikel
      expect(
        verblendungsbedarf(
          Planungsstand.start.mitVerblendet(1, an: true),
          hoehen: _vier,
          belag: _belag,
          regelwerk: _regelwerk(_blende),
        ).meldungen,
        [Anschlussmeldung.ohneVerblendungsartikel],
      );
      expect(verblendungsbedarf(_f37, hoehen: _vier).meldungen, [
        Anschlussmeldung.unterlueftung,
      ]);
      expect(
        verblendungsbedarf(
          _f37,
          hoehen: _vier,
          belag: _diele('x', staerke: null),
        ).meldungen,
        [Anschlussmeldung.unterlueftung],
      );
      expect(
        verblendungsbedarf(
          Planungsstand.start,
          hoehen: _vier,
          belag: _belag,
        ).meldungen,
        isEmpty,
      );
    });

    test('Verblendungsartikel ohne Lieferlängen in lfm, ohne Breite eine '
        'Reihe', () {
      final ohneLaenge = Artikel(
        nummer: const Artikelnummer('20-10-001'),
        titel: 'Blende',
        art: Artikelart.verblendung,
        einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
      );
      final b = verblendungsbedarf(
        _f37,
        hoehen: const [
          Millimeter(300),
          Millimeter(300),
          Millimeter(300),
          Millimeter(300),
        ],
        belag: _belag,
        regelwerk: _regelwerk(_belag, [ohneLaenge]),
      );
      // 309 + 480 + 309 cm = 10,98 m → 11 lfm
      expect(b.bedarf.single.stueck, 11);
      expect(b.bedarf.single.laenge, isNull);
      expect(b.bedarf.single.zusatz, Materialzusatz.verblendung);
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
