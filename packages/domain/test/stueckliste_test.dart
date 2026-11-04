import 'dart:convert';
import 'dart:io';

import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

const _uk = Artikelnummer('50-10-001');
const _diele = Artikelnummer('10-10-073-R');

Planstueck _stueck(
  int laenge, {
  Artikelnummer nummer = _uk,
  int ganz = 2000,
  Stuecklage lage = Stuecklage.laengs,
}) => Planstueck(
  nummer,
  'Artikel ${nummer.wert}',
  Millimeter(laenge),
  ganzeLaenge: Millimeter(ganz),
  lage: lage,
);

void main() {
  group('Stückfarbe (M9-04)', () {
    test('rot ganze Länge, blau zugeschnitten, grün quer', () {
      expect(_stueck(2000).farbe, Stueckfarbe.rot);
      expect(_stueck(1999).farbe, Stueckfarbe.blau);
      expect(_stueck(2000, lage: Stuecklage.quer).farbe, Stueckfarbe.gruen);
      expect(_stueck(350, lage: Stuecklage.quer).farbe, Stueckfarbe.gruen);
    });

    test('Nummern und Farbwerte', () {
      expect([for (final f in Stueckfarbe.values) f.nummer], [0, 1, 2]);
      expect(
        [for (final f in Stueckfarbe.values) f.argb],
        [0xFFD32F2F, 0xFF1976D2, 0xFF388E3C],
      );
      for (final f in Stueckfarbe.values) {
        expect(Stueckfarbe.ausNummer(f.nummer), f);
      }
      expect(
        () => Stueckfarbe.ausNummer(3),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            'unbekannte Stückfarbe: 3',
          ),
        ),
      );
    });

    test('Regel gegen die UK-Stücklisten der Referenzfälle (M1-02)', () {
      // Längsstücke: rot in der ganzen Länge des Artikels – UK-Holz 6000 mm
      // (die 6500 mm des alten Planers gibt es nicht, B-035), Alu-Schienen
      // in ihrer Lieferlänge; grüne Stücke sind Querstücke.
      var geprueft = 0;
      for (final datei in Directory('test/referenzfaelle').listSync()) {
        final json = jsonDecode(
          File(datei.path).readAsStringSync(),
        ) as Map<String, Object?>;
        final erwartet = json['erwartet']! as Map<String, Object?>;
        final ganz = <String, num>{};
        for (final z in erwartet['zuschnitt_unterkonstruktion']! as List) {
          final m = z as Map<String, Object?>;
          final artikel = m['artikel']! as String;
          final laenge = m['ausgangslaenge_cm']! as num;
          ganz[artikel] = artikel.startsWith('Unterkonstruktionsholz')
              ? 600
              : laenge > (ganz[artikel] ?? 0)
              ? laenge
              : ganz[artikel]!;
        }
        for (final r in erwartet['unterkonstruktion_stueckliste']! as List) {
          final m = r as Map<String, Object?>;
          final artikel = m['artikel']! as String;
          final farbe = m['farbe']! as String;
          if (!ganz.containsKey(artikel)) continue;
          final stueck = Planstueck(
            const Artikelnummer('x'),
            artikel,
            Millimeter.ausCm(m['laenge_cm']! as num),
            ganzeLaenge: Millimeter.ausCm(ganz[artikel]!),
            lage: farbe == 'green' ? Stuecklage.quer : Stuecklage.laengs,
          );
          expect(
            stueck.farbe.name,
            {'red': 'rot', 'blue': 'blau', 'green': 'gruen'}[farbe],
            reason: '${json['id']} ${m['laenge_cm']} cm',
          );
          geprueft++;
        }
      }
      expect(geprueft, greaterThan(150));
    });
  });

  group('Stückliste (M9-04)', () {
    test('wie die Planungsunterlage 2026-04-28-4413: 200 rot, 87 blau, '
        '36/35/33 grün', () {
      final liste = Stueckliste.aus([
        for (var i = 0; i < 4; i++) _stueck(330, lage: Stuecklage.quer),
        for (var i = 0; i < 12; i++) _stueck(870),
        for (var i = 0; i < 5; i++) _stueck(360, lage: Stuecklage.quer),
        for (var i = 0; i < 12; i++) _stueck(2000),
        for (var i = 0; i < 8; i++) _stueck(350, lage: Stuecklage.quer),
      ]);
      expect(
        [for (final z in liste.zeilen) (z.laenge.cm, z.stueck, z.farbe.name)],
        [
          (200, 12, 'rot'),
          (87, 12, 'blau'),
          (36, 5, 'gruen'),
          (35, 8, 'gruen'),
          (33, 4, 'gruen'),
        ],
      );
      expect(liste.zeilen.first.titel, 'Artikel 50-10-001');
      expect(liste.zeilen.first.nummer, _uk);
      expect(liste.istLeer, isFalse);
    });

    test('Artikel in der Reihenfolge ihres ersten Stücks', () {
      final liste = Stueckliste.aus([
        _stueck(4800, nummer: _diele, ganz: 5000),
        _stueck(2000),
        _stueck(5000, nummer: _diele, ganz: 5000),
        _stueck(4800, nummer: _diele, ganz: 5000),
      ]);
      expect(
        [for (final z in liste.zeilen) '$z'],
        [
          '1 × 5000 mm 10-10-073-R (rot)',
          '2 × 4800 mm 10-10-073-R (blau)',
          '1 × 2000 mm 50-10-001 (rot)',
        ],
      );
      expect(Stueckliste.aus(const []).istLeer, isTrue);
    });

    test('Gleichheit', () {
      Stuecklistenzeile zeile([int stueck = 2]) => Stuecklistenzeile(
        nummer: _uk,
        titel: 'T',
        laenge: const Millimeter(870),
        stueck: stueck,
        farbe: Stueckfarbe.blau,
      );
      expect(zeile(), zeile());
      expect(zeile().hashCode, zeile().hashCode);
      expect(zeile(), isNot(zeile(3)));
      expect(zeile(), isNot(Object()));
      expect(Stueckliste([zeile()]), Stueckliste([zeile()]));
      expect(Stueckliste([zeile()]).hashCode, Stueckliste([zeile()]).hashCode);
      expect(Stueckliste([zeile()]), isNot(Stueckliste([zeile(3)])));
      expect(Stueckliste([zeile()]), isNot(Stueckliste.leer));
      expect(Stueckliste.leer, isNot(Object()));
      expect(
        () => Stueckliste([zeile()]).zeilen.add(zeile()),
        throwsUnsupportedError,
      );
    });

    test('Transport und in der Berechnung auf Platz 61/62', () {
      final liste = Stueckliste.aus([
        _stueck(2000),
        _stueck(870),
        _stueck(350, lage: Stuecklage.quer),
      ]);
      final fbb = fb.Builder();
      fbb.finish(liste.schreibe(fbb));
      final puffer = fb.BufferContext.fromBytes(fbb.buffer);
      expect(Stueckliste.lies(puffer, puffer.derefObject(0)), liste);

      final b = Berechnung(
        umriss: const [],
        flaeche: 1,
        stueckliste: liste,
        stueckfarben: const [Stueckfarbe.blau, Stueckfarbe.rot],
      );
      final zurueck = Berechnung.ausBytes(b.zuBytes());
      expect(zurueck.stueckliste, liste);
      expect(zurueck.stueckfarben, [Stueckfarbe.blau, Stueckfarbe.rot]);
      final kopie = b.mitPlanung(2);
      expect(kopie.stueckliste, liste);
      expect(kopie.stueckfarben, b.stueckfarben);
      // ältere Puffer ohne die Plätze: leer
      final alt = fb.Builder()..startTable(0);
      alt.finish(alt.endTable());
      final ohne = Berechnung.ausBytes(alt.buffer);
      expect(ohne.stueckliste, Stueckliste.leer);
      expect(ohne.stueckfarben, isEmpty);
      // fehlende Felder einer Zeile
      final leer = fb.Builder();
      leer.startTable(0);
      final z = leer.endTable();
      final zeilen = leer.writeList([z]);
      leer
        ..startTable(1)
        ..addOffset(0, zeilen);
      leer.finish(leer.endTable());
      final p = fb.BufferContext.fromBytes(leer.buffer);
      expect(
        Stueckliste.lies(p, p.derefObject(0)).zeilen.single,
        const Stuecklistenzeile(
          nummer: Artikelnummer(''),
          titel: '',
          laenge: Millimeter(0),
          stueck: 0,
          farbe: Stueckfarbe.rot,
        ),
      );
    });
  });
}
