import 'dart:math';

import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/darstellung.dart';
import '../konfiguration/konfigurations_steuerung.dart';
import '../sprache/sprache.dart';
import 'einstellungs_speicher.dart';

/// Die einzigen Daten, die der Planer im Browser speichert (M3-09):
/// Bedienungseinstellungen, die zuletzt geöffnete Konfiguration für
/// „Weiterplanen“ und der Sitzungsschlüssel des Entwurfs (M9-05) – keine
/// Fachdaten, das Frontend bleibt „doof“ (Vorgabe 02.10.2026). Sprache und
/// Darstellung liest auch der Ladebildschirm (`web/ladebild/fortschritt.js`)
/// unter denselben Schlüsseln.
final class LokaleEinstellungen implements KonfigurationsGedaechtnis {
  LokaleEinstellungen(this._speicher, {Random? zufall})
    : _zufall = zufall ?? Random.secure();

  final EinstellungsSpeicher _speicher;
  final Random _zufall;
  String? _sitzung;

  static const sprachSchluessel = 'terrassenplaner.sprache';
  static const darstellungSchluessel = 'terrassenplaner.darstellung';
  static const konfigurationSchluessel = 'terrassenplaner.weiterplanen';
  static const sitzungSchluessel = 'terrassenplaner.sitzung';

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
  @override
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
  @override
  void merke(KonfigurationsStand stand) => _speicher.schreibe(
    konfigurationSchluessel,
    '${stand.nummer.wert}/${stand.version}',
  );

  /// Sitzungsschlüssel für den Entwurf auf dem Server (M9-05): 128 Bit
  /// Zufall, beim ersten Aufruf erzeugt und danach behalten. Er ist kein
  /// Fachdatum, nur der Schlüssel, unter dem der Server den Entwurf führt.
  @override
  String sitzungsschluessel() => _sitzung ??= _sitzungAusSpeicher();

  String _sitzungAusSpeicher() {
    final gemerkt = _speicher.lies(sitzungSchluessel);
    if (gemerkt != null && _schluesselMuster.hasMatch(gemerkt)) return gemerkt;
    final neu = [
      for (var i = 0; i < 16; i++)
        _zufall.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ].join();
    _speicher.schreibe(sitzungSchluessel, neu);
    return neu;
  }

  static final _schluesselMuster = RegExp(r'^[0-9a-f]{32}$');
}
