import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'argument_fehler.dart';

Set<Millimeter> _mm(Iterable<int> werte) => {
  for (final w in werte) Millimeter(w),
};

/// Beispiel einer zweiten Holzart – nur Daten, kein Code (Abnahme M2-08).
const _beispielDaten = <String, Object?>{
  'id': 'beispiel',
  'name': 'Beispielholz',
  'rohdichte_kg_m3': 600,
  'uk_achsabstand_max_mm': 450,
  'uk_achsabstand_empfohlen_mm': 400,
  'zwei_schrauben_ab_mm': 120,
  'serien': [
    {
      'name': 'STANDARD',
      'dielen': {
        'glattkant': {
          'breiten_mm': [90, 140],
          'staerken_mm': [21],
        },
      },
      'lieferlaengen_mm': [3000, 2500],
      'uk_seiten': [
        [
          [40],
          [60],
        ],
      ],
    },
  ],
};

void main() {
  group('Robinie (M2-08, Regelkatalog 14)', () {
    test('Kennwerte', () {
      expect([robinie.id, robinie.name], ['robinie', 'Robinie']);
      expect(robinie.rohdichteKgProM3, 750);
      expect(robinie.ukAchsabstandMax, const Millimeter(400));
      expect(robinie.ukAchsabstandEmpfohlen, const Millimeter(350));
      expect(robinie.zweiSchraubenAb, const Millimeter(100));
      expect(robinie.serien.keys, [basic, ecoSelect, premiumSelect, massiv]);
    });

    test('Dielenstärken (R-A04, B-032): 22 mm gibt es nicht', () {
      expect(
        robinie.serie(basic).dielen[Profil.genutet]!.staerken,
        _mm([21, 26]),
      );
      expect(
        robinie.serie(basic).dielen[Profil.glattkant]!.staerken,
        _mm([21]),
      );
      for (final profil in Profil.values) {
        expect(robinie.serie(ecoSelect).dielen[profil]!.staerken, _mm([23]));
        expect(
          robinie.serie(premiumSelect).dielen[profil]!.staerken,
          _mm([23]),
        );
        expect(robinie.serie(massiv).dielen[profil]!.staerken, _mm([25]));
      }
    });

    test('Dielenbreiten (R-A05)', () {
      final erwartet = {
        (basic, Profil.genutet): [60, 80, 100, 110],
        (basic, Profil.glattkant): [50, 60, 80, 100, 110],
        (ecoSelect, Profil.genutet): [50, 60, 80, 100],
        (ecoSelect, Profil.glattkant): [50, 60, 80, 100, 120],
        (premiumSelect, Profil.genutet): [60, 80, 90, 100, 118],
        (premiumSelect, Profil.glattkant): [60, 80, 100, 118],
        (massiv, Profil.genutet): [50, 60, 70, 80, 90],
        (massiv, Profil.glattkant): [50, 60, 70, 80, 90, 100, 110, 120],
      };
      for (final MapEntry(key: (serie, profil), value: breiten)
          in erwartet.entries) {
        expect(
          robinie.serie(serie).dielen[profil]!.breiten,
          _mm(breiten),
          reason: '${serie.name} ${profil.name}',
        );
      }
    });

    test('Dielenformat gültig (R-A03)', () {
      bool g(Serie s, Profil p, int b, int t) =>
          robinie.serie(s).dielenformatGueltig(p, Millimeter(b), Millimeter(t));
      expect(g(premiumSelect, Profil.genutet, 118, 23), isTrue);
      expect(g(basic, Profil.genutet, 80, 26), isTrue);
      expect(g(basic, Profil.glattkant, 80, 26), isFalse);
      expect(g(premiumSelect, Profil.genutet, 60, 22), isFalse);
      expect(g(ecoSelect, Profil.genutet, 120, 23), isFalse);
    });

    test('Lieferlängen (R-A06, B-035): keine Zwischenlängen', () {
      List<int> l(Serie s) => [
        for (final m in robinie.serie(s).lieferlaengen) m.mm,
      ];
      expect(l(ecoSelect), [4000, 5000, 6000, 7000]);
      expect(l(basic), [4000, 5000, 6000]);
      expect(l(premiumSelect), [4000, 5000, 6000]);
      expect(l(massiv), [800, 1200, 1600, 2000]);
    });

    test('Befestigung (R-B01 B-094, R-B02 B-090)', () {
      Befestigung b(Serie s, Profil p, int breite) =>
          robinie.serie(s).befestigung(p, Millimeter(breite));
      for (final serie in robinie.serien.keys) {
        expect(b(serie, Profil.genutet, 99), Befestigung.clipFixx);
        expect(
          b(serie, Profil.glattkant, 60),
          Befestigung.verschraubungVonOben,
        );
      }
      expect(b(premiumSelect, Profil.genutet, 100), Befestigung.duoClipFixx);
      expect(b(premiumSelect, Profil.genutet, 118), Befestigung.duoClipFixx);
      expect(b(ecoSelect, Profil.genutet, 100), Befestigung.clipFixx);
      expect(b(basic, Profil.genutet, 110), Befestigung.clipFixx);
    });

    test('Schrauben je Punkt: Clip 1, DUO 2, von oben ab 100 mm 2', () {
      int s(Serie serie, Profil p, int breite) =>
          robinie.schraubenJePunkt(serie, p, Millimeter(breite));
      expect(s(ecoSelect, Profil.genutet, 80), 1);
      expect(s(premiumSelect, Profil.genutet, 100), 2);
      expect(s(ecoSelect, Profil.glattkant, 99), 1);
      expect(s(ecoSelect, Profil.glattkant, 100), 2);
      expect(s(ecoSelect, Profil.glattkant, 120), 2);
    });

    test('UK-Formate (R-A08: B-034, B-212), tauschbar', () {
      UkFormat u(Serie s, int a, int b) =>
          robinie.serie(s).ukFormat(Millimeter(a), Millimeter(b));
      for (final (a, b) in [(45, 40), (40, 45), (45, 60), (60, 45)]) {
        expect(u(basic, a, b), UkFormat.gueltig, reason: '$a×$b');
      }
      expect(u(basic, 45, 80), UkFormat.ungueltig);
      expect(u(basic, 40, 60), UkFormat.ungueltig);
      expect(u(premiumSelect, 45, 60), UkFormat.gueltig);
      expect(u(premiumSelect, 70, 45), UkFormat.gueltig);
      expect(u(premiumSelect, 45, 100), UkFormat.ungueltig);
      expect(u(massiv, 40, 40), UkFormat.gueltig);
      expect(u(massiv, 100, 60), UkFormat.gueltig);
      expect(u(massiv, 80, 90), UkFormat.ungueltig);
      for (final a in [40, 60]) {
        for (final b in [40, 60, 80, 90, 100]) {
          expect(u(massiv, a, b), UkFormat.gueltig, reason: 'MASSIV $a×$b');
        }
      }
      expect(u(massiv, 40, 70), UkFormat.ungueltig);
      for (final g in [40, 60, 80, 90, 100]) {
        expect(u(ecoSelect, 40, g), UkFormat.gueltig);
        expect(u(ecoSelect, g, 40), UkFormat.gueltig);
      }
      for (final (a, b) in [(60, 60), (80, 60), (60, 80), (90, 90)]) {
        expect(u(ecoSelect, a, b), UkFormat.ungetrocknet, reason: '$a×$b');
      }
      for (final (a, b) in [
        (60, 90),
        (100, 60),
        (90, 80),
        (90, 100),
        (40, 120),
      ]) {
        expect(u(ecoSelect, a, b), UkFormat.ungueltig, reason: '$a×$b');
      }
    });

    test('Gewicht nach Rechengewicht 750 kg/m³ (R-A12)', () {
      // 60 × 23 mm × 5 m × 750 kg/m³ = 5,175 kg
      expect(
        robinie.gewicht(
          const Millimeter(60),
          const Millimeter(23),
          const Millimeter(5000),
        ),
        const Gramm(5175),
      );
    });

    test('unbekannte Serie wird abgelehnt', () {
      expect(
        () => robinie.serie(const Serie('GOLD')),
        wirftArgumentFehler('serie', 'GOLD', 'keine Serie von Robinie'),
      );
    });

    test('Daten sind unveränderlich', () {
      final eco = robinie.serie(ecoSelect);
      expect(
        () => eco.lieferlaengen.add(const Millimeter(1)),
        throwsUnsupportedError,
      );
      expect(eco.dielen.clear, throwsUnsupportedError);
      expect(eco.ukSeiten.clear, throwsUnsupportedError);
      expect(eco.ukUngetrocknet.clear, throwsUnsupportedError);
      expect(
        () => eco.dielen[Profil.genutet]!.breiten.clear(),
        throwsUnsupportedError,
      );
      expect(
        () => eco.dielen[Profil.genutet]!.staerken.clear(),
        throwsUnsupportedError,
      );
      expect(robinie.serien.clear, throwsUnsupportedError);
    });
  });

  group('Zweite Holzart nur über Daten (Abnahme M2-08)', () {
    final beispiel = Holzart.ausJson(_beispielDaten);
    const standard = Serie('STANDARD');

    test('wird gelesen und gerechnet wie Robinie', () {
      expect(
        [beispiel.id, beispiel.name, beispiel.rohdichteKgProM3],
        ['beispiel', 'Beispielholz', 600],
      );
      expect(beispiel.ukAchsabstandMax, const Millimeter(450));
      final regeln = beispiel.serie(standard);
      expect(regeln.lieferlaengen, [
        const Millimeter(2500),
        const Millimeter(3000),
      ], reason: 'aufsteigend sortiert');
      expect(regeln.dielen.keys, [Profil.glattkant]);
      expect(
        regeln.dielenformatGueltig(
          Profil.genutet,
          const Millimeter(90),
          const Millimeter(21),
        ),
        isFalse,
        reason: 'Profil nicht vorhanden',
      );
      expect(
        regeln.dielenformatGueltig(
          Profil.glattkant,
          const Millimeter(140),
          const Millimeter(21),
        ),
        isTrue,
      );
      expect(regeln.ukUngetrocknet, isEmpty);
      expect(regeln.duoClipAb, isNull);
      expect(
        regeln.ukFormat(const Millimeter(60), const Millimeter(40)),
        UkFormat.gueltig,
      );
      expect(
        beispiel.schraubenJePunkt(
          standard,
          Profil.glattkant,
          const Millimeter(119),
        ),
        1,
      );
      expect(
        beispiel.schraubenJePunkt(
          standard,
          Profil.glattkant,
          const Millimeter(120),
        ),
        2,
      );
      expect(
        beispiel.gewicht(
          const Millimeter(100),
          const Millimeter(20),
          const Millimeter(1000),
        ),
        const Gramm(1200),
      );
      expect(() => beispiel.serie(premiumSelect), throwsArgumentError);
    });

    test('Holzart braucht Serien und stimmige Achsabstände', () {
      expect(
        () => Holzart.ausJson({..._beispielDaten, 'serien': <Object?>[]}),
        wirftArgumentFehler('serien', 'beispiel', 'Holzart ohne Serie'),
      );
      expect(
        () => Holzart.ausJson({
          ..._beispielDaten,
          'uk_achsabstand_empfohlen_mm': 451,
        }),
        wirftArgumentFehler(
          'ukAchsabstandEmpfohlen',
          451,
          'größer als der höchste Achsabstand',
        ),
      );
      expect(
        Holzart.ausJson({..._beispielDaten, 'uk_achsabstand_empfohlen_mm': 450})
            .ukAchsabstandEmpfohlen,
        const Millimeter(450),
      );
    });
  });
}
