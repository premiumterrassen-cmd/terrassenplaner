import 'package:flutter/widgets.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'steuerung.dart';
import 'zeichnung.dart';

/// Berechnet ein Planungsstand auf dem Server (M4-02); in Tests austauschbar.
typedef PlanungBerechnen = Future<Berechnung> Function(Planungsstand stand);

/// Hält die Berechnung des Servers zum aktuellen Planungsstand (M4-02): bei
/// jeder Änderung neu angefragt; kommt eine Antwort zu einem älteren Stand
/// erst nach einer neueren, wird sie verworfen. Die App rechnet nichts selbst.
class BerechnungsSteuerung extends ChangeNotifier {
  BerechnungsSteuerung({required this.planung, required this.berechne}) {
    planung.addListener(_frage);
    _frage();
  }

  final PlanungsSteuerung planung;
  final PlanungBerechnen berechne;

  Berechnung? _ergebnis;
  Object? _fehler;
  var _anfrage = 0;

  /// Letzte gültige Berechnung; `null`, solange keine vorliegt.
  Berechnung? get ergebnis => _ergebnis;

  /// Fehler der letzten Anfrage; `null`, wenn sie gelang.
  Object? get fehler => _fehler;

  /// Was die Zeichenfläche zeigt.
  Zeichnung get zeichnung => switch (_ergebnis) {
    final b? => Zeichnung(
      umriss: _offsets(b.umriss),
      ecken: _offsets(b.ecken),
      ausschnitte: [for (final a in b.ausschnitte) _offsets(a)],
    ),
    null => Zeichnung.leer,
  };

  static List<Offset> _offsets(List<Punkt> punkte) => [
    for (final p in punkte) Offset(p.x, p.y),
  ];

  /// Terrassenfläche in m² für die Kennzahlen.
  double? get flaeche => _ergebnis?.flaecheQuadratmeter;

  Future<void> _frage() async {
    final nummer = ++_anfrage;
    try {
      final ergebnis = await berechne(planung.aktuell);
      if (nummer != _anfrage) return;
      _ergebnis = ergebnis;
      _fehler = null;
    } on Object catch (fehler) {
      if (nummer != _anfrage) return;
      _fehler = fehler;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    // Antworten, die danach noch eintreffen, gelten als veraltet.
    _anfrage++;
    planung.removeListener(_frage);
    super.dispose();
  }
}
