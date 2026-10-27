import 'browser_speicher_stub.dart'
    if (dart.library.js_interop) 'browser_speicher_web.dart'
    as umsetzung;

/// Schlüssel-Wert-Speicher für Bedienungseinstellungen (M3-09).
abstract interface class EinstellungsSpeicher {
  String? lies(String schluessel);
  void schreibe(String schluessel, String wert);
}

/// Speicher nur für die laufende Sitzung – außerhalb des Browsers und in
/// Tests.
final class FluechtigerSpeicher implements EinstellungsSpeicher {
  final _werte = <String, String>{};

  @override
  String? lies(String schluessel) => _werte[schluessel];

  @override
  void schreibe(String schluessel, String wert) => _werte[schluessel] = wert;
}

/// Fängt Fehler des [inneren] Speichers ab: Ist der Browser-Speicher
/// gesperrt oder voll (privates Fenster, Datenschutz-Einstellungen), liest
/// die App nichts und arbeitet mit Standardwerten weiter.
final class SichererSpeicher implements EinstellungsSpeicher {
  SichererSpeicher(this.inneren);

  final EinstellungsSpeicher inneren;

  @override
  String? lies(String schluessel) {
    try {
      return inneren.lies(schluessel);
    } on Object {
      return null;
    }
  }

  @override
  void schreibe(String schluessel, String wert) {
    try {
      inneren.schreibe(schluessel, wert);
    } on Object {
      // Nicht speicherbar: Die Einstellung gilt nur bis zum Neuladen.
    }
  }
}

/// `localStorage` im Browser, sonst flüchtig – immer abgesichert.
EinstellungsSpeicher browserSpeicher() =>
    SichererSpeicher(umsetzung.browserSpeicher());
