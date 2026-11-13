import 'dart:convert';
import 'dart:io';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'paritaet_daten.dart';

/// Paritätsnachweis (M10-01): Alle Referenzkonfigurationen (M1-03) und
/// alle rechenbaren Referenzfälle (M1-02) werden im neuen Planer
/// (`PlanungsDienst.berechnePlanung`) gerechnet und mit den Ergebnissen
/// des alten Planers verglichen. Jede Abweichung braucht eine Begründung
/// aus [_gruende] – eine neue oder verschwundene Abweichung lässt den Test
/// scheitern. Bericht: `docs/abnahme/paritaetsbericht.md`.
const _gruende = {
  'B-035':
      'nur Lieferlängen 4/5/6 m; Zwischen- und Überlängen des alten '
      'Planers gibt es nicht (R-A06)',
  'Fuge':
      'Fuge 6 mm statt 5 mm (R-B06): Reihen = Breite + 6 mm, z. B. 47 statt '
      '48 Reihen auf 309 cm – Planungskern v6 / Entscheidung Alexander '
      '11.11.2026',
  'Befestigung':
      'Anfangs- und Enddiele sichtbar verschraubt, Clips = übrige '
      'Kreuzungen + 5 % (Fachkonzept 2.6) – Planungskern v6 / Entscheidung '
      'Alexander 11.11.2026',
  'R-B09': 'Freidielen nach der Staffel ab 25 Dielen (B-079, B-228)',
  'M4-07': 'Kreisfläche exakt π·r² statt Vieleck',
  'Fehler': 'Fehler des alten Planers (fehlerverdacht, Fachkonzept 09)',
  'UK-Lage':
      'Lage der UK-Linien (Fachkonzept 08: F10 24 statt 25 Hölzer, '
      'F20 zwei Stücke à 353 cm ohne Holz; 2794 alt enger als 40 cm)',
  'Treppe': 'Treppenkonstruktion und Treppendielen (Fachkonzept 05, M7-05)',
  'Varianten': 'Verschnittvariante 2 ohne 5,5 m (Fachkonzept 07)',
  'Reste':
      'kurze UK-Stücke aus den Resten der langen (M10-01) – neu '
      'weniger UK-Holz als alt',
  'Stützen':
      'eine Stütze je Auflager (M6-11: 91 wie die 91 Bodenanker; '
      'der alte Export schneidet nur 63)',
  'Rechenweg':
      'Verschnitt mit Teilflächen: alter Rechenweg nicht '
      'nachvollziehbar (Fachkonzept 2.7)',
  'Eingaben':
      'Unterlage unvollständig: Nutzungsart, Terrassenart oder '
      'Verblendungsseiten nicht erfasst (Querstücke, Stützen, Blendenhalter)',
  'Rand-UK':
      'Planungsregeln 3.3 (Rand-UK): an jeder Kante mit Dielenenden eine '
      'UK – Rand-UK, wo keine UK-Linie höchstens 6 cm daneben liegt '
      '(schräge Ränder, Ausschnitte, Innenecken, Bögen); Stücke und '
      'Lieferlängen anders als im alten Planer, Dielenenden darauf befestigt',
  'Planungskern v6':
      'Planungskern v6 / Musterverfahren R-B17: höchstens 3 Stücke je '
      'Diele, 5 mm Sägeschnitt, Reste ab 30 cm, bei höchstens 1 % '
      'Mehrlänge die Verteilung mit den wenigsten Dielen (z. B. 152 Stücke '
      'mit Stoß durch A bei 135° brauchen mindestens 51 Dielen und damit '
      'nach der Staffel R-B09 2 Freidielen)',
  'Planungskern v7':
      'Planungskern v7 Regel 9.3 / R-B18 (Verlegemuster): Verband nur, wenn '
      'die Fläche länger als eine Diele ist (F06/F07: 480 cm ohne Stoß, '
      'also ohne Doppel-UK), Wechselverband unregelmäßig mit Stücken ab '
      '40 cm (F12); jede benutzte Stoßlinie mit Doppel-UK',
  'Planungskern v11':
      'Planungskern v11 / Regel 13.1.1 (R-D11): die Rinne RELO V liegt '
      'innen an der Kante, der Belag endet 15,7 cm (Profil 15,1 cm und '
      '6 mm Fuge) statt der Artikelbreite 12 cm vor der Kante '
      '(F38: 480 × 293,3 cm = 14,078 m²)',
  'Frage 2': 'offen: vorhandene UK – alt 2 × 473 cm zusätzlich',
  'Frage 3': 'offen: Alu-UK – Anzahl der Schienen',
};

