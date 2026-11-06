import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'argument_fehler.dart';

/// Planungsstand im Transportformat vor M7-04.
Uint8List _alt() {
  final fbb = fb.Builder();
  final masseOrt = fbb.writeListInt32([4800, 3090]);
  fbb
    ..startTable(2)
    ..addUint8(0, 0)
    ..addOffset(1, masseOrt);
  final ort = fbb.endTable();
  fbb
    ..startTable(141)
    ..addOffset(1, ort);
  fbb.finish(fbb.endTable());
  return fbb.buffer;
}

void main() {
  const f01 = Planungsstand.start;

  group('Weitere Höhenreferenzpunkte im Planungsstand (M7-04)', () {
    test('neu in der Mitte, so hoch wie A, schaltet das Gefälle ein', () {
      expect(f01.hoehenpunkte, isEmpty);
      final neu = f01.mitNeuemHoehenpunkt();
      expect(neu.gefaelle, isTrue);
      expect(neu.hoehenpunkte, [
        (
          x: const Millimeter(2400),
          y: const Millimeter(1545),
          hoehe: const Millimeter(86),
        ),
      ]);
      expect(neu.wirksameHoehenpunkte, neu.hoehenpunkte);
      expect(neu.mitGefaelle(false).wirksameHoehenpunkte, isEmpty);
      expect(neu.mitGefaelle(false).hoehenpunkte, hasLength(1));
      expect(neu.ortVon(neu.hoehenpunkte.single), const Punkt(2400, 1545));
      expect(neu.hoehenpunkte.clear, throwsUnsupportedError);
      expect(neu.mitNeuemHoehenpunkt().hoehenpunkte, hasLength(2));
    });

    test('ändern mit negativen Lagen, Grenzen, entfernen', () {
      final neu = f01.mitNeuemHoehenpunkt();
      const ablauf = (
        x: Millimeter(-500),
        y: Millimeter(300000),
        hoehe: Millimeter(50),
      );
      final geaendert = neu.mitHoehenpunkt(0, ablauf);
      expect(geaendert.hoehenpunkte.single, ablauf);
      expect(geaendert.ortVon(ablauf), const Punkt(-500, 300000));
      expect(
        () => neu.mitHoehenpunkt(0, (
          x: const Millimeter(300001),
          y: const Millimeter(0),
          hoehe: const Millimeter(50),
        )),
        wirftArgumentFehler('punkt', 300001, 'Lage außerhalb ±300 m'),
      );
      expect(
        () => neu.mitHoehenpunkt(0, (
          x: const Millimeter(0),
          y: const Millimeter(-300001),
          hoehe: const Millimeter(50),
        )),
        throwsArgumentError,
      );
      expect(
        () => neu.mitHoehenpunkt(0, (
          x: const Millimeter(0),
          y: const Millimeter(0),
          hoehe: const Millimeter(0),
        )),
        throwsArgumentError,
      );
      expect(() => neu.mitHoehenpunkt(1, ablauf), throwsRangeError);
      expect(
        Planungsstand.hoehenpunktLageGueltig(const Millimeter(-300000)),
        isTrue,
      );
      expect(geaendert.ohneHoehenpunkt(0).hoehenpunkte, isEmpty);
    });

    test('Gleichheit, Hash, Transportformat; bleibt bei neuen Maßen', () {
      final neu = f01.mitNeuemHoehenpunkt();
      final anders = neu.mitHoehenpunkt(0, (
        x: const Millimeter(1),
        y: const Millimeter(1545),
        hoehe: const Millimeter(86),
      ));
      expect(neu == anders, isFalse);
      expect(neu.hashCode == anders.hashCode, isFalse);
      expect(neu == neu.mitNeuemHoehenpunkt(), isFalse);
      expect(neu.mitGefaelle(true), neu);
      expect(Planungsstand.ausBytes(anders.zuBytes()), anders);
      expect(Planungsstand.ausBytes(_alt()).hoehenpunkte, isEmpty);
      expect(
        neu
            .mitGrundriss(
              RechteckGrundriss(const Millimeter(5000), const Millimeter(3000)),
            )
            .hoehenpunkte,
        neu.hoehenpunkte,
      );
    });

    test('Kreis: A ist der Anfang der Kontur', () {
      final kreis = f01.mitForm(Terrassenform.kreis);
      expect(kreis.punktA, kreis.kontur.punkte.first);
      expect(f01.punktA, Punkt.ursprung);
    });
  });

  group('Höhenfläche mit weiteren Punkten (M7-04)', () {
    const ecken = [
      Punkt(0, 0),
      Punkt(4000, 0),
      Punkt(4000, 3000),
      Punkt(0, 3000),
    ];
    const hundert = [
      Millimeter(100),
      Millimeter(100),
      Millimeter(100),
      Millimeter(100),
    ];

    test('Ablauf in der Mitte (auf der Diagonale): dort tiefer, an den Ecken '
        'nicht', () {
      final f = Hoehenflaeche(
        ecken,
        [...hundert, const Millimeter(50)],
        const [Punkt(2000, 1500)],
      );
      expect(f.bei(const Punkt(2000, 1500)), const Millimeter(50));
      expect(f.bei(const Punkt(1000, 750)), const Millimeter(75));
      expect(f.bei(const Punkt(3000, 750)), const Millimeter(75));
      expect(f.bei(Punkt.ursprung), const Millimeter(100));
      expect(f.bei(const Punkt(4000, 3000)), const Millimeter(100));
    });

    test('Ablauf in einem Dreieck, außerhalb, auf einer Ecke', () {
      final innen = Hoehenflaeche(
        ecken,
        [...hundert, const Millimeter(40)],
        const [Punkt(3000, 500)],
      );
      expect(innen.bei(const Punkt(3000, 500)), const Millimeter(40));
      expect(innen.bei(const Punkt(3500, 2500)), const Millimeter(100));
      final aussen = Hoehenflaeche(
        ecken,
        [...hundert, const Millimeter(40)],
        const [Punkt(5000, 500)],
      );
      expect(aussen.bei(const Punkt(3000, 500)), const Millimeter(100));
      final ecke = Hoehenflaeche(
        ecken,
        [...hundert, const Millimeter(40)],
        const [Punkt(4000, 0)],
      );
      expect(ecke.bei(const Punkt(4000, 0)), const Millimeter(40));
      // ohne passende Höhen: flach
      expect(
        Hoehenflaeche(ecken, hundert, const [
          Punkt(2000, 1500),
        ]).bei(const Punkt(2000, 1500)),
        const Millimeter(100),
      );
    });
  });

  group('Höhenreferenzpunkte für die Zeichnung (M7-04)', () {
    test('mit geprüfter Höhe, ohne Gefälle keine, Transportformat', () {
      final stand = f01.mitNeuemHoehenpunkt();
      final e = anschlussergebnis(
        stand,
        hoehen: const [
          Millimeter(86),
          Millimeter(86),
          Millimeter(86),
          Millimeter(86),
          Millimeter(90),
        ],
      );
      expect(e.hoehenpunkte, [
        (ort: const Punkt(2400, 1545), hoehe: const Millimeter(90)),
      ]);
      expect(e.hoehenpunkte.clear, throwsUnsupportedError);
      expect(
        anschlussergebnis(stand).hoehenpunkte.single.hoehe,
        const Millimeter(86),
      );
      expect(anschlussergebnis(stand.mitGefaelle(false)).hoehenpunkte, isEmpty);
      final zurueck = Berechnung.ausBytes(
        Berechnung(umriss: const [], flaeche: 0, anschluss: e).zuBytes(),
      ).anschluss;
      expect(zurueck.hoehenpunkte, e.hoehenpunkte);
    });
  });
}
