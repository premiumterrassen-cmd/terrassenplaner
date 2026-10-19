import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

void main() {
  group('Konstanten (R-C01, R-C03, R-B06, R-B09)', () {
    test('UK-Achsabstand max. 40 cm, empfohlen unter 35 cm', () {
      expect(ukAchsabstandMaxMm, 400);
      expect(ukAchsabstandEmpfohlenMm, 350);
    });
    test('Querstreben alle 60 cm, Fuge 5 mm, Freidielen ab 25 Dielen', () {
      expect([querstrebenAbstandMm, fugeMm, freidielenAbDielen], [600, 5, 25]);
    });
  });

  group('Freidielen (R-B09) und Wandabstand (R-C10)', () {
    test('Staffel: ab 25 eine, ab 50 zwei, ab 100 je 50 eine mehr', () {
      final faelle = {
        0: 0,
        24: 0,
        25: 1,
        49: 1,
        50: 2,
        99: 2,
        100: 3,
        149: 3,
        150: 4,
        199: 4,
        200: 5,
        586: 12,
      };
      for (final MapEntry(:key, :value) in faelle.entries) {
        expect(freidielen(key), value, reason: '$key Dielen');
      }
    });
    test('Wandabstand 2 cm', () => expect(wandabstandMm, 20));
  });

  group('Dielenstärken (R-A04, B-032)', () {
    test('BASIC 21/26 genutet, glattkant nur 21', () {
      expect(dielenstaerkenMm(Serie.basic, Profil.genutet), {21, 26});
      expect(dielenstaerkenMm(Serie.basic, Profil.glattkant), {21});
    });
    test('ECO und PREMIUM SELECT 23, MASSIV 25 – je Profil gleich', () {
      for (final profil in Profil.values) {
        expect(dielenstaerkenMm(Serie.ecoSelect, profil), {23});
        expect(dielenstaerkenMm(Serie.premiumSelect, profil), {23});
        expect(dielenstaerkenMm(Serie.massiv, profil), {25});
      }
    });
    test('22 mm gibt es nicht – Altdaten werden zu 21 mm', () {
      expect(normierteStaerkeMm(22), 21);
      expect([21, 23, 25, 26].map(normierteStaerkeMm), [21, 23, 25, 26]);
      for (final serie in Serie.values) {
        for (final profil in Profil.values) {
          expect(dielenstaerkenMm(serie, profil), isNot(contains(22)));
        }
      }
    });
  });

  group('Dielenbreiten (R-A05)', () {
    const erwartet = {
      (Serie.basic, Profil.genutet): {60, 80, 100, 110},
      (Serie.basic, Profil.glattkant): {50, 60, 80, 100, 110},
      (Serie.ecoSelect, Profil.genutet): {50, 60, 80, 100},
      (Serie.ecoSelect, Profil.glattkant): {50, 60, 80, 100, 120},
      (Serie.premiumSelect, Profil.genutet): {60, 80, 90, 100, 118},
      (Serie.premiumSelect, Profil.glattkant): {60, 80, 100, 118},
      (Serie.massiv, Profil.genutet): {50, 60, 70, 80, 90},
      (Serie.massiv, Profil.glattkant): {50, 60, 70, 80, 90, 100, 110, 120},
    };
    for (final MapEntry(key: (serie, profil), value: breiten)
        in erwartet.entries) {
      test('${serie.name} ${profil.name}', () {
        expect(dielenbreitenMm(serie, profil), breiten);
      });
    }
  });

  group('Dielenformat gültig (R-A03)', () {
    test('Formate aus der Matrix', () {
      expect(
        dielenformatGueltig(Serie.premiumSelect, Profil.genutet, 118, 23),
        isTrue,
      );
      expect(dielenformatGueltig(Serie.basic, Profil.genutet, 80, 26), isTrue);
      expect(
        dielenformatGueltig(Serie.massiv, Profil.glattkant, 120, 25),
        isTrue,
      );
    });
    test('falsche Breite oder Stärke', () {
      expect(
        dielenformatGueltig(Serie.basic, Profil.glattkant, 80, 26),
        isFalse,
        reason: 'BASIC 26 mm nur genutet',
      );
      expect(
        dielenformatGueltig(Serie.premiumSelect, Profil.genutet, 60, 22),
        isFalse,
        reason: '22 mm gibt es nicht',
      );
      expect(
        dielenformatGueltig(Serie.ecoSelect, Profil.genutet, 120, 23),
        isFalse,
        reason: 'ECO 120 nur glattkant',
      );
    });
  });

  group('Lieferlängen (R-A06, B-035)', () {
    test('ECO SELECT bis 7 m, BASIC und PREMIUM bis 6 m', () {
      expect(lieferlaengenMm(Serie.ecoSelect), [4000, 5000, 6000, 7000]);
      expect(lieferlaengenMm(Serie.basic), [4000, 5000, 6000]);
      expect(lieferlaengenMm(Serie.premiumSelect), [4000, 5000, 6000]);
    });
    test('MASSIV Längenmix', () {
      expect(lieferlaengenMm(Serie.massiv), [800, 1200, 1600, 2000]);
    });
  });

  group('Befestigung (R-B01 B-094, R-B02 B-090)', () {
    test('genutet unter 100 mm: CLIP-FIXX, 1 Schraube', () {
      for (final serie in Serie.values) {
        expect(befestigung(serie, Profil.genutet, 99), Befestigung.clipFixx);
        expect(schraubenJePunkt(serie, Profil.genutet, 80), 1);
      }
    });
    test('PREMIUM SELECT genutet ab 100 mm: DUO-CLIP-FIXX, 2 Schrauben', () {
      expect(
        befestigung(Serie.premiumSelect, Profil.genutet, 100),
        Befestigung.duoClipFixx,
      );
      expect(
        befestigung(Serie.premiumSelect, Profil.genutet, 118),
        Befestigung.duoClipFixx,
      );
      expect(schraubenJePunkt(Serie.premiumSelect, Profil.genutet, 100), 2);
    });
    test('ECO und BASIC genutet 100 mm: CLIP-FIXX', () {
      expect(
        befestigung(Serie.ecoSelect, Profil.genutet, 100),
        Befestigung.clipFixx,
      );
      expect(
        befestigung(Serie.basic, Profil.genutet, 100),
        Befestigung.clipFixx,
      );
    });
    test('glattkant: von oben verschraubt, ab 100 mm 2 Schrauben', () {
      expect(
        befestigung(Serie.ecoSelect, Profil.glattkant, 60),
        Befestigung.verschraubungVonOben,
      );
      expect(schraubenJePunkt(Serie.ecoSelect, Profil.glattkant, 99), 1);
      expect(schraubenJePunkt(Serie.ecoSelect, Profil.glattkant, 100), 2);
    });
  });

  group('UK-Formate (R-A08: B-034, B-212)', () {
    test('BASIC 45 × 40/60, tauschbar', () {
      for (final (a, b) in [(45, 40), (40, 45), (45, 60), (60, 45)]) {
        expect(ukFormat(Serie.basic, a, b), UkFormat.gueltig, reason: '$a×$b');
      }
      expect(ukFormat(Serie.basic, 45, 80), UkFormat.ungueltig);
      expect(ukFormat(Serie.basic, 40, 60), UkFormat.ungueltig);
    });
    test('PREMIUM SELECT 45 × 60/70', () {
      expect(ukFormat(Serie.premiumSelect, 45, 60), UkFormat.gueltig);
      expect(ukFormat(Serie.premiumSelect, 70, 45), UkFormat.gueltig);
      expect(ukFormat(Serie.premiumSelect, 45, 100), UkFormat.ungueltig);
    });
    test('MASSIV 40/60 × 40–100', () {
      expect(ukFormat(Serie.massiv, 40, 40), UkFormat.gueltig);
      expect(ukFormat(Serie.massiv, 100, 60), UkFormat.gueltig);
      expect(ukFormat(Serie.massiv, 80, 90), UkFormat.ungueltig);
      expect(ukFormat(Serie.massiv, 60, 120), UkFormat.ungueltig);
    });
    test('ECO SELECT getrocknet nur mit 40 mm auf einer Seite', () {
      for (final g in [40, 60, 80, 90, 100]) {
        expect(ukFormat(Serie.ecoSelect, 40, g), UkFormat.gueltig);
        expect(ukFormat(Serie.ecoSelect, g, 40), UkFormat.gueltig);
      }
      expect(ukFormat(Serie.ecoSelect, 40, 120), UkFormat.ungueltig);
    });
    test('ECO SELECT 60×60, 60×80, 90×90 nur ungetrocknet', () {
      for (final (a, b) in [(60, 60), (80, 60), (60, 80), (90, 90)]) {
        expect(
          ukFormat(Serie.ecoSelect, a, b),
          UkFormat.ungetrocknet,
          reason: '$a×$b',
        );
      }
    });
    test('ECO SELECT entfallen: 60×90, 60×100, 90×80, 90×100', () {
      for (final (a, b) in [(60, 90), (100, 60), (90, 80), (90, 100)]) {
        expect(
          ukFormat(Serie.ecoSelect, a, b),
          UkFormat.ungueltig,
          reason: '$a×$b',
        );
      }
    });
  });
}
