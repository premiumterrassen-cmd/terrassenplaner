import 'dart:math' as math;

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

Flaeche _rechteck(double x, double y, double breite, double hoehe) =>
    Flaeche(Kontur.rechteck(breite, hoehe, Punkt(x, y)));

/// Terrasse 540 x 360 cm mit Ausschnitt 180 x 120 cm bei X 200 / Y 100
/// (Fachkonzept 1.4) in mm.
final _terrasse = _rechteck(0, 0, 5400, 3600);
final _ausschnitt = _rechteck(2000, 1000, 1800, 1200);

List<double> _flaechen(List<Flaeche> f) =>
    [for (final x in f) x.flaeche]..sort();

void main() {
  group('Fläche mit Loch', () {
    final f = Flaeche(_terrasse.kontur, [_ausschnitt.kontur]);

    test('Fläche, Umfang, Huellrechteck', () {
      expect(f.flaeche, 19440000 - 2160000);
      expect(f.umfang, 18000 + 6000);
      expect(f.huellrechteck.max, const Punkt(5400, 3600));
      expect(f.loecher, hasLength(1));
      expect(gesamtflaeche([f, _ausschnitt]), 19440000);
      expect(gesamtflaeche([]), 0);
    });

    test('Punkte im Loch gehören nicht dazu', () {
      expect(f.enthaelt(const Punkt(100, 100)), isTrue);
      expect(f.enthaelt(const Punkt(2500, 1500)), isFalse);
      expect(f.enthaelt(const Punkt(6000, 1500)), isFalse);
      expect(f.abstandZumRand(const Punkt(2500, 1500)), 500);
      expect(f.abstandZumRand(const Punkt(100, 200)), 100);
    });

    test('Verschieben und Drehen bewegen auch das Loch', () {
      final v = f.verschoben(const Punkt(100, 0));
      expect(v.loecher.single.punkte.first, const Punkt(2100, 1000));
      expect(v.kontur.punkte.first, const Punkt(100, 0));
      final d = f.gedreht(180, const Punkt(2700, 1800));
      expect(d.flaeche, closeTo(f.flaeche, 1e-3));
      expect(f.enthaelt(const Punkt(3600, 1100)), isFalse);
      expect(d.enthaelt(const Punkt(3600, 1100)), isTrue);
      expect(d.enthaelt(const Punkt(1700, 2500)), isFalse);
      expect(f.gedreht(90).kontur.punkte[1].y, closeTo(5400, 1e-9));
    });
  });

  group('Mengenoperationen', () {
    test('Ausschnitt wird zum Loch', () {
      final ohne = _terrasse.ohne(_ausschnitt);
      expect(ohne, hasLength(1));
      expect(ohne.single.flaeche, closeTo(17280000, 1e-6));
      final loch = ohne.single.loecher.single;
      expect(loch.flaeche, closeTo(2160000, 1e-6));
      expect(loch.gegenUhrzeigersinn, isFalse);
      expect(ohne.single.kontur.gegenUhrzeigersinn, isTrue);
      expect(ohne.single.kontur.punkte, hasLength(4));
    });

    test('Schnitt und Vereinigung', () {
      expect(_flaechen(_terrasse.geschnitten(_ausschnitt)), [
        closeTo(2160000, 1e-6),
      ]);
      expect(_flaechen(_terrasse.vereinigt(_ausschnitt)), [
        closeTo(19440000, 1e-6),
      ]);
      final halb = _rechteck(4000, 1000, 3000, 1000);
      expect(_flaechen(_terrasse.vereinigt(halb)), [
        closeTo(19440000 + 1600000, 1e-6),
      ]);
      expect(_flaechen(_terrasse.geschnitten(halb)), [closeTo(1400000, 1e-6)]);
      expect(_flaechen(halb.ohne(_terrasse)), [closeTo(1600000, 1e-6)]);
    });

    test('getrennte Flächen bleiben getrennt', () {
      final weit = _rechteck(10000, 0, 1000, 1000);
      expect(_flaechen(_terrasse.vereinigt(weit)), [
        closeTo(1000000, 1e-6),
        closeTo(19440000, 1e-6),
      ]);
      expect(_terrasse.geschnitten(weit), isEmpty);
      expect(_flaechen(_terrasse.ohne(weit)), [closeTo(19440000, 1e-6)]);
    });

    test('gleiche Flächen', () {
      expect(_terrasse.ohne(_terrasse), isEmpty);
      expect(_flaechen(_terrasse.vereinigt(_terrasse)), [
        closeTo(19440000, 1e-6),
      ]);
      expect(_terrasse.vereinigt(_terrasse).single.kontur.punkte, hasLength(4));
      expect(_flaechen(_terrasse.geschnitten(_terrasse)), [
        closeTo(19440000, 1e-6),
      ]);
    });

    test('gemeinsame Kante: ein Rechteck ohne Zwischenpunkte', () {
      final rechts = _rechteck(5400, 0, 1000, 3600);
      final v = _terrasse.vereinigt(rechts);
      expect(v.single.kontur.punkte, hasLength(4));
      expect(v.single.flaeche, closeTo(23040000, 1e-6));
      expect(_terrasse.geschnitten(rechts), isEmpty);
    });

    test('teilweise gemeinsame Kante', () {
      final rechts = _rechteck(5400, 1000, 1000, 1000);
      final v = _terrasse.vereinigt(rechts).single;
      expect(v.flaeche, closeTo(20440000, 1e-6));
      expect(v.kontur.punkte, hasLength(8));
      final innen = _rechteck(4400, 1000, 1000, 1000);
      final kerbe = _terrasse.ohne(innen).single;
      expect(kerbe.loecher, isEmpty);
      expect(kerbe.kontur.punkte, hasLength(8));
      expect(kerbe.flaeche, closeTo(18440000, 1e-6));
    });

    test('Berührung in einer Ecke: zwei Teile', () {
      final ecke = _rechteck(5400, 3600, 1000, 1000);
      expect(_flaechen(_terrasse.vereinigt(ecke)), [
        closeTo(1000000, 1e-6),
        closeTo(19440000, 1e-6),
      ]);
      expect(
        _terrasse.vereinigt(ecke).every((f) => f.kontur.punkte.length == 4),
        isTrue,
      );
    });

    test('ein Streifen teilt die Terrasse', () {
      final streifen = _rechteck(2000, -1000, 1000, 6000);
      expect(_flaechen(_terrasse.ohne(streifen)), [
        closeTo(7200000, 1e-6),
        closeTo(8640000, 1e-6),
      ]);
    });

    test('Kreis-Ausschnitt: Bogen als Sehnenzug', () {
      final kreis = Flaeche(Kontur.kreis(const Punkt(2700, 1800), 1000));
      final ohne = _terrasse.ohne(kreis).single;
      final exakt = 19440000 - math.pi * 1000 * 1000;
      // Sehnenzug innerhalb von 0,1 mm: Abweichung höchstens Umfang · 0,1
      expect(ohne.flaeche, greaterThan(exakt));
      expect(ohne.flaeche, lessThan(exakt + 2 * math.pi * 1000 * 0.1));
      expect(ohne.loecher.single.punkte, hasLength(224));
    });

    test('Löcher gehören zum kleinsten umgebenden Teil', () {
      final ring = Flaeche(_terrasse.kontur, [_ausschnitt.kontur]);
      final insel = _rechteck(2500, 1300, 500, 500);
      final ergebnis = verknuepfe(
        [ring, insel],
        const [],
        Verknuepfung.vereinigung,
      );
      expect(_flaechen(ergebnis), [
        closeTo(250000, 1e-6),
        closeTo(17280000, 1e-6),
      ]);
      final gross = ergebnis.firstWhere((f) => f.flaeche > 1000000);
      expect(gross.loecher.single.flaeche, closeTo(2160000, 1e-6));
      expect(ergebnis.firstWhere((f) => f.flaeche < 1000000).loecher, isEmpty);
    });

    test('Insel im Loch füllt es wieder', () {
      final ring = Flaeche(_terrasse.kontur, [_ausschnitt.kontur]);
      final v = ring.vereinigt(_ausschnitt);
      expect(v.single.loecher, isEmpty);
      expect(v.single.flaeche, closeTo(19440000, 1e-6));
    });

    test('Dreieck mit Grundseite auf der Kante', () {
      final dreieck = Flaeche(
        Kontur(const [Punkt(1000, 3600), Punkt(3000, 3600), Punkt(2000, 4600)]),
      );
      final v = _terrasse.vereinigt(dreieck).single;
      expect(v.flaeche, closeTo(19440000 + 1000000, 1e-6));
      expect(v.kontur.punkte, hasLength(7));
      expect(_terrasse.geschnitten(dreieck), isEmpty);
    });

    test('Spitze liegt auf einer Kante (T-Stoß): zwei Teile', () {
      final dreieck = Flaeche(
        Kontur(const [Punkt(2000, 3600), Punkt(3000, 4600), Punkt(1000, 4600)]),
      );
      expect(_flaechen(_terrasse.vereinigt(dreieck)), [
        closeTo(1000000, 1e-6),
        closeTo(19440000, 1e-6),
      ]);
      expect(_terrasse.geschnitten(dreieck), isEmpty);
    });

    test('gerader Zwischenpunkt auf einer deckungsgleichen Kante', () {
      // Anbau rechts mit zusätzlichem Punkt (5400|1000) auf der linken Kante
      final anbau = Flaeche(
        Kontur(const [
          Punkt(5400, -1000),
          Punkt(6400, -1000),
          Punkt(6400, 2000),
          Punkt(5400, 2000),
          Punkt(5400, 1000),
        ]),
      );
      for (final (a, b) in [(_terrasse, anbau), (anbau, _terrasse)]) {
        final v = a.vereinigt(b).single;
        expect(v.flaeche, closeTo(19440000 + 3000000, 1e-6));
        expect(v.kontur.punkte, hasLength(8));
        expect(a.geschnitten(b), isEmpty);
      }
      // dasselbe gedreht und verschoben
      final d = _terrasse.gedreht(33, const Punkt(-700, 900));
      final e = anbau.gedreht(33, const Punkt(-700, 900));
      for (final (a, b) in [(d, e), (e, d)]) {
        final v = a.vereinigt(b).single;
        expect(v.flaeche, closeTo(19440000 + 3000000, 1e-3));
        expect(v.kontur.punkte, hasLength(8));
      }
    });

    test('gedrehte gemeinsame Kante: wieder ein Rechteck mit vier Ecken', () {
      final links = _terrasse.gedreht(17, const Punkt(1234, 567));
      final rechts = _rechteck(
        5400,
        0,
        1000,
        3600,
      ).gedreht(17, const Punkt(1234, 567));
      final v = links.vereinigt(rechts).single;
      expect(v.kontur.punkte, hasLength(4));
      expect(v.flaeche, closeTo(23040000, 1e-3));
    });

    test('Loch gehört zum kleinsten Teil, auch verschachtelt', () {
      final ring = Flaeche(_terrasse.kontur, [_ausschnitt.kontur]);
      final innenring = Flaeche(
        Kontur.rechteck(1400, 1000, const Punkt(2200, 1100)),
        [Kontur.rechteck(400, 400, const Punkt(2700, 1400))],
      );
      final ergebnis = verknuepfe(
        [ring, innenring],
        const [],
        Verknuepfung.vereinigung,
      );
      expect(_flaechen(ergebnis), [
        closeTo(1400000 - 160000, 1e-6),
        closeTo(17280000, 1e-6),
      ]);
      final klein = ergebnis.firstWhere((f) => f.flaeche < 5000000);
      expect(klein.loecher.single.flaeche, closeTo(160000, 1e-6));
      final gross = ergebnis.firstWhere((f) => f.flaeche > 5000000);
      expect(gross.loecher.single.flaeche, closeTo(2160000, 1e-6));
    });
  });

  group('Prüfungen für Ausschnitte und Teilflächen', () {
    test('überschneidet: Berührung zählt nicht, Toleranz 1 mm²', () {
      expect(_terrasse.ueberschneidet(_ausschnitt), isTrue);
      expect(_terrasse.ueberschneidet(_rechteck(5400, 0, 100, 100)), isFalse);
      expect(_terrasse.ueberschneidet(_rechteck(5399.5, 0, 100, 1)), isFalse);
      expect(_terrasse.ueberschneidet(_rechteck(5398, 0, 100, 1)), isTrue);
    });

    test('umschließt: auch am Rand anliegend', () {
      expect(_terrasse.umschliesst(_ausschnitt), isTrue);
      expect(_terrasse.umschliesst(_rechteck(0, 0, 100, 100)), isTrue);
      expect(_terrasse.umschliesst(_rechteck(-10, 0, 100, 100)), isFalse);
      expect(_terrasse.umschliesst(_rechteck(-0.5, 0, 100, 1)), isTrue);
      expect(_ausschnitt.umschliesst(_terrasse), isFalse);
    });

    test('Abstand der Ränder', () {
      expect(
        _terrasse.abstand(_rechteck(5600, 0, 100, 100)),
        closeTo(200, 1e-9),
      );
      expect(
        _terrasse.abstand(_rechteck(5700, 4000, 100, 100)),
        closeTo(500, 1e-9),
      );
      expect(_terrasse.abstand(_rechteck(5400, 0, 100, 100)), 0);
      expect(_terrasse.abstand(_ausschnitt), 0);
      final ring = Flaeche(_terrasse.kontur, [_ausschnitt.kontur]);
      expect(ring.abstand(_rechteck(2100, 1100, 100, 100)), closeTo(100, 1e-9));
    });
  });
}