/// Abweichungen der Referenzkonfigurationen: Fall → Größe → Grund.
const _konfigurationen = <String, Map<String, String>>{
  'F01': {'Dielen': 'Fuge'},
  'F02': {'Dielen': 'Fuge'},
  'F03': {'Verschnitt': 'B-035', 'Dielen': 'B-035', 'UK': 'Rand-UK'},
  // Stöße bei 135° am Rand statt durch A (Alexander 13.11.2026): 85 statt
  // 152 Stücke, damit wieder 1 Freidiele wie im alten Planer
  'F04': {
    'Verschnitt': 'B-035',
    'Dielen': 'B-035',
    'UK': 'Rand-UK',
    'Clips': 'Befestigung',
  },
  'F05': {'Verschnitt': 'Fuge', 'Dielen': 'B-035', 'UK': 'Rand-UK'},
  'F06': {
    'Dielen': 'Fuge',
    'UK': 'Planungskern v7',
    'Clips': 'Planungskern v7',
  },
  'F07': {
    'Dielen': 'Fuge',
    'UK': 'Planungskern v7',
    'Clips': 'Planungskern v7',
  },
  'F08': {'Dielen': 'Fuge'},
  'F09': {'Dielen': 'Fuge'},
  'F10': {'Dielen': 'Fuge', 'UK': 'UK-Lage', 'Clips': 'Befestigung'},
  'F11': {'Dielen': 'Fuge'},
  'F12': {
    'Dielen': 'Planungskern v7',
    'UK': 'Planungskern v7',
    'Clips': 'Planungskern v7',
  },
  'F13': {'Dielen': 'Fuge', 'Freidielen': 'R-B09', 'UK': 'B-035'},
  'F14': {
    'Verschnitt': 'Fehler',
    'Dielen': 'Fehler',
    'Freidielen': 'Fehler',
    'UK': 'Fehler',
  },
  'F15': {'Verschnitt': 'B-035', 'Dielen': 'B-035', 'UK': 'Rand-UK'},
  'F16': {
    'Verschnitt': 'B-035',
    'Dielen': 'B-035',
    'Freidielen': 'R-B09',
    'UK': 'Rand-UK',
  },
  'F17': {
    'Verschnitt': 'B-035',
    'Dielen': 'B-035',
    'Freidielen': 'R-B09',
    'UK': 'Rand-UK',
  },
  'F18': {
    'Verschnitt': 'B-035',
    'Dielen': 'B-035',
    'UK': 'Rand-UK',
    'Clips': 'Rand-UK',
  },
  'F19': {
    'Fläche': 'M4-07',
    'Verschnitt': 'B-035',
    'Dielen': 'B-035',
    'UK': 'Rand-UK',
  },
  'F20': {'Dielen': 'Fuge', 'UK': 'UK-Lage'},
  'F21': {'Verschnitt': 'Rechenweg', 'Dielen': 'Fuge', 'UK': 'Rand-UK'},
  'F22': {
    'Verschnitt': 'Rechenweg',
    'Dielen': 'B-035',
    'UK': 'Rand-UK',
    'Clips': 'Rand-UK',
  },
  'F23': {'Dielen': 'Fuge'},
  'F24': {'Freidielen': 'R-B09'},
  'F26': {'Dielen': 'Fuge'},
  'F27': {'Dielen': 'Fuge'},
  'F28': {'Dielen': 'Fuge', 'UK': 'Stützen'},
  'F29': {'Dielen': 'Fuge', 'UK': 'Frage 2'},
  'F30': {'Dielen': 'Fuge'},
  'F31': {'Dielen': 'Fuge', 'UK': 'Reste'},
  'F32': {'Dielen': 'Fuge'},
  'F33': {'Dielen': 'Fuge', 'UK': 'Reste'},
  'F34': {'Dielen': 'Fuge'},
  'F35': {'Dielen': 'Fuge'},
  'F36': {'Dielen': 'Fuge'},
  'F37': {'Dielen': 'Fuge'},
  'F38': {'Fläche': 'Planungskern v11', 'Dielen': 'Fuge'},
  'F39': {'Verschnitt': 'Treppe', 'Dielen': 'Treppe', 'UK': 'Treppe'},
  'F40': {'Verschnitt': 'Fehler', 'Dielen': 'Fehler', 'UK': 'Fehler'},
  'F41': {'Verschnitt': 'Treppe', 'Dielen': 'Treppe', 'UK': 'Treppe'},
  'F42': {'Verschnitt': 'Treppe', 'Dielen': 'Treppe', 'UK': 'Treppe'},
  'F43': {'Verschnitt': 'Varianten', 'Dielen': 'Varianten'},
};

