# Lokale Bedienungseinstellungen (M3-09)

Vorgabe Alexander 02.10.2026: Das Frontend bleibt „doof“. Im Browser liegen nur Bedienungseinstellungen, keine Fachdaten.

## Was gespeichert wird

| Schlüssel (`localStorage`) | Werte | Standard | Gelesen von |
|---|---|---|---|
| `terrassenplaner.sprache` | `de`, `en` | `de` (wie M3-07) | App, Ladebildschirm |
| `terrassenplaner.darstellung` | `light`, `dark`, `system` | `system` | App, Ladebildschirm |
| `terrassenplaner.weiterplanen` | `JJJJ-MM-TT-NNNN/Version` | – | App (Eingangsdialog „Weiterplanen“) |

- Unbekannte oder beschädigte Werte zählen als nicht gespeichert, es gilt der Standard.
- „Weiterplanen“ merkt sich eine Konfiguration erst, wenn sie erfolgreich geladen wurde (`LokaleEinstellungen.merkend`). Das Laden über den Server folgt mit M9-05, bis dahin bleibt der Eintrag leer.

## Aufbau

- `lib/src/einstellungen/einstellungs_speicher.dart`:
  - `EinstellungsSpeicher` (lesen/schreiben);
  - `FluechtigerSpeicher` außerhalb des Browsers und in Tests;
  - `SichererSpeicher` fängt jeden Fehler des Browser-Speichers ab;
  - `browserSpeicher()` wählt über einen bedingten Import `localStorage` (`browser_speicher_web.dart`).
- `lib/src/einstellungen/lokale_einstellungen.dart` erzeugt `SprachSteuerung` und `DarstellungSteuerung` mit den gespeicherten Werten und speichert jede Änderung.
- `lib/src/design/darstellung.dart` enthält `DarstellungSteuerung` und die Darstellungsauswahl in der Kopfzeile (Hell, Dunkel, Wie System).
- `planerThema(Brightness)`:
  - Die Markenfarben Braun und Grün bleiben.
  - Die Flächen laufen über das Farbschema: `surface` Grund, `surfaceContainer` Leisten (Sand), `onSurface` Text, `outlineVariant` Linien.
  - Dunkel: `PlanerFarbenDunkel`.
- Ladebildschirm (`web/ladebild/fortschritt.js`):
  - liest dieselben Schlüssel;
  - Texte auf Deutsch und Englisch, auch die festen Texte aus `index.html` und `<html lang>`;
  - dunkle Variante über `html.dunkel`, die Farben stimmen mit dem Planer überein.

## Gefunden und behoben

- **Kopfzeile bei 1280 px zu eng:** Mit Sprach- und Darstellungsauswahl lief die Kopfzeile auf Englisch um 42 px über. Beschriftete Knöpfe gibt es deshalb erst ab 1366 px (`Kopfzeile.textAb`), darunter nur Symbole mit Tooltip.
- **Ladebildschirm hell, App dunkel:** Bei dunkler Darstellung blitzte beim Start der helle Ladebildschirm auf. Er folgt jetzt derselben Einstellung, ohne Eintrag dem System (`prefers-color-scheme`).

## Geprüft

| Prüfung | Wo |
|---|---|
| Standardwerte, Speichern, Wiederfinden, ungültige Einträge, gesperrter Speicher | `test/einstellungen_test.dart` |
| Umschalten hell/dunkel/System, Thema der App, Texte in beiden Sprachen | `test/einstellungen_test.dart`, `test/planer_rahmen_test.dart` |
| Echter `localStorage`: speichern und nach „Neuladen“ wiederfinden | `integration_test/einstellungen_test.dart` |
| Ladebildschirm: gespeichertes Englisch | `tool/ladebild/pruefung.mjs` |
| Ladebildschirm: Darstellung gespeichert dunkel/hell, sonst wie das System | `tool/ladebild/pruefung.mjs` |
| Gesperrter Speicher (Zugriff auf `localStorage` wirft): Deutsch, App startet ohne Konsolenfehler | `tool/ladebild/pruefung.mjs` |

## Offen

- Die Dateien unter `web/ladebild/` haben keinen Versionsanhang. Nach einem Update kann der Browser noch das alte CSS oder Skript aus dem Cache nehmen; das ist lokal aufgefallen. Die Cache-Regeln für die Web-App gehören zum Deployment (Traefik, `Cache-Control`).
