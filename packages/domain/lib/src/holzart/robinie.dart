import 'holzart.dart';

/// Robinie als Holzart – reine Daten (M2-08). Quellen: Sortimentsmatrix
/// 2027_07 (B-030), B-032 bis B-036, B-094, B-150, B-212, Antworten Alexander
/// 19.10.2026 (Regelkatalog `docs/fachkonzept/14-planungsregeln.md`).
/// Nur Serien, keine Werke oder Herkunft (B-020).
const robinieDaten = <String, Object?>{
  'id': 'robinie',
  'name': 'Robinie',
  // R-A12: Rechengewicht wie die ERP-Plugins.
  'rohdichte_kg_m3': 750,
  // R-C01: max. 40 cm, sicherer unter 35 cm.
  'uk_achsabstand_max_mm': 400,
  'uk_achsabstand_empfohlen_mm': 350,
  // R-B02: ab 100 mm zwei Schrauben je Auflager.
  'zwei_schrauben_ab_mm': 100,
  'serien': [
    {
      'name': 'BASIC',
      'dielen': {
        'genutet': {
          'breiten_mm': [60, 80, 100, 110],
          'staerken_mm': [21, 26],
        },
        'glattkant': {
          'breiten_mm': [50, 60, 80, 100, 110],
          'staerken_mm': [21],
        },
      },
      'lieferlaengen_mm': [4000, 5000, 6000],
      'uk_seiten': [
        [
          [45],
          [40, 60],
        ],
      ],
    },
    {
      'name': 'ECO SELECT',
      'dielen': {
        'genutet': {
          'breiten_mm': [50, 60, 80, 100],
          'staerken_mm': [23],
        },
        'glattkant': {
          'breiten_mm': [50, 60, 80, 100, 120],
          'staerken_mm': [23],
        },
      },
      'lieferlaengen_mm': [4000, 5000, 6000, 7000],
      // B-212: getrocknet nur mit 40 mm auf einer Seite.
      'uk_seiten': [
        [
          [40],
          [40, 60, 80, 90, 100],
        ],
      ],
      'uk_ungetrocknet': [
        [60, 60],
        [60, 80],
        [90, 90],
      ],
    },
    {
      'name': 'PREMIUM SELECT',
      'dielen': {
        'genutet': {
          'breiten_mm': [60, 80, 90, 100, 118],
          'staerken_mm': [23],
        },
        'glattkant': {
          'breiten_mm': [60, 80, 100, 118],
          'staerken_mm': [23],
        },
      },
      'lieferlaengen_mm': [4000, 5000, 6000],
      'uk_seiten': [
        [
          [45],
          [60, 70],
        ],
      ],
      // B-094: genutete PREMIUM SELECT ab 100 mm mit DUO-CLIP-FIXX.
      'duo_clip_ab_mm': 100,
    },
    {
      'name': 'MASSIV',
      'dielen': {
        'genutet': {
          'breiten_mm': [50, 60, 70, 80, 90],
          'staerken_mm': [25],
        },
        'glattkant': {
          'breiten_mm': [50, 60, 70, 80, 90, 100, 110, 120],
          'staerken_mm': [25],
        },
      },
      'lieferlaengen_mm': [800, 1200, 1600, 2000],
      'uk_seiten': [
        [
          [40, 60],
          [40, 60, 80, 90, 100],
        ],
      ],
    },
  ],
};

/// Robinie – die Holzart zum Go-Live (Alexander, 19.10.2026).
final robinie = Holzart.ausJson(robinieDaten);

/// Serien der Robinie.
const basic = Serie('BASIC');
const ecoSelect = Serie('ECO SELECT');
const premiumSelect = Serie('PREMIUM SELECT');
const massiv = Serie('MASSIV');
