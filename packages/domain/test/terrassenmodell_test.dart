import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'argument_fehler.dart';

List<Bauteil> _terrasse({int laenge = 4000, int breite = 3000}) =>
    rechteckTerrasse(
      laenge: Millimeter(laenge),
      breite: Millimeter(breite),
      dielenbreite: const Millimeter(120),
      dielenstaerke: const Millimeter(23),
      ukBreite: const Millimeter(70),
      ukHoehe: const Millimeter(45),
      ukAchsabstand: const Millimeter(400),
    );

List<int> _mm(Iterable<Bauteil> teile, Millimeter Function(Quader) wert) => [
  for (final t in teile) wert(t.quader).mm,
];

void main() {
  test('Unterkonstruktion bündig an den Stirnseiten, höchstens 400 mm', () {
    final uk = _terrasse()
        .where((t) => t.art == Bauteilart.unterkonstruktion)
        .toList();
    // 3930 mm Spannweite / 400 → 10 Felder → 11 Lagen
    expect(uk.length, 11);
    expect(_mm(uk, (q) => q.x), [
      for (var i = 0; i <= 10; i++) (3930 * i / 10).round(),
    ]);
    final q = uk.first.quader;
    expect(
      [q.y.mm, q.z.mm, q.laenge.mm, q.hoehe.mm, q.breite.mm],
      [0, 0, 70, 45, 3000],
    );
    expect(uk.last.quader.x.mm + 70, 4000);
  });

  test('genau ein Feld bei Spannweite gleich Achsabstand', () {
    final uk = _terrasse(laenge: 470)
        .where((t) => t.art == Bauteilart.unterkonstruktion);
    expect(_mm(uk, (q) => q.x), [0, 400]);
  });

  test('Dielen mit 5 mm Fuge, letzte auf Restbreite', () {
    final dielen = _terrasse(breite: 500)
        .where((t) => t.art == Bauteilart.diele)
        .toList();
    // 0, 125, 250, 375 → letzte 125 mm breit verfügbar, Diele 120
    expect(_mm(dielen, (q) => q.z), [0, 125, 250, 375]);
    expect(_mm(dielen, (q) => q.breite), [120, 120, 120, 120]);
    final schmal = _terrasse(breite: 300)
        .where((t) => t.art == Bauteilart.diele)
        .toList();
    expect(_mm(schmal, (q) => q.z), [0, 125, 250]);
    expect(_mm(schmal, (q) => q.breite), [120, 120, 50]);
    final q = dielen.first.quader;
    expect([q.x.mm, q.y.mm, q.laenge.mm, q.hoehe.mm], [0, 45, 4000, 23]);
    expect(fuge, const Millimeter(5));
  });

  test('genau passende Breite ohne Reststück', () {
    final dielen = _terrasse(breite: 245)
        .where((t) => t.art == Bauteilart.diele);
    expect(_mm(dielen, (q) => q.breite), [120, 120]);
  });

  test('Ergebnis ist unveränderlich', () {
    expect(_terrasse().clear, throwsUnsupportedError);
  });

  test('ungültige Maße', () {
    expect(
      () => _terrasse(laenge: 70),
      wirftArgumentFehler('laenge', 70, 'muss größer als die UK-Breite sein'),
    );
    expect(
      () => rechteckTerrasse(
        laenge: const Millimeter(1000),
        breite: const Millimeter(1000),
        dielenbreite: const Millimeter(120),
        dielenstaerke: const Millimeter(23),
        ukBreite: const Millimeter(70),
        ukHoehe: const Millimeter(45),
        ukAchsabstand: const Millimeter(0),
      ),
      wirftArgumentFehler('ukAchsabstand', 0, 'muss größer als 0 sein'),
    );
    expect(
      () => _terrasse(laenge: 50),
      wirftArgumentFehler('laenge', 50, 'muss größer als die UK-Breite sein'),
    );
    expect(
      () => rechteckTerrasse(
        laenge: const Millimeter(1000),
        breite: const Millimeter(1000),
        dielenbreite: const Millimeter(120),
        dielenstaerke: const Millimeter(23),
        ukBreite: const Millimeter(70),
        ukHoehe: const Millimeter(45),
        ukAchsabstand: const Millimeter(-400),
      ),
      wirftArgumentFehler('ukAchsabstand', -400, 'muss größer als 0 sein'),
    );
    expect(
      () => _terrasse(breite: 0),
      wirftArgumentFehler('breite', 0, 'muss größer als 0 sein'),
    );
  });

  test('Quader verlangt positive Ausdehnung', () {
    Quader quader({int l = 1, int h = 1, int b = 1}) => Quader(
      x: const Millimeter(-5),
      y: const Millimeter(0),
      z: const Millimeter(0),
      laenge: Millimeter(l),
      hoehe: Millimeter(h),
      breite: Millimeter(b),
    );
    expect(quader().x, const Millimeter(-5));
    for (final (name, q) in [
      ('laenge', () => quader(l: 0)),
      ('hoehe', () => quader(h: -1)),
      ('breite', () => quader(b: 0)),
    ]) {
      expect(
        q,
        wirftArgumentFehler(
          name,
          name == 'hoehe' ? -1 : 0,
          'muss größer als 0 sein',
        ),
      );
    }
  });
}
