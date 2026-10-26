import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

import 'argument_fehler.dart';

void main() {
  test('Anfang ohne Rückgängig und Wiederherstellen', () {
    final v = Verlauf('a');
    expect(v.aktuell, 'a');
    expect([v.kannRueckgaengig, v.kannWiederherstellen], [false, false]);
    expect(v.rueckgaengig(), 'a');
    expect(v.wiederherstellen(), 'a');
    expect(v.hoechstens, 200);
  });

  test('Rückgängig liefert exakt den vorherigen Stand', () {
    final staende = [
      <String, int>{'laenge': 4000},
      <String, int>{'laenge': 4500},
      <String, int>{'laenge': 4500, 'breite': 3000},
    ];
    final v = Verlauf<Map<String, int>>(staende[0]);
    v
      ..setze(staende[1])
      ..setze(staende[2]);
    expect([v.kannRueckgaengig, v.kannWiederherstellen], [true, false]);
    expect(identical(v.rueckgaengig(), staende[1]), isTrue);
    expect(identical(v.rueckgaengig(), staende[0]), isTrue);
    expect([v.kannRueckgaengig, v.kannWiederherstellen], [false, true]);
    expect(identical(v.wiederherstellen(), staende[1]), isTrue);
    expect(identical(v.wiederherstellen(), staende[2]), isTrue);
    expect(v.kannWiederherstellen, isFalse);
  });

  test('neuer Stand nach Rückgängig verwirft die Zukunft', () {
    final v = Verlauf('a')
      ..setze('b')
      ..setze('c')
      ..rueckgaengig()
      ..setze('d');
    expect(v.aktuell, 'd');
    expect(v.kannWiederherstellen, isFalse);
    expect(v.rueckgaengig(), 'b');
    expect(v.rueckgaengig(), 'a');
  });

  test('gleicher Stand erzeugt keinen Schritt', () {
    final v = Verlauf('a')..setze('a');
    expect(v.kannRueckgaengig, isFalse);
    v
      ..setze('b')
      ..setze('b');
    expect(v.rueckgaengig(), 'a');
    expect(v.kannRueckgaengig, isFalse);
  });

  test('höchstens n Schritte, älteste fallen weg', () {
    final v = Verlauf(0, hoechstens: 3);
    for (var i = 1; i <= 5; i++) {
      v.setze(i);
    }
    expect([v.rueckgaengig(), v.rueckgaengig(), v.rueckgaengig()], [4, 3, 2]);
    expect(v.kannRueckgaengig, isFalse);
    expect(v.rueckgaengig(), 2);
    expect(Verlauf(0, hoechstens: 1).hoechstens, 1);
    final eins = Verlauf(0, hoechstens: 1)
      ..setze(1)
      ..setze(2);
    expect([eins.rueckgaengig(), eins.kannRueckgaengig], [1, false]);
    expect(
      () => Verlauf(0, hoechstens: 0),
      wirftArgumentFehler('hoechstens', 0, 'mindestens 1'),
    );
  });

  test('Zurücksetzen leert den Verlauf', () {
    final v = Verlauf('a')
      ..setze('b')
      ..setze('c')
      ..rueckgaengig()
      ..zuruecksetzen('neu');
    expect(v.aktuell, 'neu');
    expect([v.kannRueckgaengig, v.kannWiederherstellen], [false, false]);
    v.setze('x');
    expect(v.rueckgaengig(), 'neu');
  });

  test('leerer Planungsstand ist gleich sich selbst', () {
    const leer = Planungsstand.leer();
    expect(leer, const Planungsstand.leer());
    expect(leer.hashCode, const Planungsstand.leer().hashCode);
    expect(leer.hashCode, (Planungsstand).hashCode);
    expect(leer == Object(), isFalse);
    expect(leer == const _Anderer(), isFalse);
    final v = Verlauf(leer)..setze(const Planungsstand.leer());
    expect(v.kannRueckgaengig, isFalse);
  });
}

final class _Anderer extends Planungsstand {
  const _Anderer() : super.leer();
}
