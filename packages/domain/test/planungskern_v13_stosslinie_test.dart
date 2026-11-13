// Planungsregeln Alexander (Planungskern v13, 13.11.2026), Regel 15:
// Vorgabe „Stoßlinie durch Eckpunkt“ (R-B20).
import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

const _m4 = Millimeter(4000);
const _m5 = Millimeter(5000);
const _m6 = Millimeter(6000);

Artikel _artikel(Artikelart art, {List<Millimeter>? laengen}) => Artikel(
  nummer: Artikelnummer('10-10-${art.index}'),
  titel: 'Artikel ${art.name}',
  art: art,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: Millimeter(art == Artikelart.holzfliese ? 606 : 140),
    staerke: const Millimeter(21),
    laengen:
        laengen ??
        (art == Artikelart.holzfliese
            ? const [Millimeter(606)]
            : const [_m4, _m5, _m6]),
  ),
  holzart: art.istHolz ? robinie : null,
  serie: art.istHolz ? basic : null,
  profil: art.istHolz ? Profil.genutet : null,
);

final _diele = _artikel(Artikelart.diele);

/// L-Form: A (0|0), B (lang|0), C (lang|1000), D (innen|1000),
/// E (innen|2000), F (0|2000) – D ist die Innenecke.
Planungsstand _l(int lang, int innen) => Planungsstand(
  grundriss: FreiformGrundriss([
    const Punkt(0, 0),
    Punkt(lang.toDouble(), 0),
    Punkt(lang.toDouble(), 1000),
    Punkt(innen.toDouble(), 1000),
    Punkt(innen.toDouble(), 2000),
    const Punkt(0, 2000),
  ], geschlossen: true),
);

const _d = 3;

/// Längen je Reihe (Reihe → Stücke in Verlegereihenfolge) einer Teilfläche.
Map<int, List<int>> _reihen(Teilverlegung t) {
  final ergebnis = <int, List<int>>{};
  for (final s in t.stuecke) {
    (ergebnis[s.reihe] ??= []).add(s.laenge.mm);
  }
  return ergebnis;
}

