import 'dart:io';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

Artikeleintrag _mitBildern(String nummer, List<String> bilder) =>
    Artikeleintrag(
      artikel: Artikel(
        nummer: Artikelnummer(nummer),
        titel: nummer,
        art: Artikelart.sonstiges,
        einheit: Verkaufseinheit(Mengeneinheit.stueck),
        bilder: bilder,
      ),
    );

void main() {
  late Directory a;
  late Directory b;

  setUp(() {
    a = Directory.systemTemp.createTempSync('bilder_a');
    b = Directory.systemTemp.createTempSync('bilder_b');
    for (final (ordner, name) in [
      (a, 'diele.jpg'),
      (a, 'clip.webp'),
      (b, 'clip.webp'),
      (b, 'uk.webp'),
      (b, 'diele.webp'),
    ]) {
      File('${ordner.path}/$name').writeAsStringSync(name);
    }
  });
  tearDown(() {
    a.deleteSync(recursive: true);
    b.deleteSync(recursive: true);
  });

  test('sucht jedes Bild einmal, der erste Ordner gilt', () {
    final datei = Artikeldatei(
      quelle: 'q',
      version: 'v',
      eintraege: [
        _mitBildern('1', ['diele.jpg', 'clip.webp']),
        _mitBildern('2', ['clip.webp', 'uk.webp', 'fehlt.webp']),
        _mitBildern('3', ['diele.webp', 'fehlt.webp', 'auch_weg.png']),
      ],
    );
    final plan = planeArtikelbilder(datei, [a.path, b.path]);
    expect(plan.quellen, {
      'diele.webp': '${a.path}/diele.jpg',
      'clip.webp': '${a.path}/clip.webp',
      'uk.webp': '${b.path}/uk.webp',
    });
    expect(plan.fehlend, ['fehlt.webp', 'auch_weg.png']);
    expect(plan.mehrdeutig, ['diele.jpg / diele.webp']);
    expect(plan.quellen.clear, throwsUnsupportedError);
    expect(plan.fehlend.clear, throwsUnsupportedError);
    expect(plan.mehrdeutig.clear, throwsUnsupportedError);
  });

  test('fehlende Quelle macht den Namen nicht mehrdeutig', () {
    final datei = Artikeldatei(
      quelle: 'q',
      version: 'v',
      eintraege: [
        _mitBildern('1', ['uk.png', 'uk.webp']),
      ],
    );
    final plan = planeArtikelbilder(datei, [a.path, b.path]);
    expect(plan.quellen, {'uk.webp': '${b.path}/uk.webp'});
    expect(
      [plan.fehlend, plan.mehrdeutig],
      [
        ['uk.png'],
        isEmpty,
      ],
    );
  });

  test('cwebp: WebP, Qualität 80, nur verkleinern, ohne Metadaten', () {
    expect(artikelbildBreite, 800);
    expect(cwebpArgumente('ein.jpg', 'aus.webp'), [
      '-quiet',
      '-q',
      '80',
      '-resize',
      '800',
      '0',
      '-resize_mode',
      'down_only',
      '-metadata',
      'none',
      'ein.jpg',
      '-o',
      'aus.webp',
    ]);
  });
}
