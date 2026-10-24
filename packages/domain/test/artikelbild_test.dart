import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

void main() {
  test('aufbereitete Bilder sind immer WebP', () {
    expect(artikelbildDatei('Diele_60x23.jpg'), 'Diele_60x23.webp');
    expect(artikelbildDatei('RELO_V_02.webp'), 'RELO_V_02.webp');
    expect(artikelbildDatei('a.b.png'), 'a.b.webp');
    expect(artikelbildDatei('ohne_endung'), 'ohne_endung.webp');
    expect(artikelbildDatei('.webp'), '.webp.webp');
  });

  test('Adresse liegt unter artikelbilder/ und ist kodiert', () {
    expect(artikelbilderPfad, 'artikelbilder');
    expect(
      artikelbildAdresse('_86A6024Clipschraube 4,2x28mm TX20web.webp'),
      'artikelbilder/_86A6024Clipschraube%204%2C2x28mm%20TX20web.webp',
    );
    expect(
      artikelbildAdresse('4251236413041.webp'),
      'artikelbilder/4251236413041.webp',
    );
  });
}
