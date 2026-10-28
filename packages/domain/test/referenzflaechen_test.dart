import 'dart:convert';
import 'dart:io';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

/// Fläche des Grundrisses gegen die Referenzfälle (M4-13, M1-02): Der neue
/// Planer zeigt dieselbe Fläche wie der alte, auf drei Nachkommastellen.
///
/// Verglichen werden alle Fälle fester Form, deren Kantenmaße zur Form des
/// neuen Planers passen; Freiformen und gerundete Grundrisse haben in den
/// Unterlagen keine vollständigen Maße. Die angezeigte Fläche ist die
/// Außenfläche – Ausschnitte ziehen nichts ab (Fachkonzept 1.4).
void main() {
  final faelle =
      Directory('test/referenzfaelle')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json'))
          .map(
            (f) => Referenzfall.ausJson(
              jsonDecode(f.readAsStringSync()) as Map<String, Object?>,
            ),
          )
          .toList()
        ..sort((a, b) => a.id.compareTo(b.id));

  final vergleichbar = [
    for (final fall in faelle)
      if (fall.flaecheM2 != null && !fall.grundriss.rundungen)
        if (_grundriss(fall.grundriss) case final g?) (fall, g),
  ];

  test('alle Rechtecke und passenden L-/T-Formen werden verglichen', () {
    expect(vergleichbar, hasLength(26));
    expect(
      {for (final (_, g) in vergleichbar) g.form},
      {Terrassenform.rechteck, Terrassenform.lForm, Terrassenform.tForm},
    );
  });

  for (final (fall, grundriss) in vergleichbar) {
    test('${fall.id}: ${fall.flaecheM2} m²', () {
      final stand = Planungsstand(grundriss: grundriss);
      expect(
        (stand.kontur.flaeche / 1e6).toStringAsFixed(3),
        fall.flaecheM2!.toStringAsFixed(3),
      );
    });
  }
}

/// Grundriss des neuen Planers aus den Kantenmaßen (cm) oder `null`, wenn
/// die Maße nicht zur Form passen (andere Lage der Aussparung, fehlende
/// Maße).
Grundriss? _grundriss(ReferenzGrundriss r) {
  final k = r.kantenCm;
  Millimeter mm(String kante) => Millimeter((k[kante]! * 10).round());
  bool hat(List<String> kanten) =>
      k.length == kanten.length && kanten.every((x) => k[x] != null);
  switch (r.form) {
    case 'Rechteck':
      return RechteckGrundriss(mm('A-B'), mm('B-C'));
    case 'L-Form'
        when hat(['A-B', 'B-C', 'C-D', 'D-E', 'E-F', 'F-A']) &&
            k['E-F'] == k['A-B']! + k['C-D']! &&
            k['F-A'] == k['B-C']! + k['D-E']!:
      return LGrundriss(mm('A-B'), mm('B-C'), mm('C-D'), mm('D-E'));
    case 'T-Form'
        when hat(['A-B', 'B-C', 'C-D', 'D-E', 'E-F', 'F-G', 'G-H', 'H-A']) &&
            k['A-B'] == k['G-H']! + k['E-F']! + k['C-D']! &&
            k['F-G'] == k['B-C']! + k['D-E']! - k['H-A']!:
      return TGrundriss(
        mm('B-C'),
        mm('C-D'),
        mm('D-E'),
        mm('E-F'),
        mm('G-H'),
        mm('H-A'),
      );
  }
  return null;
}
