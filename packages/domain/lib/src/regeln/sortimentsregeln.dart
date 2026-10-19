/// Ausführbare Sortiments- und Planungsregeln aus dem Firmenwissen (M1-04,
/// Regelkatalog `docs/fachkonzept/14-planungsregeln.md`). Nur Serien, keine
/// Werke oder Herkunft (B-020).
library;

/// Serien der Robinien-Terrassendielen (Sortimentsmatrix 2027_07, B-030).
enum Serie { basic, ecoSelect, premiumSelect, massiv }

/// Kantenprofil der Diele.
enum Profil {
  /// Beidseitig genutet für die verdeckte Befestigung.
  genutet,

  /// Ohne Nut, sichtbar von oben verschraubt.
  glattkant,
}

/// Befestigungsart der Diele auf der Unterkonstruktion (R-B01, R-B02).
enum Befestigung { clipFixx, duoClipFixx, verschraubungVonOben }

/// Ob ein UK-Format zur Serie gehört (R-A08).
enum UkFormat {
  /// Technisch getrocknet (KD), regulär im Sortiment.
  gueltig,

  /// Nur ungetrocknet lieferbar (B-212).
  ungetrocknet,

  /// Nicht im Sortiment.
  ungueltig,
}

/// Höchster UK-Achsabstand in mm (R-C01, Montagehinweise Regel 3).
const ukAchsabstandMaxMm = 400;

/// Empfohlener UK-Achsabstand in mm („sicherer unter 35 cm“, R-C01).
const ukAchsabstandEmpfohlenMm = 350;

/// Abstand der Querstreben (Leiterverband) in mm (R-C03, Alexander).
const querstrebenAbstandMm = 600;

/// Fuge zwischen zwei Dielen in mm (R-B06, Alexander).
const fugeMm = 5;

/// Ab dieser Dielenzahl gibt es Freidielen (R-B09, B-079).
const freidielenAbDielen = 25;

/// Dielenstärken je Serie und Profil in mm (R-A04, B-032, Matrix Z. 10/15).
Set<int> dielenstaerkenMm(Serie serie, Profil profil) => switch (serie) {
  Serie.basic => profil == Profil.genutet ? const {21, 26} : const {21},
  Serie.ecoSelect || Serie.premiumSelect => const {23},
  Serie.massiv => const {25},
};

/// Dielenbreiten je Serie und Profil in mm (R-A05, Matrix Z. 9/14, B-036,
/// B-174).
Set<int> dielenbreitenMm(Serie serie, Profil profil) => switch ((
  serie,
  profil,
)) {
  (Serie.basic, Profil.genutet) => const {60, 80, 100, 110},
  (Serie.basic, Profil.glattkant) => const {50, 60, 80, 100, 110},
  (Serie.ecoSelect, Profil.genutet) => const {50, 60, 80, 100},
  (Serie.ecoSelect, Profil.glattkant) => const {50, 60, 80, 100, 120},
  (Serie.premiumSelect, Profil.genutet) => const {60, 80, 90, 100, 118},
  (Serie.premiumSelect, Profil.glattkant) => const {60, 80, 100, 118},
  (Serie.massiv, Profil.genutet) => const {50, 60, 70, 80, 90},
  (Serie.massiv, Profil.glattkant) => const {50, 60, 70, 80, 90, 100, 110, 120},
};

/// Ob Breite × Stärke in der Serie mit diesem Profil existiert (R-A03).
bool dielenformatGueltig(
  Serie serie,
  Profil profil,
  int breiteMm,
  int staerkeMm,
) =>
    dielenbreitenMm(serie, profil).contains(breiteMm) &&
    dielenstaerkenMm(serie, profil).contains(staerkeMm);

/// Lieferlängen je Serie in mm (R-A06, B-035, B-036).
List<int> lieferlaengenMm(Serie serie) => switch (serie) {
  Serie.ecoSelect => const [4000, 5000, 6000, 7000],
  Serie.basic || Serie.premiumSelect => const [4000, 5000, 6000],
  Serie.massiv => const [800, 1200, 1600, 2000],
};

/// Stärke aus Altdaten: „22 mm“ gibt es nicht, gemeint ist 21 mm (R-A04,
/// B-032).
int normierteStaerkeMm(int staerkeMm) => staerkeMm == 22 ? 21 : staerkeMm;

/// Befestigung einer Diele (R-B01: B-094, B-150; R-B02: B-090).
Befestigung befestigung(Serie serie, Profil profil, int breiteMm) {
  if (profil == Profil.glattkant) return Befestigung.verschraubungVonOben;
  return serie == Serie.premiumSelect && breiteMm >= 100
      ? Befestigung.duoClipFixx
      : Befestigung.clipFixx;
}

/// Schrauben je Befestigungspunkt: CLIP-FIXX 1, DUO-CLIP-FIXX 2, von oben
/// verschraubt ab 100 mm Breite 2, sonst 1 (R-B01, R-B02).
int schraubenJePunkt(Serie serie, Profil profil, int breiteMm) =>
    switch (befestigung(serie, profil, breiteMm)) {
      Befestigung.clipFixx => 1,
      Befestigung.duoClipFixx => 2,
      Befestigung.verschraubungVonOben => breiteMm >= 100 ? 2 : 1,
    };

/// UK-Maße je Serie als zwei Seiten (eine Seite aus jeder Menge; Matrix
/// Z. 18/19, B-034). ECO SELECT folgt B-212 und steht in [ukFormat].
const _ukSeiten = {
  Serie.basic: ({45}, {40, 60}),
  Serie.premiumSelect: ({45}, {60, 70}),
  Serie.massiv: ({40, 60}, {40, 60, 80, 90, 100}),
};

/// Prüft ein UK-Format; Breite und Stärke sind tauschbar (R-A08: B-034,
/// B-212).
UkFormat ukFormat(Serie serie, int aMm, int bMm) {
  final (klein, gross) = aMm <= bMm ? (aMm, bMm) : (bMm, aMm);
  if (serie == Serie.ecoSelect) {
    // B-212: getrocknet nur mit 40 mm auf einer Seite; drei Formate nur
    // ungetrocknet; 60×90, 60×100, 90×80, 90×100 entfallen.
    if (klein == 40 && const {40, 60, 80, 90, 100}.contains(gross)) {
      return UkFormat.gueltig;
    }
    return const {(60, 60), (60, 80), (90, 90)}.contains((klein, gross))
        ? UkFormat.ungetrocknet
        : UkFormat.ungueltig;
  }
  final (seiteA, seiteB) = _ukSeiten[serie]!;
  final passt =
      (seiteA.contains(klein) && seiteB.contains(gross)) ||
      (seiteA.contains(gross) && seiteB.contains(klein));
  return passt ? UkFormat.gueltig : UkFormat.ungueltig;
}
