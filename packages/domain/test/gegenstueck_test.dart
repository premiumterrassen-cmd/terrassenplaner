import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

Artikel _diele(
  String nummer, {
  Profil? profil = Profil.genutet,
  int breite = 80,
  int staerke = 23,
  Serie serie = premiumSelect,
  Oberseite oberseite = Oberseite.glatt,
  Artikelart art = Artikelart.diele,
}) => Artikel(
  nummer: Artikelnummer(nummer),
  titel: 'Diele $nummer',
  art: art,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: Millimeter(breite),
    staerke: Millimeter(staerke),
  ),
  holzart: robinie,
  serie: serie,
  profil: profil,
  oberseite: oberseite,
);

Regelwerk _regelwerk(List<Artikel> artikel) => Regelwerk(
  Artikeldatei(
    quelle: 'test',
    version: '1',
    eintraege: [for (final a in artikel) Artikeleintrag(artikel: a)],
  ),
);

void main() {
  group('Gegenstück (Planungskern v6 Regel 4.4)', () {
    final genutet = _diele('10-10-046-R', oberseite: Oberseite.bombiert);
    final glatt = _diele('10-10-044-R', profil: Profil.glattkant);

    test('gleiche Serie und Breite, anderes Profil – in beide Richtungen', () {
      final r = _regelwerk([genutet, glatt]);
      expect(gegenstueck(r, genutet), glatt);
      expect(gegenstueck(r, glatt), genutet);
    });

    test('andere Serie, Breite, Art oder ohne Profil passt nicht', () {
      final r = _regelwerk([
        genutet,
        _diele('1', profil: Profil.glattkant, serie: ecoSelect),
        _diele('2', profil: Profil.glattkant, breite: 60),
        _diele('3', profil: Profil.glattkant, art: Artikelart.systemdiele),
        _diele('4', profil: null),
        _diele('6'),
      ]);
      expect(gegenstueck(r, genutet), isNull);
      expect(gegenstueck(r, _diele('7', profil: null)), isNull);
    });

    test('mehrere: gleiche Stärke vor gleicher Oberseite vor Reihenfolge', () {
      final dick = _diele(
        '1',
        profil: Profil.glattkant,
        staerke: 26,
        oberseite: Oberseite.bombiert,
      );
      final glattDuenn = _diele('2', profil: Profil.glattkant);
      final bombiert = _diele(
        '3',
        profil: Profil.glattkant,
        oberseite: Oberseite.bombiert,
      );
      final zweiter = _diele(
        '4',
        profil: Profil.glattkant,
        oberseite: Oberseite.bombiert,
      );
      expect(
        gegenstueck(_regelwerk([genutet, dick, glattDuenn]), genutet),
        glattDuenn,
      );
      expect(
        gegenstueck(_regelwerk([genutet, dick, glattDuenn, bombiert]), genutet),
        bombiert,
      );
      expect(
        gegenstueck(_regelwerk([genutet, bombiert, zweiter]), genutet),
        bombiert,
      );
      expect(gegenstueck(_regelwerk([genutet, dick]), genutet), dick);
    });
  });
}
