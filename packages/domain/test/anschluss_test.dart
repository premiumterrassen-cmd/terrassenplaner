import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

/// Planungsstand im Transportformat vor M7 (ohne Anschluss).
Uint8List _alt() {
  final fbb = fb.Builder();
  final masseOrt = fbb.writeListInt32([4800, 3090]);
  fbb
    ..startTable(2)
    ..addUint8(0, 0)
    ..addOffset(1, masseOrt);
  final ort = fbb.endTable();
  fbb
    ..startTable(102)
    ..addOffset(1, ort);
  fbb.finish(fbb.endTable());
  return fbb.buffer;
}

void main() {
  const f01 = Planungsstand.start;

  group('Anschluss (M7-01)', () {
    test('Vorgabe ohne Rollen; Seiten aufsteigend ohne doppelte', () {
      expect(Anschluss.keiner.leer, isTrue);
      expect(f01.anschluss, Anschluss.keiner);
      final a = Anschluss.keiner
          .mitAngrenzend(2, an: true)
          .mitAngrenzend(0, an: true)
          .mitAngrenzend(2, an: true);
      expect(a.angrenzend, [0, 2]);
      expect(a.leer, isFalse);
      expect(a.grenztAn(0), isTrue);
      expect(a.grenztAn(1), isFalse);
      expect(a.mitAngrenzend(0, an: false).angrenzend, [2]);
      expect(a.angrenzend.clear, throwsUnsupportedError);
    });

    test('Gleichheit und Hash über die Seiten', () {
      final a = Anschluss.keiner.mitAngrenzend(1, an: true);
      expect(a, Anschluss.keiner.mitAngrenzend(1, an: true));
      expect(a.hashCode, Anschluss.keiner.mitAngrenzend(1, an: true).hashCode);
      expect(a == Anschluss.keiner, isFalse);
      expect(a == Anschluss.keiner.mitAngrenzend(2, an: true), isFalse);
      expect(
        a == a.mitAngrenzend(2, an: true),
        isFalse,
        reason: 'andere Anzahl',
      );
      expect(a == Object(), isFalse);
    });
  });

  group('Planungsstand mit angrenzenden Seiten (M7-01)', () {
    test('Seitenzahl je Form: Kreis und offene Freiform ohne Seiten', () {
      expect(f01.seitenzahl, 4);
      expect(f01.mitForm(Terrassenform.lForm).seitenzahl, 6);
      expect(f01.mitForm(Terrassenform.kreis).seitenzahl, 0);
      expect(f01.mitForm(Terrassenform.freiform).seitenzahl, 0);
      final offen = f01.mitGrundriss(
        FreiformGrundriss(const [Punkt(0, 0), Punkt(1000, 0), Punkt(0, 1000)]),
      );
      expect(offen.seitenzahl, 0);
      final zu = f01.mitGrundriss(
        FreiformGrundriss(const [
          Punkt(0, 0),
          Punkt(1000, 0),
          Punkt(0, 1000),
        ], geschlossen: true),
      );
      expect(zu.seitenzahl, 3);
    });

    test('Seite an Bauelement setzen und lösen (F36: A — B)', () {
      final f36 = f01.mitAngrenzend(0, an: true);
      expect(f36.anschluss.angrenzend, [0]);
      expect(f36 == f01, isFalse);
      expect(f36.hashCode == f01.hashCode, isFalse);
      expect(f36.mitAngrenzend(0, an: false), f01);
      expect(f36.mitAngrenzend(3, an: true).anschluss.angrenzend, [0, 3]);
    });

    test('nur Seiten des Grundrisses', () {
      expect(() => f01.mitAngrenzend(-1, an: true), throwsRangeError);
      expect(() => f01.mitAngrenzend(4, an: true), throwsRangeError);
      expect(
        () => f01.mitForm(Terrassenform.kreis).mitAngrenzend(0, an: true),
        throwsRangeError,
      );
    });

    test('bleibt bei gleicher Eckenzahl, beginnt bei neuer Form neu', () {
      final f36 = f01.mitAngrenzend(1, an: true);
      final anders = f36.mitGrundriss(
        RechteckGrundriss(const Millimeter(5000), const Millimeter(3000)),
      );
      expect(anders.anschluss.angrenzend, [1]);
      expect(f36.gedreht(90).anschluss.angrenzend, [1]);
      expect(f36.mitBelag(const Artikelnummer('x')).anschluss, f36.anschluss);
      expect(f36.mitForm(Terrassenform.rechteck).anschluss, Anschluss.keiner);
      expect(f36.mitForm(Terrassenform.lForm).anschluss, Anschluss.keiner);
      expect(
        f36
            .mitGrundriss(
              FreiformGrundriss(const [
                Punkt(0, 0),
                Punkt(1000, 0),
                Punkt(0, 1000),
              ], geschlossen: true),
            )
            .anschluss,
        Anschluss.keiner,
      );
    });

    test('Transportformat: hin und zurück, abwärtskompatibel', () {
      final f36 = f01.mitAngrenzend(0, an: true).mitAngrenzend(2, an: true);
      expect(Planungsstand.ausBytes(f36.zuBytes()), f36);
      expect(Planungsstand.ausBytes(f01.zuBytes()).anschluss, Anschluss.keiner);
      expect(Planungsstand.ausBytes(_alt()).anschluss, Anschluss.keiner);
    });
  });

  group('Anschlussergebnis (M7-01)', () {
    test('angrenzende Seiten grau, von Ecke zu Ecke', () {
      final f36 = f01.mitAngrenzend(3, an: true).mitAngrenzend(0, an: true);
      expect(anschlussergebnis(f36).seiten, [
        (
          seite: 0,
          rolle: Seitenrolle.bauelement,
          von: Punkt.ursprung,
          bis: const Punkt(4800, 0),
        ),
        (
          seite: 3,
          rolle: Seitenrolle.bauelement,
          von: const Punkt(0, 3090),
          bis: Punkt.ursprung,
        ),
      ]);
      expect(anschlussergebnis(f01).seiten, isEmpty);
      expect(seitenstrecke(f01, 1), (
        von: const Punkt(4800, 0),
        bis: const Punkt(4800, 3090),
      ));
    });

    test('Rolle aus dem Transportformat', () {
      expect(Seitenrolle.ausNummer(1), Seitenrolle.bauelement);
      expect(() => Seitenrolle.ausNummer(0), throwsFormatException);
    });

    test(
      'Transportformat der Berechnung: hin und zurück, abwärtskompatibel',
      () {
        final ergebnis = anschlussergebnis(
          f01.mitAngrenzend(1, an: true).mitAngrenzend(2, an: true),
        );
        final b = Berechnung(umriss: const [], flaeche: 0, anschluss: ergebnis);
        final zurueck = Berechnung.ausBytes(b.zuBytes()).anschluss;
        expect(zurueck.seiten, ergebnis.seiten);
        expect(b.mitPlanung(0).anschluss, same(ergebnis));
        expect(ergebnis.seiten.clear, throwsUnsupportedError);
        expect(
          Berechnung(umriss: const [], flaeche: 0).anschluss.seiten,
          isEmpty,
        );
        final fbb = fb.Builder()..startTable(1);
        fbb.finish(fbb.endTable());
        expect(Berechnung.ausBytes(fbb.buffer).anschluss.seiten, isEmpty);
      },
    );
  });
}
