import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/darstellung.dart';
import '../sprache/sprache.dart';
import '../start/eingangsdialog.dart';
import 'einstellungs_speicher.dart';

/// Die einzigen Daten, die der Planer im Browser speichert (M3-09):
/// Bedienungseinstellungen und die zuletzt geöffnete Konfiguration für
/// „Weiterplanen“ – keine Fachdaten, das Frontend bleibt „doof“ (Vorgabe
/// 02.10.2026). Sprache und Darstellung liest auch der Ladebildschirm
/// (`web/ladebild/fortschritt.js`) unter denselben Schlüsseln.
final class LokaleEinstellungen {
  LokaleEinstellungen(this._speicher);

  final EinstellungsSpeicher _speicher;

  static const sprachSchluessel = 'terrassenplaner.sprache';
  static const darstellungSchluessel = 'terrassenplaner.darstellung';
  static const konfigurationSchluessel = 'terrassenplaner.weiterplanen';

  /// Gespeicherte Sprache, sonst Deutsch; jede Änderung wird gespeichert.
  SprachSteuerung sprache() {
    final code = _speicher.lies(sprachSchluessel);
    final steuerung = SprachSteuerung(
      SprachSteuerung.sprachen
              .where((s) => s.languageCode == code)
              .firstOrNull ??
          SprachSteuerung.standard,
    );
    return steuerung..addListener(
      () => _speicher.schreibe(sprachSchluessel, steuerung.value.languageCode),
    );
  }

  /// Gespeicherte Darstellung, sonst wie das System; jede Änderung wird
  /// gespeichert.
  DarstellungSteuerung darstellung() {
    final name = _speicher.lies(darstellungSchluessel);
    final steuerung = DarstellungSteuerung(
      ThemeMode.values.where((m) => m.name == name).firstOrNull ??
          DarstellungSteuerung.standard,
    );
    return steuerung..addListener(
      () => _speicher.schreibe(darstellungSchluessel, steuerung.value.name),
    );
  }

  /// Zuletzt geöffnete Konfiguration (`JJJJ-MM-TT-NNNN/Version`), falls
  /// gültig gespeichert.
  KonfigurationsStand? letzteKonfiguration() {
    final teile = _speicher.lies(konfigurationSchluessel)?.split('/');
    if (teile case [final nummer, final version]) {
      try {
        return KonfigurationsStand(
          Konfigurationsnummer.pruefe(nummer),
          int.parse(version),
        );
      } on FormatException {
        return null;
      } on ArgumentError {
        return null;
      }
    }
    return null;
  }

  /// Merkt sich [stand] für „Weiterplanen“ beim nächsten Start.
  void merke(KonfigurationsStand stand) => _speicher.schreibe(
    konfigurationSchluessel,
    '${stand.nummer.wert}/${stand.version}',
  );

  /// Hülle um [laden]: Erst eine erfolgreich geladene Konfiguration wird
  /// gemerkt.
  KonfigurationLaden merkend(KonfigurationLaden laden) => (stand) async {
    await laden(stand);
    merke(stand);
  };
}
