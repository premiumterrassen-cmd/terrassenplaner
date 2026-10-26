import 'package:flutter/foundation.dart';

import 'planer_schritt.dart';

/// Bedienzustand des Rahmens (M3-01): aktiver Schritt, besuchte Stationen
/// und ob das Bearbeitungsmenü offen ist. Keine Fachdaten.
class RahmenZustand extends ChangeNotifier {
  PlanerSchritt _aktiv = PlanerSchritt.grundriss;
  final Set<PlanerSchritt> _besucht = {PlanerSchritt.grundriss};
  bool? _menuOffen;

  PlanerSchritt get aktiv => _aktiv;

  Set<PlanerSchritt> get besucht => Set.unmodifiable(_besucht);

  /// Anteil der besuchten Stationen (0 … 1).
  double get fortschritt => _besucht.length / PlanerSchritt.values.length;

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
