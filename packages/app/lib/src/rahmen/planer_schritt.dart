/// Die sieben Schritte des Planers mit ihren nummerierten Unterpunkten
/// (Fachkonzept 00–07). Frei anklickbar, keine Pflichtreihenfolge.
enum PlanerSchritt {
  grundriss('GRUNDRISS', null, [
    'Terrassenform auswählen',
    'Terrassenmaße',
    'Ecken und Seiten abrunden',
    'Ausschnitte und Teilflächen',
  ]),
  terrassenbelag('TERRASSENBELAG', 'TERRASSEN-\nBELAG', [
    'Terrassenbelag auswählen',
    'Dielenlänge automatisch ermitteln',
    'Verlegearten',
    'Verlegerichtungen',
    'Ausgangspunkt des Belags',
  ]),
  unterkonstruktion('UNTERKONSTRUKTION', 'UNTER-\nKONSTRUKTION', [
    'Art der Terrasse',
    'Höhenpunkte',
    'Unterkonstruktion auswählen',
    'Länge der Unterkonstruktion',
    'Untergrund',
    'Art der Terrassennutzung',
    'Querstreben',
    'Nutzung privat oder gewerblich',
  ]),
  terrassenanschluss('TERRASSENANSCHLUSS', 'TERRASSEN-\nANSCHLUSS', [
    'Angrenzende Bauelemente',
    'Verblendung',
    'Entwässerungsrinnen',
  ]),
  treppen('TREPPEN', null, ['Treppen']),
  zubehoer('ZUBEHÖR', null, [
    'Allgemein',
    'Anlieferung',
    'Clips & Schrauben',
    'Höhenausgleich',
    'Pads & EPDM-Bänder',
    'Rhombusleisten',
    'Terrassenfliesen',
    'Terrassenöl RIBOL',
  ]),
  verschnittoptimierung('VERSCHNITTOPTIMIERUNG', 'VERSCHNITT-\nOPTIMIERUNG', [
    'Verschnittvariante auswählen',
  ]);

  const PlanerSchritt(this.titel, this._getrennt, this.unterpunkte);

  final String titel;
  final String? _getrennt;

  /// Titel für schmale Stationen: lange Wörter getrennt auf zwei Zeilen.
  String get getrennterTitel => _getrennt ?? titel;
  final List<String> unterpunkte;

  /// Nummer ab 1 („1. GRUNDRISS“).
  int get nummer => index + 1;

  /// Nummerierte Unterpunkte, z. B. „1.2 Terrassenmaße“.
  List<String> get nummerierteUnterpunkte => [
    for (final (i, text) in unterpunkte.indexed) '$nummer.${i + 1} $text',
  ];
}
