import 'package:flutter/widgets.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
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
      geschlossen: b.geschlossen,
      ausschnitte: [for (final a in b.ausschnitte) _offsets(a)],
      ausschnittDarstellung: [
        for (final a in planung.aktuell.ausschnitte)
          (name: a.bezeichnung, farbe: farbe(a)),
      ],
    ),
    null => Zeichnung.leer,
  };

  /// Füllung eines Ausschnitts (Fachkonzept 1.4: nur Darstellung).
  static Color farbe(Ausschnitt a) => switch ((a.funktion, a.inhalt)) {
    (Ausschnittfunktion.andererBelag, _) => PlanerFarben.belagAnders,
    (_, Ausschnittinhalt.leer) => PlanerFarben.weiss,
    (_, Ausschnittinhalt.kiesHell) => const Color(0xFFD8D4CC),
    (_, Ausschnittinhalt.steinDunkel) => const Color(0xFF6E6A66),
    (_, Ausschnittinhalt.pool) => const Color(0xFF7FC4E8),
    (_, Ausschnittinhalt.rasen) => const Color(0xFF8DC26F),
    (_, Ausschnittinhalt.erde) => const Color(0xFF8B6A4E),
  };

  static List<Offset> _offsets(List<Punkt> punkte) => [
    for (final p in punkte) Offset(p.x, p.y),
  ];

  /// Terrassenfläche in m² für die Kennzahlen.
  /// Offene Freiform (M4-08): keine Fläche.
  double? get flaeche => switch (_ergebnis) {
    final b? when b.geschlossen => b.flaecheQuadratmeter,
    _ => null,
  };

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
