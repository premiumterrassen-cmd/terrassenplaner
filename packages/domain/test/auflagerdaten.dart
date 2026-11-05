import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Artikeldaten wie die Upload-Datei (Auszug, neutrale Titel): eine
/// Robinien-UK 40 × 60 mit Stelzfüßen privat/gewerblich und Unterlegpads,
/// Abstand der Stelzfüße 60 cm (M6-08, M6-11).
Artikel _artikel(
  String nummer,
  String titel,
  Artikelart art, {
  int inhalt = 1,
}) => Artikel(
  nummer: Artikelnummer(nummer),
  titel: titel,
  art: art,
  einheit: Verkaufseinheit(
    inhalt == 1 ? Mengeneinheit.stueck : Mengeneinheit.karton,
    inhalt: inhalt,
  ),
);

final ukArtikel = Artikel(
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

final pad2 = _artikel('50-60-004', 'Unterleger 2 mm', Artikelart.pad);
final pad5 = _artikel('50-60-005', 'Unterleger 5 mm', Artikelart.pad);
final pad8 = _artikel('50-60-006', 'Unterleger 8 mm', Artikelart.pad);
final keil14 = _artikel('50-40-001', 'Keil 14-22', Artikelart.stellfuss);
final keil18 = _artikel('50-40-003', 'Keil 18-32', Artikelart.stellfuss);
final fuss35 = _artikel(
  '60-55-110',
  'Fuß 35-55 (10)',
  Artikelart.stellfuss,
  inhalt: 10,
);
final fuss35gross = _artikel(
  '60-55-130',
  'Fuß 35-55 (30)',
  Artikelart.stellfuss,
  inhalt: 30,
);
final fuss55 = _artikel(
  '60-55-136',
  'Fuß 55-95 (20)',
  Artikelart.stellfuss,
  inhalt: 20,
);
final fuss80 = _artikel(
  '60-57-009',
  'Fuß 80-200 (5)',
  Artikelart.stellfuss,
  inhalt: 5,
);

/// Ein Stellfuß ohne Höhenangabe – zählt nicht als Auflager.
final ohneHoehe = _artikel('70-10-001', 'Fuß ohne Höhe', Artikelart.stellfuss);
final bodenanker = _artikel('70-20-001', 'Bodenanker L', Artikelart.bodenanker);

Artikeleintrag _mitHoehe(Artikel a, int von, int bis) =>
    Artikeleintrag(artikel: a, angaben: {'MinHoehe': von, 'MaxHoehe': bis});

/// Regelwerk der Testdaten; gewerblich ohne die Keile.
final auflagerRegelwerk = Regelwerk(
  Artikeldatei(
    quelle: 'test',
    version: '1',
    eintraege: [
      Artikeleintrag(
        artikel: ukArtikel,
        verweise: {
          Beziehung.stellfussPrivat.spalte: [
            keil14.nummer,
            keil18.nummer,
            fuss35.nummer,
            fuss55.nummer,
            fuss35gross.nummer,
            fuss80.nummer,
            ohneHoehe.nummer,
          ],
          Beziehung.stellfussGewerblich.spalte: [
            fuss35.nummer,
            fuss55.nummer,
            fuss80.nummer,
          ],
          Beziehung.unterlegpads.spalte: [
            pad2.nummer,
            pad5.nummer,
            pad8.nummer,
            keil14.nummer,
          ],
        },
        angaben: const {'Abstand_Stelzfuesse': 600, 'Abstand_UK': 400},
      ),
      _mitHoehe(pad2, 2, 2),
      _mitHoehe(pad5, 5, 5),
      _mitHoehe(pad8, 8, 8),
      _mitHoehe(keil14, 14, 22),
      _mitHoehe(keil18, 18, 32),
      _mitHoehe(fuss35, 35, 55),
      _mitHoehe(fuss35gross, 35, 55),
      _mitHoehe(fuss55, 55, 95),
      _mitHoehe(fuss80, 80, 200),
      Artikeleintrag(artikel: ohneHoehe),
      Artikeleintrag(artikel: bodenanker),
    ],
  ),
);
