/// Namen der Eckpunkte A, B, C … (Planungsregeln Alexander (Planungskern
/// v6, 11.11.2026), Regel 6.2, R-E03): einheitlich um den Umriss, oben
/// links beginnend im Uhrzeigersinn.
library;

import 'punkt.dart';

/// Buchstabe der [i]-ten Ecke in der Reihenfolge der Benennung: A … Z, dann
/// AA, AB … wie im Planungskern.
String eckbuchstabe(int i) => i < 26
    ? String.fromCharCode(_a + i)
    : String.fromCharCode(_a - 1 + i ~/ 26) + String.fromCharCode(_a + i % 26);

const _a = 0x41;

/// Name je Eckpunkt der [ecken] (parallel zur Liste): A ist die Ecke oben
/// links (kleinstes y, bei Gleichstand kleinstes x), weiter im
/// Uhrzeigersinn der Zeichnung (y nach unten) – unabhängig davon, wo der
/// Umriss beginnt und in welcher Richtung er gezeichnet wurde (Freiform,
/// gedrehter Grundriss).
///
/// Ein offener Linienzug ([geschlossen] = false) oder weniger als drei
/// Ecken haben keinen Umlauf: Namen in der Reihenfolge der Punkte.
List<String> eckenBenennen(List<Punkt> ecken, {bool geschlossen = true}) => [
  for (final i in eckennummern(ecken, geschlossen: geschlossen))
    eckbuchstabe(i),
];

/// Nummer des Buchstabens je Eckpunkt der [ecken] (`eckenBenennen`, A = 0).
List<int> eckennummern(List<Punkt> ecken, {bool geschlossen = true}) {
  final n = ecken.length;
  if (!geschlossen || n < 3) {
    return [for (var i = 0; i < n; i++) i];
  }
  var start = 0;
  var flaeche = 0.0;
  for (var i = 0; i < n; i++) {
    final p = ecken[i];
    final s = ecken[start];
    if (p.y < s.y || (p.y == s.y && p.x < s.x)) start = i;
    flaeche += p.kreuz(ecken[(i + 1) % n]);
  }
  // y nach unten: positive Fläche = im Uhrzeigersinn der Zeichnung
  final vorwaerts = flaeche > 0;
  return [
    for (var i = 0; i < n; i++) vorwaerts ? (i - start) % n : (start - i) % n,
  ];
}
