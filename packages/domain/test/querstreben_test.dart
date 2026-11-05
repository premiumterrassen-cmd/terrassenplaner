import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'argument_fehler.dart';

/// Planungsstand im Transportformat vor M6-06 (bzw. nur mit Querstreben).
Uint8List _alt({bool? querstreben, int? reihen}) {
  final fbb = fb.Builder();
  final masseOrt = fbb.writeListInt32([4800, 3090]);
  fbb
    ..startTable(2)
    ..addUint8(0, 0)
    ..addOffset(1, masseOrt);
  final ort = fbb.endTable();
  fbb
    ..startTable(84)
    ..addOffset(1, ort)
    ..addBool(82, querstreben)
    ..addUint16(83, reihen);
  fbb.finish(fbb.endTable());
  return fbb.buffer;
}

/// UK-Holz Robinie 40 x 60 mm wie in F01.
final _uk = Artikel(
  nummer: const Artikelnummer('10-10-031'),
  titel: 'UK 40 x 60',
  art: Artikelart.unterkonstruktion,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: const Millimeter(40),
    staerke: const Millimeter(60),
    laengen: const [Millimeter(6000)],
  ),
  holzart: robinie,
  serie: basic,
);

void main() {
  const f01 = Planungsstand.start;

  group('Planungsstand mit Querstreben (M6-06)', () {
    test('Vorgabe: keine zusätzlichen Querstreben, Anzahl automatisch', () {
      expect(f01.querstreben, isFalse);
      expect(f01.querstrebenReihen, isNull);
    });

    test('ändern; Gleichheit und Hash; Anzahl bleibt beim Abwählen', () {
      final mit = f01.mitQuerstreben(true);
      expect(mit.querstreben, isTrue);
      expect(mit == f01, isFalse);
      expect(mit.hashCode == f01.hashCode, isFalse);
      expect(mit.mitQuerstreben(false), f01);
      final sieben = mit.mitQuerstrebenReihen(7);
      expect(sieben.querstrebenReihen, 7);
      expect(sieben == mit, isFalse);
      expect(sieben.hashCode == mit.hashCode, isFalse);
      expect(sieben.mitQuerstreben(false).querstrebenReihen, 7);
      expect(sieben.mitQuerstrebenReihen(null), mit);
      // andere Eingaben lassen die Anzahl stehen
      expect(sieben.mitNutzungsart(Nutzungsart.rahmen).querstrebenReihen, 7);
    });

    test('Anzahl der Quertraversen 1 bis 99', () {
      for (final (n, gueltig) in [
        (0, false),
        (1, true),
        (99, true),
        (100, false),
      ]) {
        expect(
          Planungsstand.querstrebenReihenGueltig(n),
          gueltig,
          reason: '$n',
        );
      }
      expect(f01.mitQuerstrebenReihen(1).querstrebenReihen, 1);
      expect(f01.mitQuerstrebenReihen(99).querstrebenReihen, 99);
      expect(
        () => f01.mitQuerstrebenReihen(0),
        wirftArgumentFehler('reihen', 0, 'muss 1 bis 99 sein'),
      );
      expect(
        () => f01.mitQuerstrebenReihen(100),
        wirftArgumentFehler('reihen', 100, 'muss 1 bis 99 sein'),
      );
    });

    test('Transportformat: hin und zurück, abwärtskompatibel', () {
      for (final stand in [
        f01.mitQuerstreben(true),
        f01.mitQuerstreben(true).mitQuerstrebenReihen(12),
        f01.mitQuerstrebenReihen(3),
      ]) {
        expect(Planungsstand.ausBytes(stand.zuBytes()), stand);
      }
      final alt = Planungsstand.ausBytes(_alt());
      expect(alt.querstreben, isFalse);
      expect(alt.querstrebenReihen, isNull);
      final neu = Planungsstand.ausBytes(_alt(querstreben: true, reihen: 4));
      expect(neu.querstreben, isTrue);
      expect(neu.querstrebenReihen, 4);
    });
  });

  group('Reihen der Querstreben (M6-06, R-C03)', () {
    test('automatisch höchstens 60 cm auseinander, mindestens eine', () {
      final mit = f01.mitQuerstreben(true);
      for (final (mm, reihen) in [
        (300, 1),
        (1200, 1),
        (1201, 2),
        (3090, 5),
        (3600, 5),
        (3601, 6),
      ]) {
        expect(strebenreihen(mit, Millimeter(mm)), reihen, reason: '$mm');
      }
    });

    test('die eingegebene Anzahl gilt fest – auch statt der Versteifung', () {
      final versteift = f01.mitNutzungsart(Nutzungsart.versteifungMitRahmen);
      expect(strebenreihen(versteift, const Millimeter(3090)), 2);
      final mit = versteift.mitQuerstreben(true);
      expect(strebenreihen(mit, const Millimeter(3090)), 5);
      expect(
        strebenreihen(mit.mitQuerstrebenReihen(3), const Millimeter(3090)),
        3,
      );
      // ohne Querstreben gilt die Anzahl nicht
      expect(
        strebenreihen(f01.mitQuerstrebenReihen(3), const Millimeter(3090)),
        0,
      );
      // auch bei Hochterrasse (3.7 gibt es immer)
      expect(
        strebenreihen(
          f01.mitTerrassenart(Terrassenart.hochterrasse).mitQuerstreben(true),
          const Millimeter(3090),
        ),
        5,
      );
    });

    test('F01 mit Querstreben: 5 Reihen à 12 Streben; Mengen und '
        'Zeichnung folgen der Anzahl', () {
      final z = ukZusatz(
        f01.mitQuerstreben(true),
        _uk,
        ukAbstand: const Millimeter(400),
      );
      expect(z.reihen, 5);
      expect(z.streben, hasLength(60));
      expect(z.stuecke, hasLength(60));
      expect(z.stuecke.every((s) => s.lage == Stuecklage.quer), isTrue);
      // 60 × 36 cm = 21,6 m: drei 6-m-Hölzer à 16, der Rest (12 × 36 cm)
      // aus einem 5-m-Holz
      expect(
        {for (final b in z.bedarf) b.laenge!.mm: b.stueck},
        {5000: 1, 6000: 3},
      );
      expect(
        {for (final s in z.streben) s.von.y},
        {515.0, 1030.0, 1545.0, 2060.0, 2575.0},
      );
      final drei = ukZusatz(
        f01.mitQuerstreben(true).mitQuerstrebenReihen(3),
        _uk,
        ukAbstand: const Millimeter(400),
      );
      expect(drei.reihen, 3);
      expect(drei.streben, hasLength(36));
      expect(Ukzusatz.keiner.reihen, 0);
    });
  });

  group('Berechnung mit Querstreben (M6-06)', () {
    test('Transportformat: Streben und Anzahl, abwärtskompatibel', () {
      final b = Berechnung(
        umriss: const [Punkt(0, 0), Punkt(4800, 0), Punkt(4800, 3090)],
        flaeche: 1,
        querstreben: const [
          (von: Punkt(20, 1030), bis: Punkt(380, 1030)),
          (von: Punkt(420, 1030), bis: Punkt(780, 1030.5)),
        ],
        querstrebenReihen: 1,
      );
      final zurueck = Berechnung.ausBytes(b.zuBytes());
      expect(zurueck.querstreben, b.querstreben);
      expect(zurueck.querstrebenReihen, 1);
      expect(b.querstreben.clear, throwsUnsupportedError);
      final ohne = Berechnung.ausBytes(
        Berechnung(umriss: const [], flaeche: 0).zuBytes(),
      );
      expect(ohne.querstreben, isEmpty);
      expect(ohne.querstrebenReihen, isNull);
      final planung = b.mitPlanung(2);
      expect(planung.querstreben, b.querstreben);
      expect(planung.querstrebenReihen, 1);
    });
  });
}
