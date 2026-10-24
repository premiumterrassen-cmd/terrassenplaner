import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

Artikel _diele({
  Serie serie = premiumSelect,
  Profil profil = Profil.genutet,
  Oberseite oberseite = Oberseite.glatt,
}) => Artikel(
  nummer: const Artikelnummer('10-10-073-R'),
  titel: 'Diele',
  art: Artikelart.diele,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  holzart: robinie,
  serie: serie,
  profil: profil,
  oberseite: oberseite,
);

final _clip = Artikel(
  nummer: const Artikelnummer('80-10-001'),
  titel: 'Clip',
  art: Artikelart.clip,
  einheit: Verkaufseinheit(Mengeneinheit.stueck),
);

void main() {
  test('leerer Filter passt auf alles', () {
    const filter = Artikelfilter();
    expect([filter.passt(_diele()), filter.passt(_clip)], [true, true]);
    expect(filter.alsJson(), isEmpty);
  });

  test('jedes Feld filtert für sich', () {
    final diele = _diele();
    for (final (filter, erwartet) in [
      (const Artikelfilter(bereich: Bereich.belag), true),
      (const Artikelfilter(bereich: Bereich.befestigung), false),
      (const Artikelfilter(art: Artikelart.diele), true),
      (const Artikelfilter(art: Artikelart.systemdiele), false),
      (const Artikelfilter(holzart: 'robinie'), true),
      (const Artikelfilter(holzart: 'kastanie'), false),
      (const Artikelfilter(serie: premiumSelect), true),
      (const Artikelfilter(serie: basic), false),
      (const Artikelfilter(profil: Profil.genutet), true),
      (const Artikelfilter(profil: Profil.glattkant), false),
      (const Artikelfilter(oberseite: Oberseite.glatt), true),
      (const Artikelfilter(oberseite: Oberseite.bombiert), false),
    ]) {
      expect(filter.passt(diele), erwartet, reason: '${filter.alsJson()}');
    }
    expect(const Artikelfilter(holzart: 'robinie').passt(_clip), isFalse);
  });

  test('Rundreise über JSON', () {
    const filter = Artikelfilter(
      bereich: Bereich.belag,
      art: Artikelart.diele,
      holzart: 'robinie',
      serie: ecoSelect,
      profil: Profil.glattkant,
      oberseite: Oberseite.bombiert,
    );
    final json = filter.alsJson();
    expect(json, {
      'bereich': 'belag',
      'art': 'diele',
      'holzart': 'robinie',
      'serie': 'ECO SELECT',
      'profil': 'glattkant',
      'oberseite': 'bombiert',
    });
    expect(Artikelfilter.ausJson(json).alsJson(), json);
    expect(Artikelfilter.ausJson(const {}).alsJson(), isEmpty);
    expect(
      () => Artikelfilter.ausJson(const {'profil': 'rund'}),
      throwsArgumentError,
    );
  });
}