/// Abweichungen der rechenbaren Referenzfälle: Fall → Größe → Grund.
const _faelle = <String, Map<String, String>>{
  '2025-08-26-719-v2': {'Dielen': 'Fuge', 'UK': 'Eingaben'},
  '2026-04-13-1946-v6': {'Dielen': 'Fehler', 'UK': 'Fehler'},
  '2026-04-28-4413-v11': {'Dielen': 'B-035', 'UK': 'Frage 3'},
  '2026-04-28-859-v5': {'Dielen': 'B-035', 'UK': 'Frage 3'},
  '2026-04-29-164-v4': {'Dielen': 'Fehler', 'UK': 'Fehler'},
  '2026-04-29-2412-v5': {'Dielen': 'Fuge', 'UK': 'Eingaben'},
  '2026-05-03-347-v4': {'Dielen': 'Fuge', 'UK': 'Eingaben'},
  '2026-05-03-4381-v2': {'Dielen': 'B-035', 'UK': 'B-035'},
  '2026-05-12-1823-v4': {'Dielen': 'Fuge', 'UK': 'Eingaben'},
  '2026-05-19-3958-v4': {'Dielen': 'B-035'},
  '2026-05-28-4655-v2': {'Dielen': 'Fuge'},
  '2026-06-07-4340-v4': {'Dielen': 'B-035', 'UK': 'Rand-UK'},
  '2026-06-11-3389-v3': {'Dielen': 'B-035'},
  '2026-06-15-1093-v7': {'Dielen': 'B-035', 'UK': 'Eingaben'},
  '2026-06-25-1275-v3': {'Dielen': 'B-035', 'UK': 'B-035'},
  '2026-06-30-2295-v5': {'Dielen': 'Fuge', 'UK': 'Frage 3'},
  '2026-07-07-2794-v2': {'Dielen': 'B-035', 'UK': 'UK-Lage'},
  '2026-07-31-3374-v3': {'Dielen': 'B-035', 'UK': 'Eingaben'},
  '2026-07-31-3374-v5': {'Dielen': 'B-035', 'UK': 'Eingaben'},
  '2026-08-06-2810-v3': {'Dielen': 'Fuge', 'UK': 'Eingaben'},
  '2026-08-26-1067-v2': {'Dielen': 'B-035', 'UK': 'Frage 3'},
};

/// Seite 1 nennt „Waagrecht“, die Zeichnung zeigt senkrecht (M1-02).
const _senkrecht = {'2026-05-03-347-v4', '2026-06-30-2295-v5'};

void main() {
  test('jede Begründung ist erklärt', () {
    for (final abweichungen in [
      ..._konfigurationen.values,
      ..._faelle.values,
    ]) {
      expect(_gruende.keys, containsAll(abweichungen.values.toSet()));
    }
  });

  group('Referenzkonfigurationen (M1-03)', () {
    for (var i = 1; i <= 43; i++) {
      final id = 'F${i.toString().padLeft(2, '0')}';
      test('$id: gleich oder begründet', () {
        final f = Referenzkonfiguration.ausJson(
          jsonDecode(
            File('../domain/test/referenzkonfigurationen/$id.json')
                .readAsStringSync(),
          ) as Map<String, Object?>,
        );
        final abweichungen = Vergleichswerte.alt(f)
            .abweichungen(rechneKonfiguration(f));
        expect(
          abweichungen.keys.toSet(),
          (_konfigurationen[id] ?? const {}).keys.toSet(),
          reason: '$id: $abweichungen',
        );
        // Fälle mit Fehler des alten Planers sind nie Sollwert
        if (!f.istSollwert && abweichungen.isNotEmpty) {
          expect(_konfigurationen[id]!.values, contains('Fehler'));
        }
      });
    }
  });

  group('Referenzfälle (M1-02)', () {
    final dateien =
        Directory('../domain/test/referenzfaelle')
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('.json'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    final faelle = [
      for (final d in dateien)
        jsonDecode(d.readAsStringSync()) as Map<String, Object?>,
    ];

    test('26 rechenbar (Rechteck, passende L-/T-Form ohne Ausschnitt), '
        '21 nicht (Freiform, Ausschnitt, Rundung, unvollständige Maße)', () {
      final rechenbar = [
        for (final j in faelle)
          if (grundrissAus(Referenzfall.ausJson(j).grundriss) != null) j,
      ];
      expect(faelle, hasLength(47));
      expect(rechenbar, hasLength(26));
    });

    for (final json in faelle) {
      final f = Referenzfall.ausJson(json);
      final grundriss = grundrissAus(f.grundriss);
      if (grundriss == null) continue;
      test('${f.id}: gleich oder begründet', () {
        final neu = fallNeu(
          f,
          json['eingaben']! as Map<String, Object?>,
          grundriss,
          richtung: _senkrecht.contains(f.id)
              ? Verlegerichtung.senkrecht
              : null,
          art: f.id == '2026-05-03-4381-v2'
              ? Verlegeart.drittelverband
              : Verlegeart.fugenschnitt,
        );
        final abweichungen = fallAbweichungen(fallAlt(f), neu);
        expect(
          abweichungen.keys.toSet(),
          (_faelle[f.id] ?? const {}).keys.toSet(),
          reason: '${f.id}: $abweichungen',
        );
      });
    }
  });
}
