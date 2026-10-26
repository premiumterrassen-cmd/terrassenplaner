import 'package:flutter/foundation.dart';

import 'planer_schritt.dart';

/// Bedienzustand des Rahmens (M3-01): aktiver Schritt, besuchte Stationen,
/// Schritte mit geänderten Eingaben (M3-05) und ob das Bearbeitungsmenü
/// offen ist. Keine Fachdaten.
class RahmenZustand extends ChangeNotifier {
  PlanerSchritt _aktiv = PlanerSchritt.grundriss;
  final Set<PlanerSchritt> _besucht = {PlanerSchritt.grundriss};
  final Set<PlanerSchritt> _geaendert = {};
  bool? _menuOffen;

  PlanerSchritt get aktiv => _aktiv;

  Set<PlanerSchritt> get besucht => Set.unmodifiable(_besucht);

  /// Anteil der besuchten Stationen (0 … 1).
  double get fortschritt => _besucht.length / PlanerSchritt.values.length;

  /// Schritte, in denen der Kunde nie etwas geändert hat – dort gelten die
  /// Standardwerte (M3-05), in der Reihenfolge der Schritte.
  List<PlanerSchritt> get unveraendert => [
    for (final s in PlanerSchritt.values)
      if (!_geaendert.contains(s)) s,
  ];

  /// Merkt sich, dass im [schritt] eine Eingabe geändert wurde (ab M4 von
  /// den Eingabefeldern aufgerufen).
  void markiereGeaendert(PlanerSchritt schritt) {
    if (_geaendert.add(schritt)) notifyListeners();
  }

  /// Neue Planung: alle Schritte wieder auf Standardwerten.
  void vergissAenderungen() {
    _geaendert.clear();
    notifyListeners();
  }

  /// Ob das Menü offen ist; ohne Bedienung offen nur auf dem Desktop.
  bool menuOffen({required bool desktop}) => _menuOffen ?? desktop;

  void waehle(PlanerSchritt schritt) {
    _aktiv = schritt;
    _besucht.add(schritt);
    notifyListeners();
  }

  void schalteMenu({required bool desktop}) {
    _menuOffen = !menuOffen(desktop: desktop);
    notifyListeners();
  }
}
