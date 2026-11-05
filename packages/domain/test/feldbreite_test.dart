import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'auflagerdaten.dart';

/// Planungsstand im Transportformat vor M6-09 (bzw. nur mit Feldbreite).
Uint8List _alt({int? feldbreite}) {
  final fbb = fb.Builder();
  final masseOrt = fbb.writeListInt32([4800, 3090]);
  fbb
    ..startTable(2)
    ..addUint8(0, 0)
    ..addOffset(1, masseOrt);
  final ort = fbb.endTable();
  fbb
    ..startTable(102)
    ..addOffset(1, ort)
    ..addInt32(101, feldbreite);
  fbb.finish(fbb.endTable());
  return fbb.buffer;
}

final _belag = Artikel(
  nummer: const Artikelnummer('10-10-073'),
  titel: 'Diele',
  art: Artikelart.diele,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: const Millimeter(60),
    staerke: const Millimeter(21),
    laengen: const [Millimeter(5000)],
  ),
  holzart: robinie,
  serie: basic,
);

void main() {
  const f01 = Planungsstand.start;

  group('Maximale Feldbreite (M6-09, R-C01)', () {
    test('Auswahl: 30, 35, 40 cm bis zur höchsten; 50/60 cm des alten '
        'Planers verbietet die Firmenregel', () {
      expect(feldbreitenAuswahl, const [
        Millimeter(300),
        Millimeter(350),
        Millimeter(400),
        Millimeter(500),
        Millimeter(600),
      ]);
      expect(feldbreiten(const Millimeter(400)), const [
        Millimeter(300),
        Millimeter(350),
        Millimeter(400),
      ]);
      expect(feldbreiten(const Millimeter(600)), feldbreitenAuswahl);
      expect(feldbreiten(const Millimeter(299)), isEmpty);
      expect(hoechsteFeldbreite(robinie, null), robinie.ukAchsabstandMax);
      expect(robinie.ukAchsabstandMax, const Millimeter(400));
      expect(
        hoechsteFeldbreite(robinie, const Millimeter(350)),
        const Millimeter(350),
      );
      expect(
        hoechsteFeldbreite(robinie, const Millimeter(500)),
        const Millimeter(400),
      );
    });

    test('wirksam: gewählt bis zur höchsten, sonst die höchste', () {
      const h = Millimeter(400);
      expect(wirksameFeldbreite(null, h), h);
      expect(
        wirksameFeldbreite(const Millimeter(300), h),
        const Millimeter(300),
      );
      expect(wirksameFeldbreite(h, h), h);
      expect(wirksameFeldbreite(const Millimeter(500), h), h);
    });

    test('Planungsstand: Vorgabe automatisch, ändern, Grenzen, Gleichheit, '
        'Transport abwärtskompatibel', () {
      expect(f01.feldbreite, isNull);
      final f30 = f01.mitFeldbreite(const Millimeter(300));
      expect(f30.feldbreite, const Millimeter(300));
      expect(f30 == f01, isFalse);
      expect(f30.hashCode == f01.hashCode, isFalse);
      expect(f30.mitFeldbreite(null), f01);
      expect(f30.mitGewerblich(true).feldbreite, const Millimeter(300));
      expect(Planungsstand.feldbreiteGueltig(const Millimeter(100)), isTrue);
      expect(Planungsstand.feldbreiteGueltig(const Millimeter(99)), isFalse);
      expect(Planungsstand.feldbreiteGueltig(const Millimeter(1000)), isTrue);
      expect(Planungsstand.feldbreiteGueltig(const Millimeter(1001)), isFalse);
      expect(
        () => f01.mitFeldbreite(const Millimeter(99)),
        throwsArgumentError,
      );
      expect(Planungsstand.ausBytes(f30.zuBytes()), f30);
      expect(Planungsstand.ausBytes(_alt()).feldbreite, isNull);
      expect(
        Planungsstand.ausBytes(_alt(feldbreite: 350)).feldbreite,
        const Millimeter(350),
      );
    });

    test('Unterbau: Auswahl, wirksam, begrenzt; ohne Belag aus Holz keine', () {
      final hoehen = Hoehenpunkte(hoehen: const [Millimeter(86)]);
      Unterbau u(Planungsstand s, {Artikel? belag, Artikel? uk}) =>
          unterbauFuer(
            s,
            hoehen: hoehen,
            regelwerk: auflagerRegelwerk,
            belag: belag,
            uk: uk,
          );
      final auto = u(f01, belag: _belag);
      expect(auto.feldbreiten, const [
        Millimeter(300),
        Millimeter(350),
        Millimeter(400),
      ]);
      expect(auto.feldbreite, const Millimeter(400));
      expect(auto.feldbreiteBegrenzt, isFalse);
      expect(auto.auflagerabstand, isNull);
      final f35 = u(f01.mitFeldbreite(const Millimeter(350)), belag: _belag);
      expect(f35.feldbreite, const Millimeter(350));
      expect(f35.feldbreiteBegrenzt, isFalse);
      final f40 = u(f01.mitFeldbreite(const Millimeter(400)), belag: _belag);
      expect(f40.feldbreiteBegrenzt, isFalse);
      final f60 = u(
        f01.mitFeldbreite(const Millimeter(600)),
        belag: _belag,
        uk: ukArtikel,
      );
      expect(f60.feldbreite, const Millimeter(400));
      expect(f60.feldbreiteBegrenzt, isTrue);
      expect(f60.feldbreiten, hasLength(3));
      expect(f60.auflagerabstand, const Millimeter(600));
      final ohne = u(f01.mitFeldbreite(const Millimeter(600)));
      expect(ohne.feldbreiten, isEmpty);
      expect(ohne.feldbreite, isNull);
      expect(ohne.feldbreiteBegrenzt, isFalse);
      expect(auto.feldbreiten.clear, throwsUnsupportedError);
      // der UK-Abstand des Belags aus dem Regelwerk zählt, wenn es ihn kennt
      final eng = Regelwerk(
        Artikeldatei(
          quelle: 't',
          version: '1',
          eintraege: [
            Artikeleintrag(artikel: _belag, angaben: const {'Abstand_UK': 350}),
          ],
        ),
      );
      expect(belagFeldbreite(_belag, eng), const Millimeter(350));
      expect(belagFeldbreite(_belag, auflagerRegelwerk), const Millimeter(400));
      expect(belagFeldbreite(_belag, null), const Millimeter(400));
      expect(belagFeldbreite(null, eng), isNull);
      expect(belagFeldbreite(bodenanker, eng), isNull);
    });

    test('Transportformat im Unterbau: hin und zurück', () {
      final b = Berechnung(
        umriss: const [],
        flaeche: 0,
        unterbau: Unterbau(
          feldbreiten: const [Millimeter(300), Millimeter(400)],
          feldbreite: const Millimeter(400),
          feldbreiteBegrenzt: true,
        ),
      );
      final z = Berechnung.ausBytes(b.zuBytes()).unterbau;
      expect(z.feldbreiten, const [Millimeter(300), Millimeter(400)]);
      expect(z.feldbreite, const Millimeter(400));
      expect(z.feldbreiteBegrenzt, isTrue);
      final leer = Berechnung.ausBytes(
        Berechnung(umriss: const [], flaeche: 0).zuBytes(),
      ).unterbau;
      expect(leer.feldbreiten, isEmpty);
      expect(leer.feldbreite, isNull);
      expect(leer.feldbreiteBegrenzt, isFalse);
    });
  });
}
