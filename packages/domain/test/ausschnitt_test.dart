import 'dart:math' as math;

import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'argument_fehler.dart';

Ausschnitt _a({
  String bezeichnung = 'A1',
  int x = 1000,
  int y = 1000,
  int laenge = 1800,
  int breite = 1200,
  Ausschnittform form = Ausschnittform.rechteck,
}) => Ausschnitt(
  bezeichnung: bezeichnung,
  x: Millimeter(x),
  y: Millimeter(y),
  laenge: Millimeter(laenge),
  breite: Millimeter(breite),
  form: form,
);

final _terrasse = Planungsstand(
  grundriss: RechteckGrundriss(const Millimeter(5400), const Millimeter(3600)),
);

Planungsstand _mit(List<Ausschnitt> a) =>
    Planungsstand(grundriss: _terrasse.grundriss, ausschnitte: a);

void main() {
  group('Formen (M4-12)', () {
    test('Rechteck, Dreieck, Sechseck, Kreis', () {
      expect(_a().kontur.flaeche, 1800 * 1200);
      final d = _a(form: Ausschnittform.dreieck).kontur;
      expect(d.flaeche, 1800 * 1200 / 2);
      expect(d.punkte.first, const Punkt(1900, 1000));
      final s = _a(form: Ausschnittform.sechseck).kontur;
      expect(s.flaeche, closeTo(1800 * 1200 * 3 * math.sqrt(3) / 8, 1e-6));
      expect(s.punkte.first.x, closeTo(2800, 1e-9));
      expect(s.punkte.first.y, closeTo(1600, 1e-9));
      final k = _a(form: Ausschnittform.kreis);
      expect(k.breite, const Millimeter(1800));
      expect(k.kontur.flaeche, closeTo(math.pi * 900 * 900, 1e-6));
      expect(k.kontur.huellrechteck.min.x, closeTo(1000, 1e-6));
      expect([for (final f in Ausschnittform.values) f.nummer], [0, 1, 2, 3]);
      expect([for (final f in Ausschnittfunktion.values) f.nummer], [0, 1]);
      expect(
        [for (final i in Ausschnittinhalt.values) i.nummer],
        [0, 1, 2, 3, 4, 5],
      );
    });

    test('Kopien: Form, Funktion, Inhalt, Bezeichnung, verschoben', () {
      final a = _a();
      expect(a.form, Ausschnittform.rechteck);
      expect(a.funktion, Ausschnittfunktion.leer);
      expect(a.inhalt, Ausschnittinhalt.leer);
      expect(a.mitForm(Ausschnittform.kreis).breite, const Millimeter(1800));
      expect(
        a.mitFunktion(Ausschnittfunktion.andererBelag).funktion,
        Ausschnittfunktion.andererBelag,
      );
      expect(a.mitInhalt(Ausschnittinhalt.pool).inhalt, Ausschnittinhalt.pool);
      expect(a.mitBezeichnung('Pool').bezeichnung, 'Pool');
      final v = a.verschoben(const Millimeter(-100), const Millimeter(50));
      expect([v.x.mm, v.y.mm], [900, 1050]);
      expect(v.mitInhalt(Ausschnittinhalt.rasen).x, v.x);
      expect(
        () => a.mitBezeichnung('Elf Zeichen'),
        wirftArgumentFehler(
          'bezeichnung',
          'Elf Zeichen',
          'braucht 1 bis 10 Zeichen',
        ),
      );
      expect(Ausschnitt.vorgabeLaenge, const Millimeter(1800));
      expect(Ausschnitt.vorgabeBreite, const Millimeter(1200));
    });

    test('Gleichheit berücksichtigt Form, Funktion und Inhalt', () {
      final a = _a();
      expect(a, _a());
      expect(a.hashCode, _a().hashCode);
      for (final anders in [
        a.mitForm(Ausschnittform.dreieck),
        a.mitFunktion(Ausschnittfunktion.andererBelag),
        a.mitInhalt(Ausschnittinhalt.erde),
      ]) {
        expect(anders == a, isFalse);
      }
    });

    test('Transport mit Form, Funktion und Inhalt', () {
      final stand = _mit([
        _a(form: Ausschnittform.sechseck)
            .mitFunktion(Ausschnittfunktion.andererBelag)
            .mitInhalt(Ausschnittinhalt.kiesHell),
        _a(bezeichnung: 'A2', x: 3500, form: Ausschnittform.kreis, laenge: 500),
      ]);
      final zurueck = Planungsstand.ausBytes(stand.zuBytes());
      expect(zurueck, stand);
      expect(zurueck.ausschnitte.first.inhalt, Ausschnittinhalt.kiesHell);
    });
  });

  test('unbekannte Form im Transport wird abgewiesen', () {
    final fbb = fb.Builder();
    final masse = fbb.writeListInt32([5400, 3600]);
    fbb
      ..startTable(2)
      ..addUint8(0, 0)
      ..addOffset(1, masse);
    final grundriss = fbb.endTable();
    final name = fbb.writeString('A1');
    final ausschnittMasse = fbb.writeListInt32([100, 100, 500, 500]);
    fbb
      ..startTable(5)
      ..addOffset(0, name)
      ..addOffset(1, ausschnittMasse)
      ..addUint8(2, 9);
    final ausschnitt = fbb.endTable();
    final liste = fbb.writeList([ausschnitt]);
    fbb
      ..startTable(3)
      ..addOffset(1, grundriss)
      ..addOffset(2, liste);
    fbb.finish(fbb.endTable());
    expect(
      () => Planungsstand.ausBytes(fbb.buffer),
      throwsA(
        isA<FormatException>().having(
          (e) => e.message,
          'message',
          'unbekannte Nummer 9',
        ),
      ),
    );
  });

  group('Hinzufügen und entfernen', () {
    test('A1, A2 … mitten im Grundriss, 180 × 120 cm', () {
      final eins = _terrasse.mitNeuemAusschnitt();
      final a1 = eins.ausschnitte.single;
      expect(a1.bezeichnung, 'A1');
      expect(
        [a1.x.mm, a1.y.mm, a1.laenge.mm, a1.breite.mm],
        [1800, 1200, 1800, 1200],
      );
      final zwei = eins.mitNeuemAusschnitt();
      expect(zwei.ausschnitte.last.bezeichnung, 'A2');
      // nach Entfernen von A1 ist der Name wieder frei
      final ohne = zwei.ohneAusschnitt(0);
      expect(ohne.ausschnitte.single.bezeichnung, 'A2');
      expect(ohne.mitNeuemAusschnitt().ausschnitte.last.bezeichnung, 'A1');
      final rund = _terrasse
          .mitRundungen(Rundungen.keine.mitEcke(0, const Millimeter(500)))
          .mitNeuemAusschnitt();
      expect(rund.rundungen.leer, isFalse);
      expect(rund.ohneAusschnitt(0).rundungen.leer, isFalse);
    });
  });

  group('Prüfungen (Abnahme M4-12)', () {
    test('alles in Ordnung, Berührung am Rand und untereinander erlaubt', () {
      expect(pruefeAusschnitte(_terrasse), isEmpty);
      expect(pruefeAusschnitte(_mit([_a()])), isEmpty);
      expect(
        pruefeAusschnitte(
          _mit([_a(x: 0, y: 0), _a(bezeichnung: 'A2', x: 1800, y: 0)]),
        ),
        isEmpty,
      );
      expect(
        pruefeAusschnitte(Planungsstand.start.mitForm(Terrassenform.oForm)),
        isEmpty,
      );
    });

    test('außerhalb der Terrasse', () {
      expect(pruefeAusschnitte(_mit([_a(x: 4000)])), [
        (problem: AusschnittProblem.ausserhalb, ausschnitt: 0, anderer: null),
      ]);
      expect(
        pruefeAusschnitte(_mit([_a(x: -100)])).single.problem,
        AusschnittProblem.ausserhalb,
      );
    });

    test('Kollision zweier Ausschnitte', () {
      expect(pruefeAusschnitte(_mit([_a(), _a(bezeichnung: 'A2', x: 2000)])), [
        (problem: AusschnittProblem.kollision, ausschnitt: 1, anderer: 0),
      ]);
    });

    test('Teilung der Terrasse', () {
      // quer durch die ganze Tiefe: links und rechts bleibt je ein Stück
      final streifen = _a(x: 2000, y: 0, laenge: 1000, breite: 3600);
      expect(pruefeAusschnitte(_mit([streifen])), [
        (problem: AusschnittProblem.teilung, ausschnitt: 0, anderer: null),
      ]);
      // zwei Ausschnitte, erst zusammen trennend
      final oben = _a(x: 2000, y: 0, laenge: 1000, breite: 1800);
      final unten = _a(
        bezeichnung: 'A2',
        x: 2000,
        y: 1800,
        laenge: 1000,
        breite: 1800,
      );
      expect(pruefeAusschnitte(_mit([oben, unten])), [
        (problem: AusschnittProblem.teilung, ausschnitt: 1, anderer: null),
      ]);
    });
  });
}
