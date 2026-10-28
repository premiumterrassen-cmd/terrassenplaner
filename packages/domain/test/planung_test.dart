import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'argument_fehler.dart';

Planungsstand _rechteck(int ab, int bc) =>
    Planungsstand(grundriss: RechteckGrundriss(Millimeter(ab), Millimeter(bc)));

void main() {
  final a = _rechteck(4000, 3000);
  final b = _rechteck(2000, 1000);
  final c = _rechteck(1000, 1000);

  group('Terrassenfläche (M4-14)', () {
    test('Häufigkeit 1 bis 99', () {
      expect(Terrassenflaeche(a).haeufigkeit, 1);
      expect(Terrassenflaeche(a, haeufigkeit: 99).haeufigkeit, 99);
      expect(
        () => Terrassenflaeche(a, haeufigkeit: 0),
        wirftArgumentFehler('haeufigkeit', 0, 'zwischen 1 und 99'),
      );
      expect(
        () => Terrassenflaeche(a, haeufigkeit: 100),
        wirftArgumentFehler('haeufigkeit', 100, 'zwischen 1 und 99'),
      );
      expect(Terrassenflaeche.start.stand, Planungsstand.start);
      expect(Terrassenflaeche.start.haeufigkeit, 1);
    });

    test('Gleichheit über Stand und Häufigkeit', () {
      expect(Terrassenflaeche(a), Terrassenflaeche(a));
      expect(Terrassenflaeche(a).hashCode, Terrassenflaeche(a).hashCode);
      expect(Terrassenflaeche(a), isNot(Terrassenflaeche(b)));
      expect(Terrassenflaeche(a), isNot(Terrassenflaeche(a, haeufigkeit: 2)));
      expect(Terrassenflaeche(a), isNot(Object()));
    });
  });

  group('Planung mit mehreren Flächen (M4-14)', () {
    test('Start: eine Fläche mit der Startkonfiguration', () {
      expect(Planung.start.flaechen, [Terrassenflaeche.start]);
      expect(Planung.start.aktiv, 0);
      expect(Planung.start.aktuell, Planungsstand.start);
      expect(Planung.start.haeufigkeit, 1);
    });

    test('mindestens eine Fläche, aktiver Reiter gültig', () {
      expect(
        () => Planung(const []),
        wirftArgumentFehler(
          'flaechen',
          const <Terrassenflaeche>[],
          'mindestens eine Fläche',
        ),
      );
      expect(() => Planung([Terrassenflaeche(a)], aktiv: 1), throwsRangeError);
      expect(() => Planung([Terrassenflaeche(a)], aktiv: -1), throwsRangeError);
      final liste = [Terrassenflaeche(a)];
      final p = Planung(liste);
      liste.add(Terrassenflaeche(b));
      expect(p.flaechen, hasLength(1));
      expect(() => p.flaechen.add(Terrassenflaeche(b)), throwsUnsupportedError);
    });

    test('Fläche hinzufügen: Startkonfiguration, gleich bearbeitet', () {
      final p = Planung([Terrassenflaeche(a)]).mitNeuerFlaeche();
      expect(p.flaechen, [Terrassenflaeche(a), Terrassenflaeche.start]);
      expect(p.aktiv, 1);
      expect(p.aktuell, Planungsstand.start);
      expect(p.mitNeuerFlaeche().aktiv, 2);
    });

    test('Stand und Häufigkeit gelten nur für die bearbeitete Fläche', () {
      final p = Planung([
        Terrassenflaeche(a, haeufigkeit: 3),
        Terrassenflaeche(b),
      ]);
      final neu = p.mitStand(c);
      expect(neu.flaechen, [
        Terrassenflaeche(c, haeufigkeit: 3),
        Terrassenflaeche(b),
      ]);
      expect(neu.aktiv, 0);
      final zweite = p.gewaehlt(1).mitHaeufigkeit(4);
      expect(zweite.flaechen, [
        Terrassenflaeche(a, haeufigkeit: 3),
        Terrassenflaeche(b, haeufigkeit: 4),
      ]);
      expect(zweite.aktiv, 1);
      expect(zweite.haeufigkeit, 4);
      expect(zweite.aktuell, b);
      expect(() => p.mitHaeufigkeit(0), throwsArgumentError);
      expect(() => p.gewaehlt(2), throwsRangeError);
    });

    test('Fläche löschen: Reiter danach', () {
      final p = Planung([
        Terrassenflaeche(a),
        Terrassenflaeche(b),
        Terrassenflaeche(c),
      ], aktiv: 1);
      // spätere Fläche: Reiter bleibt
      expect(
        p.ohneFlaeche(2),
        Planung([Terrassenflaeche(a), Terrassenflaeche(b)], aktiv: 1),
      );
      // bearbeitete Fläche: die davor
      expect(
        p.ohneFlaeche(1),
        Planung([Terrassenflaeche(a), Terrassenflaeche(c)]),
      );
      // frühere Fläche: dieselbe Fläche bleibt bearbeitet
      final frueher = p.ohneFlaeche(0);
      expect(frueher.aktiv, 0);
      expect(frueher.aktuell, b);
      // erste Fläche bearbeitet und gelöscht: die nächste
      final erste = p.gewaehlt(0).ohneFlaeche(0);
      expect(erste.aktiv, 0);
      expect(erste.aktuell, b);
      expect(p.gewaehlt(2).ohneFlaeche(0).aktuell, c);
      expect(() => p.ohneFlaeche(3), throwsRangeError);
      expect(
        () => Planung([Terrassenflaeche(a)]).ohneFlaeche(0),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'die letzte Fläche kann nicht gelöscht werden',
          ),
        ),
      );
    });

    test('Gleichheit über Flächen und Reiter', () {
      final p = Planung([Terrassenflaeche(a), Terrassenflaeche(b)]);
      expect(p, Planung([Terrassenflaeche(a), Terrassenflaeche(b)]));
      expect(
        p.hashCode,
        Planung([Terrassenflaeche(a), Terrassenflaeche(b)]).hashCode,
      );
      expect(p, isNot(p.gewaehlt(1)));
      expect(p, isNot(Planung([Terrassenflaeche(a)])));
      expect(p, isNot(Planung([Terrassenflaeche(a), Terrassenflaeche(c)])));
      expect(p, isNot(Planung([Terrassenflaeche(c), Terrassenflaeche(b)])));
      expect(p, isNot(Object()));
    });

    test('Transportformat hin und zurück', () {
      final p = Planung([
        Terrassenflaeche(a, haeufigkeit: 2),
        Terrassenflaeche(
          Planungsstand.start.mitNeuemAusschnitt(),
          haeufigkeit: 99,
        ),
        Terrassenflaeche(b),
      ], aktiv: 2);
      final zurueck = Planung.ausBytes(p.zuBytes());
      expect(zurueck, p);
      expect(zurueck.flaechen[1].stand.ausschnitte, hasLength(1));
      expect(Planung.ausBytes(Planung.start.zuBytes()), Planung.start);
    });

    test('Transportformat: Schema, fehlende Felder', () {
      final puffer = fb.BufferContext.fromBytes(Planung.start.zuBytes());
      expect(
        const fb.Uint16Reader().vTableGet(puffer, puffer.derefObject(0), 4, 0),
        Planung.schema,
      );
      expect(Planung.schema, 1);
      // ohne Flächen: ungültig
      final leer = fb.Builder()..startTable(3);
      leer.finish(leer.endTable());
      expect(() => Planung.ausBytes(leer.buffer), throwsArgumentError);
      // Fläche ohne Stand
      final ohneStand = fb.Builder();
      ohneStand
        ..startTable(2)
        ..addUint16(1, 2);
      final flaeche = ohneStand.endTable();
      final liste = ohneStand.writeList([flaeche]);
      ohneStand
        ..startTable(3)
        ..addOffset(1, liste);
      ohneStand.finish(ohneStand.endTable());
      expect(
        () => Planung.ausBytes(ohneStand.buffer),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'Fläche ohne Planungsstand',
          ),
        ),
      );
      // Fläche ohne Häufigkeit: 1
      final ohneHaeufigkeit = fb.Builder();
      final stand = ohneHaeufigkeit.writeListUint8(a.zuBytes());
      ohneHaeufigkeit
        ..startTable(2)
        ..addOffset(0, stand);
      final f = ohneHaeufigkeit.endTable();
      final l = ohneHaeufigkeit.writeList([f, f]);
      ohneHaeufigkeit
        ..startTable(3)
        ..addOffset(1, l);
      ohneHaeufigkeit.finish(ohneHaeufigkeit.endTable());
      final gelesen = Planung.ausBytes(ohneHaeufigkeit.buffer);
      expect(gelesen.flaechen, [Terrassenflaeche(a), Terrassenflaeche(a)]);
      expect(gelesen.aktiv, 0);
    });
  });

  group('Berechnung mit Gesamtfläche (M4-14)', () {
    const umriss = [Punkt(0, 0), Punkt(1000, 0), Punkt(0, 1000)];

    test('ohne Angabe gleich der Fläche', () {
      final b = Berechnung(umriss: umriss, flaeche: 2e6);
      expect(b.gesamtflaeche, 2e6);
      expect(b.gesamtflaecheQuadratmeter, 2);
    });

    test('im Transport, alte Puffer ohne Feld: Fläche', () {
      final b = Berechnung(umriss: umriss, flaeche: 2e6, gesamtflaeche: 7e6);
      final zurueck = Berechnung.ausBytes(b.zuBytes());
      expect(zurueck.gesamtflaeche, 7e6);
      expect(zurueck.flaeche, 2e6);
      final fbb = fb.Builder()..startTable(2);
      fbb.addFloat64(1, 3e6);
      fbb.finish(fbb.endTable());
      expect(Berechnung.ausBytes(fbb.buffer).gesamtflaeche, 3e6);
    });
  });
}
