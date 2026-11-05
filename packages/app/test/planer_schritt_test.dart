import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

void main() {
  test('sieben Schritte in der Reihenfolge des alten Planers', () {
    expect(
      [for (final s in PlanerSchritt.values) '${s.nummer}. ${s.titel(de)}'],
      [
        '1. GRUNDRISS',
        '2. TERRASSENBELAG',
        '3. UNTERKONSTRUKTION',
        '4. TERRASSENANSCHLUSS',
        '5. TREPPEN',
        '6. ZUBEHÖR',
        '7. VERSCHNITTOPTIMIERUNG',
      ],
    );
    expect(
      [for (final s in PlanerSchritt.values) s.unterpunkte(de).length],
      [4, 6, 9, 3, 1, 8, 1],
    );
  });

  test('getrennte Titel für schmale Stationen', () {
    expect(
      [for (final s in PlanerSchritt.values) s.getrennterTitel(de)],
      [
        'GRUNDRISS',
        'TERRASSEN-\nBELAG',
        'UNTER-\nKONSTRUKTION',
        'TERRASSEN-\nANSCHLUSS',
        'TREPPEN',
        'ZUBEHÖR',
        'VERSCHNITT-\nOPTIMIERUNG',
      ],
    );
  });

  test('alle Unterpunkte im Wortlaut', () {
    expect(
      {for (final s in PlanerSchritt.values) s.name: s.unterpunkte(de)},
      {
        'grundriss': [
          'Terrassenform auswählen',
          'Terrassenmaße',
          'Ecken und Seiten abrunden',
          'Ausschnitte und Teilflächen',
        ],
        'terrassenbelag': [
          'Terrassenbelag auswählen',
          'Dielenlänge automatisch ermitteln',
          'Verlegearten',
          'Verlegerichtungen',
          'Ausgangspunkt des Belags',
          'Befestigungsart',
        ],
        'unterkonstruktion': [
          'Art der Terrasse',
          'Höhenpunkte',
          'Unterkonstruktion auswählen',
          'Länge der Unterkonstruktion',
          'Untergrund',
          'Art der Terrassennutzung',
          'Querstreben',
          'Nutzung privat oder gewerblich',
          'Auflagen',
        ],
        'terrassenanschluss': [
          'Angrenzende Bauelemente',
          'Verblendung',
          'Entwässerungsrinnen',
        ],
        'treppen': ['Treppen'],
        'zubehoer': [
          'Allgemein',
          'Anlieferung',
          'Clips & Schrauben',
          'Höhenausgleich',
          'Pads & EPDM-Bänder',
          'Rhombusleisten',
          'Terrassenfliesen',
          'Terrassenöl RIBOL',
        ],
        'verschnittoptimierung': ['Verschnittvariante auswählen'],
      },
    );
  });

  test('Unterpunkte nummeriert', () {
    expect(PlanerSchritt.grundriss.nummerierteUnterpunkte(de), [
      '1.1 Terrassenform auswählen',
      '1.2 Terrassenmaße',
      '1.3 Ecken und Seiten abrunden',
      '1.4 Ausschnitte und Teilflächen',
    ]);
    expect(
      PlanerSchritt.unterkonstruktion.nummerierteUnterpunkte(de).last,
      '3.9 Auflagen',
    );
    expect(
      PlanerSchritt.zubehoer.nummerierteUnterpunkte(de).last,
      '6.8 Terrassenöl RIBOL',
    );
  });

  test('ohne Nutzungsart bei Hochterrasse und vorhandener UK '
      'lückenlos nummeriert (M6-01)', () {
    const start = Planungsstand.start;
    for (final art in Terrassenart.values) {
      final stand = start.mitTerrassenart(art);
      final punkte = PlanerSchritt.unterkonstruktion.sichtbareUnterpunkte(
        de,
        stand,
      );
      expect(punkte.length, art.mitNutzungsart ? 9 : 8, reason: art.name);
      expect(
        PlanerSchritt.unterkonstruktion.entfaellt(5, stand),
        !art.mitNutzungsart,
      );
      // andere Schritte und Unterpunkte entfallen nie
      for (final s in PlanerSchritt.values) {
        for (var i = 0; i < s.unterpunkte(de).length; i++) {
          if (s == PlanerSchritt.unterkonstruktion && i == 5) continue;
          expect(s.entfaellt(i, stand), isFalse);
        }
      }
    }
    final ohne = PlanerSchritt.unterkonstruktion.sichtbareUnterpunkte(
      de,
      start.mitTerrassenart(Terrassenart.vorhandeneUk),
    );
    expect([for (final p in ohne) p.index], [0, 1, 2, 3, 4, 6, 7, 8]);
    expect(ohne[5].text, '3.6 Querstreben');
    expect(ohne[6].text, '3.7 Nutzung privat oder gewerblich');
    expect(ohne.last.text, '3.8 Auflagen');
  });

  test('Zustand: Auswahl, besuchte Stationen, Fortschritt', () {
    final zustand = RahmenZustand();
    var meldungen = 0;
    zustand.addListener(() => meldungen++);
    expect(zustand.aktiv, PlanerSchritt.grundriss);
    expect(zustand.besucht, {PlanerSchritt.grundriss});
    expect(zustand.fortschritt, closeTo(1 / 7, 1e-9));
    zustand
      ..waehle(PlanerSchritt.treppen)
      ..waehle(PlanerSchritt.grundriss)
      ..waehle(PlanerSchritt.treppen);
    expect(zustand.aktiv, PlanerSchritt.treppen);
    expect(zustand.besucht, {PlanerSchritt.grundriss, PlanerSchritt.treppen});
    expect(zustand.fortschritt, closeTo(2 / 7, 1e-9));
    expect(meldungen, 3);
    expect(zustand.besucht.clear, throwsUnsupportedError);
    for (final s in PlanerSchritt.values) {
      zustand.waehle(s);
    }
    expect(zustand.fortschritt, 1);
  });

  test('Zustand: Menü offen auf dem Desktop, sonst nach Bedienung', () {
    final zustand = RahmenZustand();
    expect(zustand.menuOffen(desktop: true), isTrue);
    expect(zustand.menuOffen(desktop: false), isFalse);
    var meldungen = 0;
    zustand
      ..addListener(() => meldungen++)
      ..schalteMenu(desktop: false);
    expect(zustand.menuOffen(desktop: false), isTrue);
    expect(zustand.menuOffen(desktop: true), isTrue);
    zustand.schalteMenu(desktop: true);
    expect(zustand.menuOffen(desktop: true), isFalse);
    expect(meldungen, 2);
  });
}
