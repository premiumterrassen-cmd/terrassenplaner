import 'package:flutter/foundation.dart';

import '../sprache/sprache.dart';

/// Ebenen der Draufsicht (Fachkonzept 00: „Belag | UK | Maße“).
enum Ebene {
  belag,
  unterkonstruktion,
  masse;

  String titel(PlanerTexte t) => switch (this) {
    belag => t.ebeneBelag,
    unterkonstruktion => t.ebeneUnterkonstruktion,
    masse => t.ebeneMasse,
  };

  /// Ausgeschriebener Name für Tooltip und Vorleser.
  String langerTitel(PlanerTexte t) => switch (this) {
    belag => t.ebeneBelagLang,
    unterkonstruktion => t.ebeneUnterkonstruktionLang,
    masse => t.ebeneMasseLang,
  };
}

/// Schaltbare Beschriftungen der Zeichnung.
enum Beschriftung {
  seitenlaengen,
  winkel,
  punkte,
  ablaeufe;

  String titel(PlanerTexte t) => switch (this) {
    seitenlaengen => t.beschriftungSeitenlaengen,
    winkel => t.beschriftungWinkel,
    punkte => t.beschriftungPunkte,
    ablaeufe => t.beschriftungAblaeufe,
  };
}

/// Was die Zeichenfläche zeigt (M3-04) – reine Bedienung, keine Planung;
/// am Anfang ist alles eingeschaltet.
class AnsichtsOptionen extends ChangeNotifier {
  final Set<Ebene> _ebenen = {...Ebene.values};
  final Set<Beschriftung> _beschriftungen = {...Beschriftung.values};

  Set<Ebene> get ebenen => Set.unmodifiable(_ebenen);
  Set<Beschriftung> get beschriftungen => Set.unmodifiable(_beschriftungen);

  bool zeigt(Ebene ebene) => _ebenen.contains(ebene);
  bool beschriftet(Beschriftung beschriftung) =>
      _beschriftungen.contains(beschriftung);

  void setzeEbenen(Set<Ebene> ebenen) {
    _ebenen
      ..clear()
      ..addAll(ebenen);
    notifyListeners();
  }

  void schalte(Beschriftung beschriftung) {
    if (!_beschriftungen.remove(beschriftung)) {
      _beschriftungen.add(beschriftung);
    }
    notifyListeners();
  }
}
