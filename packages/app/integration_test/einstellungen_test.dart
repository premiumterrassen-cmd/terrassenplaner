import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:terrassenplaner_app/src/einstellungen/einstellungs_speicher.dart';
import 'package:terrassenplaner_app/src/einstellungen/lokale_einstellungen.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:web/web.dart' as web;

/// Lokale Einstellungen im echten Browser-Speicher (M3-09); dieselben
/// Schlüssel liest der Ladebildschirm (tool/ladebild/pruefung.mjs prüft ihn
/// mit Englisch und gesperrtem Speicher).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final schluessel = [
    LokaleEinstellungen.sprachSchluessel,
    LokaleEinstellungen.darstellungSchluessel,
    LokaleEinstellungen.konfigurationSchluessel,
  ];
  void leeren() {
    for (final s in schluessel) {
      web.window.localStorage.removeItem(s);
    }
  }

  setUp(leeren);
  tearDown(leeren);

  testWidgets('Einstellungen landen im localStorage und bleiben erhalten', (
    _,
  ) async {
    final speicher = browserSpeicher();
    final erste = LokaleEinstellungen(speicher);
    final sprache = erste.sprache();
    final darstellung = erste.darstellung();
    expect(sprache.value, const Locale('de'));
    expect(darstellung.value, ThemeMode.system);

    sprache.value = const Locale('en');
    darstellung.value = ThemeMode.dark;
    final stand = KonfigurationsStand(
      Konfigurationsnummer.pruefe('2026-10-08-1511'),
      2,
    );
    erste.merke(stand);
    sprache.dispose();
    darstellung.dispose();

    final storage = web.window.localStorage;
    expect(storage.getItem(LokaleEinstellungen.sprachSchluessel), 'en');
    expect(storage.getItem(LokaleEinstellungen.darstellungSchluessel), 'dark');
    expect(
      storage.getItem(LokaleEinstellungen.konfigurationSchluessel),
      '2026-10-08-1511/2',
    );

    // Wie nach dem Neuladen: neue Einstellungen aus demselben Speicher.
    final zweite = LokaleEinstellungen(browserSpeicher());
    final wieder = zweite.sprache();
    final wiederDarstellung = zweite.darstellung();
    expect(wieder.value, const Locale('en'));
    expect(wiederDarstellung.value, ThemeMode.dark);
    expect(zweite.letzteKonfiguration(), stand);
    wieder.dispose();
    wiederDarstellung.dispose();
  });
}
