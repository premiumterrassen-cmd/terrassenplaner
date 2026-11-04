import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../rahmen/steuerung.dart';

/// Der Server kennt die Konfigurationsnummer oder Version nicht, oder der
/// Prüfcode passt nicht (M9-05, M9-05b) – beides sieht gleich aus.
final class KonfigurationNichtGefunden implements Exception {
  const KonfigurationNichtGefunden(this.stand);

  final KonfigurationsStand stand;

  @override
  String toString() => 'Konfiguration $stand nicht gefunden';
}

/// Automatisch zwischengespeicherter Stand und die gespeicherte
/// Konfiguration, auf der er beruht (`null` = noch nie gespeichert).
typedef PlanungsEntwurf = ({Planung planung, KonfigurationsStand? bezug});

/// Server-Ablage der Konfigurationen (M9-05, Konfigurationsdienst über
/// WAMP); in Tests austauschbar.
abstract interface class KonfigurationsAblage {
  /// Speichert [planung] als neue Version von [kennung] – ohne Kennung als
  /// Version 1 einer neuen Konfigurationsnummer mit neuem Prüfcode.
  Future<KonfigurationsStand> speichere(
    Planung planung, {
    Konfigurationskennung? kennung,
  });

  /// Lädt die Version [stand]; unbekannt: [KonfigurationNichtGefunden].
  Future<Planung> lade(KonfigurationsStand stand);

  /// Merkt [planung] als Entwurf der Sitzung [schluessel].
  Future<void> merkeEntwurf(
    String schluessel,
    Planung planung, {
    KonfigurationsStand? bezug,
  });

  /// Entwurf der Sitzung [schluessel]; `null`, wenn es keinen gibt.
  Future<PlanungsEntwurf?> entwurf(String schluessel);
}

/// Was der Browser sich für „Weiterplanen“ merkt (M3-09): die zuletzt
/// geöffnete Konfiguration und den Sitzungsschlüssel des Entwurfs.
abstract interface class KonfigurationsGedaechtnis {
  KonfigurationsStand? letzteKonfiguration();
  void merke(KonfigurationsStand stand);
  String sitzungsschluessel();
}

/// Was beim Start gefunden wurde: eine gespeicherte Konfiguration und/oder
/// ein ungespeicherter Entwurf.
final class Fund {
  const Fund({this.stand, this.entwurf = false});

  final KonfigurationsStand? stand;
  final bool entwurf;
}

/// SPEICHERN, LADEN und automatisches Zwischenspeichern der Planung
/// (M9-05). Die Planung selbst liegt nur auf dem Server; die App merkt sich
/// nur Kennung (Nummer mit Prüfcode, M9-05b), Version und
/// Sitzungsschlüssel.
///
/// Zwischenspeichern: [verzoegerung] nach der letzten Änderung geht die
/// Planung als **Entwurf** an den Server – ein Datensatz je Sitzung, der
/// überschrieben wird. Versionen entstehen nur mit SPEICHERN, so gibt es
/// keine Versionsflut; trotzdem geht beim Schließen des Browsers nichts
/// verloren („Weiterplanen“).
class KonfigurationsSteuerung extends ChangeNotifier {
  KonfigurationsSteuerung({
    required this.ablage,
    required this.gedaechtnis,
    this.verzoegerung = standardVerzoegerung,
  }) {
    planung.addListener(_geaendert);
  }

  static const standardVerzoegerung = Duration(seconds: 5);

  final KonfigurationsAblage ablage;
  final KonfigurationsGedaechtnis gedaechtnis;
  final Duration verzoegerung;

  /// Die bearbeitete Planung mit Rückgängig-Verlauf.
  final planung = PlanungsSteuerung();

  KonfigurationsStand? _stand;
  PlanungsEntwurf? _gefunden;
  Timer? _timer;
  ({Planung planung, KonfigurationsStand? bezug})? _gesichert;

  /// Zuletzt gespeicherte oder geladene Konfiguration; `null` bei einer
  /// neuen Planung.
  KonfigurationsStand? get stand => _stand;

  /// SPEICHERN: legt eine neue Version an (beim ersten Mal mit neuer
  /// Konfigurationsnummer) und merkt sie für „Weiterplanen“. Schlägt es
  /// fehl, bleibt die Planung unverändert erhalten.
  Future<KonfigurationsStand> speichere() async {
    final neu = await ablage.speichere(
      planung.planung,
      kennung: _stand?.kennung,
    );
    _setzeStand(neu);
    // Der Entwurf bekommt den neuen Bezug.
    _plane();
    return neu;
  }

  /// LADEN: ersetzt die Planung durch die gespeicherte Version [stand].
  Future<void> lade(KonfigurationsStand stand) async {
    final geladen = await ablage.lade(stand);
    _setzeStand(stand);
    planung.beginne(geladen);
  }

  /// Sucht beim Start den Entwurf dieser Sitzung (Server) und die zuletzt
  /// geöffnete Konfiguration (Browser). Ist der Server nicht erreichbar,
  /// zählt nur die gemerkte Konfiguration.
  Future<Fund?> suche() async {
    PlanungsEntwurf? entwurf;
    try {
      entwurf = await ablage.entwurf(gedaechtnis.sitzungsschluessel());
    } on Object {
      entwurf = null;
    }
    _gefunden = entwurf;
    if (entwurf != null) return Fund(stand: entwurf.bezug, entwurf: true);
    return switch (gedaechtnis.letzteKonfiguration()) {
      final stand? => Fund(stand: stand),
      null => null,
    };
  }

  /// „Weiterplanen“ mit dem Fund aus [suche]: der Entwurf, sonst die
  /// gemerkte Konfiguration vom Server.
  Future<void> weiterplanen() async {
    if (_gefunden case final entwurf?) {
      _stand = entwurf.bezug;
      _gesichert = entwurf;
      planung.beginne(entwurf.planung);
      notifyListeners();
      return;
    }
    await lade(gedaechtnis.letzteKonfiguration()!);
  }

  /// ZURÜCKSETZEN: neue Planung ohne Konfigurationsnummer.
  void neu() {
    _stand = null;
    planung.zuruecksetzen();
    notifyListeners();
  }

  void _setzeStand(KonfigurationsStand stand) {
    _stand = stand;
    gedaechtnis.merke(stand);
    notifyListeners();
  }

  void _geaendert() => _plane();

  void _plane() {
    _timer?.cancel();
    _timer = Timer(verzoegerung, _sichereEntwurf);
  }

  /// Sendet den Entwurf, wenn sich Planung oder Bezug seit dem letzten Mal
  /// geändert haben. Fehler bleiben still – die nächste Änderung versucht
  /// es erneut, die Planung bleibt in der App erhalten.
  Future<void> _sichereEntwurf() async {
    final aktuell = (planung: planung.planung, bezug: _stand);
    if (aktuell == _gesichert) return;
    try {
      await ablage.merkeEntwurf(
        gedaechtnis.sitzungsschluessel(),
        aktuell.planung,
        bezug: aktuell.bezug,
      );
      _gesichert = aktuell;
    } on Object {
      // still: die nächste Änderung versucht es erneut
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    planung
      ..removeListener(_geaendert)
      ..dispose();
    super.dispose();
  }
}
