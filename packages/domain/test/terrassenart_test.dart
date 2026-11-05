import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'argument_fehler.dart';

/// Planungsstand im Transportformat vor M6-01 (bzw. mit einzelnen Feldern).
Uint8List _alt({int? art, int? spannweite}) {
  final fbb = fb.Builder();
  final masseOrt = fbb.writeListInt32([4800, 3090]);
  fbb
    ..startTable(2)
    ..addUint8(0, 0)
    ..addOffset(1, masseOrt);
  final ort = fbb.endTable();
  fbb
    ..startTable(22)
    ..addOffset(1, ort)
    ..addUint8(20, art)
    ..addInt32(21, spannweite);
  fbb.finish(fbb.endTable());
  return fbb.buffer;
}

void main() {
  group('Terrassenart (M6-01)', () {
    test('Vorgabehöhen wie im alten Planer (F01, F28, F29)', () {
      expect(Terrassenart.normal.vorgabehoehe, const Millimeter(86));
      expect(Terrassenart.hochterrasse.vorgabehoehe, const Millimeter(542));
      expect(Terrassenart.vorhandeneUk.vorgabehoehe, const Millimeter(142));
      expect([for (final a in Terrassenart.values) a.nummer], [0, 1, 2]);
    });

    test('Folgeschritte: Nutzungsart nur bei der normalen Terrasse, '
        'Spannweite nur bei vorhandener UK', () {
      expect(Terrassenart.normal.mitNutzungsart, isTrue);
      expect(Terrassenart.hochterrasse.mitNutzungsart, isFalse);
      expect(Terrassenart.vorhandeneUk.mitNutzungsart, isFalse);
      expect(Terrassenart.normal.mitSpannweite, isFalse);
      expect(Terrassenart.hochterrasse.mitSpannweite, isFalse);
      expect(Terrassenart.vorhandeneUk.mitSpannweite, isTrue);
    });

    test('Spannweite 10 bis 300 cm, Vorgabe 80 cm', () {
      expect(Terrassenart.vorgabeSpannweite, const Millimeter(800));
      for (final (mm, gueltig) in [
        (99, false),
        (100, true),
        (3000, true),
        (3001, false),
      ]) {
        expect(
          Terrassenart.spannweiteGueltig(Millimeter(mm)),
          gueltig,
          reason: '$mm',
        );
      }
    });

    test('Nummer aus dem Transportformat', () {
      for (final a in Terrassenart.values) {
        expect(Terrassenart.ausNummer(a.nummer), a);
      }
      expect(
        () => Terrassenart.ausNummer(3),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'unbekannte Terrassenart 3',
          ),
        ),
      );
    });
  });

  group('Planungsstand mit Terrassenart (M6-01)', () {
    const start = Planungsstand.start;

    test('Vorgabe normale Terrasse, Spannweite 80 cm', () {
      expect(start.terrassenart, Terrassenart.normal);
      expect(start.spannweite, const Millimeter(800));
    });

    test('Art und Spannweite ändern; Gleichheit und Hash', () {
      final hoch = start.mitTerrassenart(Terrassenart.hochterrasse);
      expect(hoch.terrassenart, Terrassenart.hochterrasse);
      expect(hoch == start, isFalse);
      expect(hoch.hashCode == start.hashCode, isFalse);
      expect(hoch.mitTerrassenart(Terrassenart.normal), start);
      final weit = start.mitSpannweite(const Millimeter(600));
      expect(weit.spannweite, const Millimeter(600));
      expect(weit == start, isFalse);
      expect(weit.hashCode == start.hashCode, isFalse);
      expect(weit.mitSpannweite(const Millimeter(800)), start);
      // die Spannweite bleibt beim Wechsel der Art
      final vorhanden = weit
          .mitTerrassenart(Terrassenart.vorhandeneUk)
          .mitTerrassenart(Terrassenart.normal)
          .mitTerrassenart(Terrassenart.vorhandeneUk);
      expect(vorhanden.spannweite, const Millimeter(600));
      expect(
        start.mitSpannweite(const Millimeter(100)).spannweite,
        const Millimeter(100),
      );
      expect(
        start.mitSpannweite(const Millimeter(3000)).spannweite,
        const Millimeter(3000),
      );
      expect(
        () => start.mitSpannweite(const Millimeter(99)),
        wirftArgumentFehler('spannweite', 99, 'muss 100 bis 3000 mm sein'),
      );
      expect(
        () => start.mitSpannweite(const Millimeter(3001)),
        wirftArgumentFehler('spannweite', 3001, 'muss 100 bis 3000 mm sein'),
      );
    });

    test('bleiben bei allen anderen Änderungen', () {
      final stand = start
          .mitTerrassenart(Terrassenart.vorhandeneUk)
          .mitSpannweite(const Millimeter(650));
      final mitA = stand.mitNeuemAusschnitt();
      for (final s in [
        stand.mitGrundriss(RechteckGrundriss.start),
        stand.mitRundungen(Rundungen.keine),
        stand.mitForm(Terrassenform.lForm),
        stand.gedreht(90),
        stand.mitBelag(const Artikelnummer('10-10-146')),
        stand.mitDielenlaenge(const Millimeter(4000)),
        stand.mitKurzeStueckeVerbinden(true),
        stand.mitVerlegeart(Verlegeart.halbverband),
        stand.mitVerlegerichtung(Verlegerichtung.senkrecht),
        stand.mitAusgangspunkt(ecke: 1),
        stand.mitBefestigungsart(Befestigungsart.verschraubt),
        mitA,
        mitA.ohneAusschnitt(0),
      ]) {
        expect(s.terrassenart, Terrassenart.vorhandeneUk);
        expect(s.spannweite, const Millimeter(650));
      }
      // umgekehrt bleiben die übrigen Eingaben beim Wechsel der Art
      final belegt = start
          .mitVerlegeart(Verlegeart.drittelverband)
          .mitAusgangspunkt(ecke: 3, y: const Millimeter(-7))
          .mitTerrassenart(Terrassenart.hochterrasse);
      expect(belegt.verlegeart, Verlegeart.drittelverband);
      expect(belegt.ausgangsecke, 3);
      expect(belegt.verschiebungY, const Millimeter(-7));
    });

    test('Transport hin und zurück; fehlende Felder sind die Vorgabe', () {
      for (final a in Terrassenart.values) {
        final s = start
            .mitTerrassenart(a)
            .mitSpannweite(const Millimeter(1234));
        expect(Planungsstand.ausBytes(s.zuBytes()), s);
      }
      expect(Planungsstand.ausBytes(_alt()), start);
      final gelesen = Planungsstand.ausBytes(_alt(art: 2, spannweite: 500));
      expect(gelesen.terrassenart, Terrassenart.vorhandeneUk);
      expect(gelesen.spannweite, const Millimeter(500));
      expect(() => Planungsstand.ausBytes(_alt(art: 3)), throwsFormatException);
    });
  });
}
