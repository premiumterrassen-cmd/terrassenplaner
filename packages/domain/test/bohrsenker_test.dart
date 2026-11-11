import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

Artikel _artikel(String nummer, String titel, Artikelart art) => Artikel(
  nummer: Artikelnummer(nummer),
  titel: titel,
  art: art,
  einheit: Verkaufseinheit(Mengeneinheit.stueck),
  preisBrutto: const Cent(2290),
);

final _bohrsenker = _artikel(
  '50-80-008',
  'ALTO Bohrsenker (5,5mm Bohrdurchmesser)',
  Artikelart.werkzeug,
);
final _clip = _artikel('80-10-001-50', 'CLIP-FIXX', Artikelart.clip);
final _schraube = _artikel(
  '50-50-101',
  'Terrassenschrauben',
  Artikelart.schraube,
);
final _pad = _artikel('50-20-002', 'Pad', Artikelart.pad);
// „Bohrsenker“ im Titel, aber kein Werkzeug: zählt nicht
final _set = _artikel('50-80-007', 'Bohrsenker-Set', Artikelart.sonstiges);
// Werkzeug ohne „Bohrsenker“ im Titel: zählt nicht
final _bit = _artikel('50-80-003', 'Bit TX25', Artikelart.werkzeug);

Regelwerk _regelwerk(List<Artikel> artikel) => Regelwerk(
  Artikeldatei(
    quelle: 'test',
    version: '1',
    eintraege: [for (final a in artikel) Artikeleintrag(artikel: a)],
  ),
);

void main() {
  group('Bohrsenker optional (Planungskern v6 Regel 4.5)', () {
    final regelwerk = _regelwerk([
      _set,
      _bit,
      _clip,
      _schraube,
      _pad,
      _bohrsenker,
    ]);

    test(
      'ein Stück, optional, einmal je Planung – zu Clips oder Schrauben',
      () {
        for (final befestigung in [_clip, _schraube]) {
          final b = bohrsenkerAngebot(regelwerk, [
            Materialbedarf([_pad], 4),
            Materialbedarf([befestigung], 10),
          ])!;
          expect(b.einheiten, [_bohrsenker]);
          expect(b.stueck, 1);
          expect(b.zusatz, Materialzusatz.optional);
          expect(b.jePlanung, isTrue);
        }
      },
    );

    test('nicht ohne Befestigung, nicht wenn fest gewählt, nicht ohne '
        'Artikel', () {
      expect(bohrsenkerAngebot(regelwerk, const []), isNull);
      expect(
        bohrsenkerAngebot(regelwerk, [
          Materialbedarf([_pad], 4),
        ]),
        isNull,
      );
      expect(
        bohrsenkerAngebot(regelwerk, [
          Materialbedarf([_clip], 0),
        ]),
        isNull,
      );
      expect(
        bohrsenkerAngebot(regelwerk, [
          Materialbedarf([_clip], 10),
          Materialbedarf([_bohrsenker], 1, jePlanung: true),
        ]),
        isNull,
      );
      expect(
        bohrsenkerAngebot(_regelwerk([_set, _bit, _clip]), [
          Materialbedarf([_clip], 10),
        ]),
        isNull,
      );
      expect(
        bohrsenkerAngebot(null, [
          Materialbedarf([_clip], 10),
        ]),
        isNull,
      );
    });
  });
}