void main() {
  group('festeStosslinien (Regel 15.1–15.3)', () {
    ({List<Millimeter> fest, List<Millimeter> zusatz}) linien(
      Kontur k,
      List<Punkt> punkte, {
      double winkel = 0,
      Punkt ab = Punkt.ursprung,
    }) => festeStosslinien(
      k,
      winkel: winkel,
      ausgangspunkt: ab,
      punkte: punkte,
      hoechstlaenge: const Millimeter(6030),
    );

    test('Linie genau durch die Ecke, quer zu den Dielen', () {
      final k = _l(9000, 4000).kontur;
      final r = linien(k, const [Punkt(4000, 1000)]);
      expect(r.fest, const [Millimeter(4000)]);
      expect(r.zusatz, isEmpty);
      // vom Ausgangspunkt B aus gemessen (negativ in Verlegerichtung)
      expect(
        linien(k, const [Punkt(4000, 1000)], ab: const Punkt(9000, 0)).fest,
        const [Millimeter(-5000)],
      );
      // doppelte Punkte und mehrere Ecken: aufsteigend, einmal
      expect(
        linien(k, const [
          Punkt(6000, 0),
          Punkt(4000, 1000),
          Punkt(4000, 2000),
        ]).fest,
        const [Millimeter(4000), Millimeter(6000)],
      );
    });

    test('Ecke am Rand oder näher als 20 cm: keine Linie', () {
      final k = _l(9000, 4000).kontur;
      expect(linien(k, const [Punkt(9000, 0)]).fest, isEmpty);
      expect(linien(k, const [Punkt(0, 2000)]).fest, isEmpty);
      expect(linien(k, const [Punkt(200, 0)]).fest, isEmpty);
      expect(linien(k, const [Punkt(201, 0)]).fest, const [Millimeter(201)]);
      expect(linien(k, const [Punkt(8800, 0)]).fest, isEmpty);
      expect(linien(k, const [Punkt(8799, 0)]).fest, const [Millimeter(8799)]);
    });

    test('Fläche passt in eine Diele: keine Linie', () {
      final k = Kontur.rechteck(6030, 1000);
      expect(linien(k, const [Punkt(3000, 0)]).fest, isEmpty);
      expect(
        linien(Kontur.rechteck(6031, 1000), const [Punkt(3000, 0)]).fest,
        const [Millimeter(3000)],
      );
    });

    test('zu lange Stücke: gleichmäßig verteilte zusätzliche Stöße', () {
      final k = _l(16000, 2000).kontur;
      final r = linien(k, const [Punkt(2000, 1000)]);
      expect(r.fest, const [Millimeter(2000)]);
      expect(r.zusatz, const [Millimeter(6667), Millimeter(11333)]);
      // Stück von genau der Höchstlänge: kein Zusatz
      final genau = linien(Kontur.rechteck(12060, 1000), const [
        Punkt(6030, 0),
      ]);
      expect(genau.zusatz, isEmpty);
      final knapp = linien(Kontur.rechteck(12061, 1000), const [
        Punkt(6030, 0),
      ]);
      expect(knapp.zusatz, const [Millimeter(9046)]);
      // auch vor der ersten Linie
      expect(
        linien(Kontur.rechteck(12061, 1000), const [Punkt(11800, 0)]).zusatz,
        const [Millimeter(5900)],
      );
    });

    test('senkrecht verlegt: Lage längs y', () {
      final k = Kontur.rechteck(1000, 9000);
      expect(linien(k, const [Punkt(1000, 4000)], winkel: 90).fest, const [
        Millimeter(4000),
      ]);
    });
  });

  group('verlegeDielen mit festen Stoßlinien', () {
    List<Dielenstueck> verlege(
      Kontur k, {
      List<Millimeter> linien = const [],
      bool verbinden = false,
    }) => verlegeDielen(
      k,
      winkel: 0,
      ausgangspunkt: Punkt.ursprung,
      dielenbreite: const Millimeter(994),
      verlegeart: Verlegeart.fugenschnitt,
      laengste: _m6,
      ueberlaenge: const Millimeter(30),
      verbinden: verbinden,
      stosslinien: linien,
    );

    test('nur Reihen über einer Diele werden gestoßen (15.2)', () {
      final k = _l(9000, 4000).kontur;
      final mit = verlege(k, linien: const [Millimeter(4000)]);
      expect(
        [for (final s in mit) (s.reihe, s.laenge.mm)],
        [(0, 4000), (0, 5000), (1, 4000)],
      );
      // ohne Linien wie bisher (Raster ab A)
      expect([for (final s in verlege(k)) s.laenge.mm], [6000, 3000, 4000]);
    });

    test('kurze Stücke nicht über eine feste Linie verbunden', () {
      final k = _l(9000, 1000).kontur;
      final linien = [const Millimeter(1000), const Millimeter(5000)];
      expect(
        [
          for (final s in verlege(k, linien: linien, verbinden: true))
            s.laenge.mm,
        ],
        [1000, 4000, 4000, 1000],
      );
      // zum Vergleich ohne Vorgabe: verbunden
      expect(
        [for (final s in verlege(k, verbinden: true)) s.laenge.mm],
        [6000, 3000, 1000],
      );
    });
  });

  group('verlegeBelag mit der Vorgabe (Regel 15)', () {
    test('Stoß an der Innenecke D, kürzere Reihen ohne Stoß', () {
      final stand = _l(9000, 4000).mitStosslinie(const [_d]);
      final v = verlegeBelag(stand, _diele)!;
      final reihen = _reihen(v.teile.single);
      expect(v.festeStoesse, 1);
      expect(v.zusatzstoesse, 0);
      for (final MapEntry(key: reihe, value: laengen) in reihen.entries) {
        expect(laengen, reihe < 7 ? [4000, 5000] : [4000], reason: '$reihe');
      }
      expect(belagmeldungen(stand, _diele, v), isEmpty);
    });

    test('ohne Vorgabe unverändert (Parität)', () {
      final ohne = _l(9000, 4000);
      final mitLeer = ohne.mitStosslinie(const []);
      expect(mitLeer, ohne);
      expect(mitLeer.zuBytes(), ohne.zuBytes());
      final a = verlegeBelag(ohne, _diele)!;
      final b = verlegeBelag(mitLeer, _diele)!;
      expect(
        [for (final s in b.teile.single.stuecke) s.laenge.mm],
        [for (final s in a.teile.single.stuecke) s.laenge.mm],
      );
      expect(a.festeStoesse, 0);
    });

    test('Zusatzstöße mit Meldung (15.3) und doppelter UK', () {
      final stand = _l(16000, 2000).mitStosslinie(const [_d]);
      final v = verlegeBelag(stand, _diele)!;
      expect(v.festeStoesse, 1);
      expect(v.zusatzstoesse, 2);
      expect(_reihen(v.teile.single)[0], [2000, 4667, 4666, 4667]);
      expect(belagmeldungen(stand, _diele, v), [
        Belagmeldung.stosslinieZusatzstoesse,
      ]);
      final uk = ukVerlegung(
        stand,
        _artikel(Artikelart.unterkonstruktion),
        abstand: const Millimeter(500),
        dielen: v.teile.single.stuecke,
      );
      final xs = {for (final l in uk.linien) l.x.round()}.toList()..sort();
      // je Stoß zwei Hölzer: links und rechts der Linie
      for (final stoss in const [2000, 6667, 11333]) {
        expect(xs.where((x) => (x - stoss).abs() < 60), hasLength(2));
      }
    });

    test('Ecke am Rand: ohne Wirkung mit Meldung', () {
      final stand = _l(9000, 4000).mitStosslinie(const [1]);
      final v = verlegeBelag(stand, _diele)!;
      expect(v.festeStoesse, 0);
      expect(belagmeldungen(stand, _diele, v), [
        Belagmeldung.stosslinieOhneWirkung,
      ]);
    });

    test('Verband, MASSIV und Holzfliesen: feste Linie gilt nicht (15.4)', () {
      final stand = _l(9000, 4000).mitStosslinie(const [_d]);
      for (final art in [
        Verlegeart.halbverband,
        Verlegeart.drittelverband,
        Verlegeart.viertelverband,
        Verlegeart.wechselverband,
      ]) {
        final s = stand.mitVerlegeart(art);
        final v = verlegeBelag(s, _diele)!;
        expect(v.festeStoesse, 0);
        expect(
          [for (final t in v.teile.single.stuecke) t.laenge.mm],
          [
            for (final t in verlegeBelag(
              s.mitStosslinie(const []),
              _diele,
            )!.teile.single.stuecke)
              t.laenge.mm,
          ],
        );
        expect(belagmeldungen(s, _diele, v), [
          Belagmeldung.stosslinieNichtImMuster,
        ]);
      }
      final massiv = _artikel(Artikelart.systemdiele);
      expect(belagmeldungen(stand, massiv, null), [
        Belagmeldung.systemdieleOhneVerlegung,
        Belagmeldung.stosslinieNichtImMuster,
      ]);
      final fliese = _artikel(Artikelart.holzfliese);
      final vf = verlegeBelag(stand, fliese)!;
      expect(vf.festeStoesse, 0);
      expect(
        belagmeldungen(stand, fliese, vf),
        contains(Belagmeldung.stosslinieNichtImMuster),
      );
      // ohne Vorgabe keine dieser Meldungen
      expect(belagmeldungen(stand.mitStosslinie(const []), massiv, null), [
        Belagmeldung.systemdieleOhneVerlegung,
      ]);
    });

    test('Teilflächen: jede mit der Ecke oder nur die gewählte', () {
      final a1 = Ausschnitt(
        bezeichnung: 'A1',
        x: const Millimeter(1000),
        y: const Millimeter(0),
        laenge: const Millimeter(8000),
        breite: const Millimeter(1000),
        funktion: Ausschnittfunktion.andererBelag,
      );
      final leer = Ausschnitt(
        bezeichnung: 'A2',
        x: const Millimeter(500),
        y: const Millimeter(1200),
        laenge: const Millimeter(500),
        breite: const Millimeter(500),
      );
      final grund = _l(16000, 2000)
          .mitNeuemAusschnitt()
          .mitAusschnitt(0, leer)
          .mitNeuemAusschnitt()
          .mitAusschnitt(1, a1);
      List<(int, int)> stoesse(int? flaeche) {
        final v = verlegeBelag(
          grund.mitStosslinie(const [_d], flaeche: flaeche),
          _diele,
        )!;
        return [for (final t in v.teile) (t.festeStoesse, t.zusatzstoesse)];
      }

      // Hauptfläche: Linie bei 2000, Zusatz bei 6667 und 11333; A1 (1000 bis
      // 9000): Linie bei 2000, Zusatz bei 5500
      expect(stoesse(null), [(1, 2), (1, 1)]);
      expect(stoesse(0), [(1, 2), (0, 0)]);
      expect(stoesse(2), [(0, 0), (1, 1)]);
      // A2 ist leer: keine Teilfläche
      expect(stoesse(1), [(0, 0), (0, 0)]);
      // Ecke nicht am Umriss von A1: dort keine Linie
      final ohneA1 = verlegeBelag(grund.mitStosslinie(const [4]), _diele)!;
      expect([for (final t in ohneA1.teile) t.festeStoesse], [1, 0]);
      final teil = verlegeBelag(
        grund.mitStosslinie(const [_d], flaeche: 2),
        _diele,
      )!.teile[1];
      expect(_reihen(teil)[0], [1000, 3500, 3500]);
    });
  });

  group('Planungsstand (Plätze 143/144)', () {
    test('Eingabe, Reihenfolge, Prüfung', () {
      final stand = _l(9000, 4000);
      expect(stand.stossecken, isEmpty);
      expect(stand.stossflaeche, isNull);
      final mit = stand.mitStosslinie(const [3, 1, 3]);
      expect(mit.stossecken, [1, 3]);
      expect(mit.stosspunkte, const [Punkt(9000, 0), Punkt(4000, 1000)]);
      expect(() => mit.stossecken.add(0), throwsUnsupportedError);
      expect(mit == stand, isFalse);
      expect(mit.hashCode == stand.hashCode, isFalse);
      expect(mit, stand.mitStosslinie(const [1, 3]));
      expect(mit == stand.mitStosslinie(const [1, 2]), isFalse);
      expect(mit == stand.mitStosslinie(const [1, 3], flaeche: 0), isFalse);
      expect(() => stand.mitStosslinie(const [6]), throwsRangeError);
      expect(() => stand.mitStosslinie(const [-1]), throwsRangeError);
      expect(
        () => stand.mitStosslinie(const [0], flaeche: 1),
        throwsRangeError,
      );
      expect(
        () => stand.mitStosslinie(const [0], flaeche: -1),
        throwsRangeError,
      );
      final mitA = stand.mitNeuemAusschnitt().mitStosslinie(const [
        0,
      ], flaeche: 1);
      expect(mitA.stossflaeche, 1);
      // andere Ausschnitte: wieder alle Teilflächen; Ecken bleiben
      expect(mitA.ohneAusschnitt(0).stossflaeche, isNull);
      expect(mitA.ohneAusschnitt(0).stossecken, [0]);
      expect(mitA.mitBelag(const Artikelnummer('x')).stossflaeche, 1);
      // Kreis: nur A, der Anfang der Kontur
      final kreis = Planungsstand(
        grundriss: KreisGrundriss(const Millimeter(1500)),
      ).mitStosslinie(const [0]);
      expect(kreis.stosspunkte, [kreis.kontur.punkte.first]);
    });

    test('andere Eckenzahl: Vorgabe entfällt, gleiche bleibt', () {
      final mit = _l(9000, 4000).mitStosslinie(const [_d]);
      expect(mit.mitGrundriss(_l(9500, 4000).grundriss).stossecken, [_d]);
      expect(mit.mitGrundriss(RechteckGrundriss(_m4, _m5)).stossecken, isEmpty);
    });

    test('Transportformat', () {
      final mit = _l(
        9000,
        4000,
      ).mitNeuemAusschnitt().mitStosslinie(const [1, _d], flaeche: 0);
      final zurueck = Planungsstand.ausBytes(mit.zuBytes());
      expect(zurueck, mit);
      expect(zurueck.stossecken, [1, _d]);
      expect(zurueck.stossflaeche, 0);
      final ohne = Planungsstand.ausBytes(_l(9000, 4000).zuBytes());
      expect(ohne.stossecken, isEmpty);
      expect(ohne.stossflaeche, isNull);
      // unbekannte Ecke
      final fbb = fb.Builder();
      final masse = fbb.writeListInt32([2000, 3000]);
      fbb
        ..startTable(2)
        ..addUint8(0, Terrassenform.rechteck.nummer)
        ..addOffset(1, masse);
      final grundriss = fbb.endTable();
      final ecken = fbb.writeListUint16([4]);
      fbb
        ..startTable(144)
        ..addOffset(1, grundriss)
        ..addOffset(143, ecken);
      fbb.finish(fbb.endTable());
      expect(
        () => Planungsstand.ausBytes(Uint8List.fromList(fbb.buffer)),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'unbekannte Ecke der Stoßlinie 4',
          ),
        ),
      );
    });
  });

  test('Berechnung: zusätzliche Stöße im Transportformat (Platz 170)', () {
    final b = Berechnung(umriss: const [], flaeche: 0, zusatzstoesse: 2);
    expect(Berechnung.ausBytes(b.zuBytes()).zusatzstoesse, 2);
    expect(b.mitPlanung(0).zusatzstoesse, 2);
    expect(
      Berechnung.ausBytes(Berechnung(umriss: const [], flaeche: 0).zuBytes())
          .zusatzstoesse,
      0,
    );
  });

  test('Texte der Unterlagen', () {
    for (final (t, eins, zwei) in [
      (Unterlagentexte.deutsch, '1 zusätzliche', 'Stoß '),
      (Unterlagentexte.englisch, '1 evenly', 'joint '),
    ]) {
      final einer = t.belagmeldung(
        Belagmeldung.stosslinieZusatzstoesse,
        null,
        zusatzstoesse: 1,
      );
      expect(einer, contains(eins));
      expect(einer, contains(zwei));
      expect(
        t.belagmeldung(
          Belagmeldung.stosslinieZusatzstoesse,
          null,
          zusatzstoesse: 3,
        ),
        contains('3 '),
      );
      for (final m in [
        Belagmeldung.stosslinieNichtImMuster,
        Belagmeldung.stosslinieOhneWirkung,
      ]) {
        expect(t.belagmeldung(m, null), isNotEmpty);
      }
    }
  });
}
