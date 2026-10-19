import 'dart:convert';
import 'dart:io';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

/// Hält die Planungsregeln (M1-04) gegen die Exporte des alten Planers
/// (M1-02/M1-03) und dokumentiert, wo er abweicht – Abweichungen werden nicht
/// übernommen (docs/fachkonzept/14-planungsregeln.md).
List<Materialposition> _material(String verzeichnis) => [
  for (final datei in Directory(
    verzeichnis,
  ).listSync().whereType<File>().where((f) => f.path.endsWith('.json')))
    ..._liste(jsonDecode(datei.readAsStringSync()) as Map<String, Object?>),
];

List<Materialposition> _liste(Map<String, Object?> json) =>
    json.containsKey('erwartet')
    ? Referenzfall.ausJson(json).materialliste
    : Referenzkonfiguration.ausJson(json).materialliste;

Referenzkonfiguration _fall(String id) => Referenzkonfiguration.ausJson(
  jsonDecode(File('test/referenzkonfigurationen/$id.json').readAsStringSync())
      as Map<String, Object?>,
);

bool _istDiele(Materialposition m) =>
    m.typ == 'Deckbelag' || m.typ == 'Anfangsdiele';

void main() {
  final alle = [
    ..._material('test/referenzfaelle'),
    ..._material('test/referenzkonfigurationen'),
  ];

  test('R-C01: Startkonfiguration hält den UK-Achsabstand ein', () {
    // F01: 480 cm breit, 13 UK-Hölzer à 4 cm → Achsabstand (480 − 4) / 12.
    final uk = _fall('F01').zuschnitt.where((z) => z.artikel.contains('Unter'));
    final hoelzer = uk.fold(0, (s, z) => s + z.menge);
    expect(hoelzer, 13);
    expect((4800 - 40) / (hoelzer - 1), lessThanOrEqualTo(ukAchsabstandMaxMm));
  });

  test('R-A07 Abweichung alt: einseitig genutete Anfangsdielen', () {
    final einseitig = alle.where((m) => m.bezeichnung.contains('einseitig'));
    expect(einseitig, isNotEmpty);
    expect(einseitig.map((m) => m.typ).toSet(), {'Anfangsdiele'});
  });

  test('R-A09 Abweichung alt: KOPPLEX statt GUMO', () {
    expect(alle.where((m) => m.bezeichnung.startsWith('KOPPLEX')), isNotEmpty);
  });

  test('R-A06 Abweichung alt: Zwischenlängen, die es nicht mehr gibt', () {
    final laengen = {
      for (final m in alle.where(_istDiele))
        if (m.laengeMm != null) m.laengeMm!,
    };
    final standard = {
      for (final serie in Serie.values) ...lieferlaengenMm(serie),
    };
    expect(laengen.difference(standard), containsAll([3000, 4500, 5500]));
  });

  test('R-B09: Staffel stimmt bei kleinen Mengen mit dem alten Planer', () {
    for (final id in ['F01', 'F02', 'F09', 'F15', 'F16', 'F17', 'F20']) {
      final dielen = _fall(id).materialliste.where(_istDiele).toList();
      final frei = dielen
          .where((m) => m.bezeichnung.contains('Freidiele'))
          .fold(0, (s, m) => s + m.anzahl);
      final haupt = dielen
          .where((m) => m.typ == 'Deckbelag')
          .where((m) => !m.bezeichnung.contains('Freidiele'))
          .fold(0, (s, m) => s + m.anzahl);
      expect(frei, freidielen(haupt), reason: id);
    }
  });

  test('R-B09 Abweichung alt: Grenzfälle und große Mengen', () {
    // F13: 92 Hauptdielen → alt 3, Regel 2; F39: 50 → alt 1, Regel 2.
    expect([freidielen(92), freidielen(50)], [2, 2]);
  });
}
