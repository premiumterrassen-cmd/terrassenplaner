import 'package:flutter/foundation.dart';

/// Ebenen der Draufsicht (Fachkonzept 00: „Belag | UK | Maße“).
enum Ebene {
  belag('Belag'),
  unterkonstruktion('UK'),
  masse('Maße');

  const Ebene(this.titel);

  final String titel;
}

/// Schaltbare Beschriftungen der Zeichnung.
enum Beschriftung {
  seitenlaengen('Seitenlängen'),
  winkel('Winkel'),
  punkte('Punkte'),
  ablaeufe('Abläufe');

  const Beschriftung(this.titel);

  final String titel;
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
