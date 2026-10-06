# Ladebildschirm (M3-08, 06.10.2026)

**Technik** nach dem Verfahren von dls-gmbh.biz/mein-essen (eigener Code), **Gestaltung** wie der bisherige Terrassenplaner (Vorgabe Alexander 06.10.2026).

## Aufbau

- `packages/app/web/index.html` – Ladebild als reines HTML/CSS, sofort sichtbar: RobinienWelt-Logo (`web/ladebild/robinienwelt-logo.svg`, aus dem bisherigen Planer), Jahresring-Motiv, Karte mit Titel, Balken (#b0864b auf #dcdcdc), Prozent, Status; Hintergrund #f5f0e8; Knopf „Erneut versuchen“ (#95c11c).
- `web/ladebild/fortschritt.js` – echte Prozentanzeige: zählt geladene Bytes (fetch wird durchgereicht und mitgezählt, ohne Puffern – WebAssembly kompiliert weiter streamend; Skripte/Cache über Ressourcen-Zeiten) gegen die Größenliste. Plan = Einstieg des gewählten Builds (`main.dart.wasm` + `.mjs` bzw. `main.dart.js`) + Renderer (`skwasm` bzw. `canvaskit`). Prozent steigt monoton, 100 % erst wenn Flutter zeichnet; bei Unstimmigkeit unbestimmter Balken. Phasen: laden → Darstellung vorbereiten → öffnen; Hinweise „langsam“ (10 s ohne Fortschritt) und „offline“; Fehler mit „Erneut versuchen“. `planerLadebildschirm.zustand()` für Tests/Fehlersuche.
- `web/flutter_bootstrap.js` – eigener Start: meldet Phasen, ruft nach `runApp()` `fertig()` (zwei Bilder abwarten, 0,2 s ausblenden, bei „Bewegung reduzieren“ sofort entfernen). Renderer kommt per `canvasKitBaseUrl: 'canvaskit/'` vom **eigenen Server** statt von gstatic.com (messbar, keine Google-Anfrage).
- `tool/startgroessen.py` – schreibt nach `flutter build web` die Größen der Startdateien in `#startgroessen` (Build-Chain).

## Geprüft

- Lokal mit WASM-Build und COOP/COEP: Plan erkannt (4 Dateien), 100 %, Ladebild entfernt, `fetch` wiederhergestellt, keine Konsolenfehler.
- Smoke-Test `integration_test/ladebild_test.dart`: Ladebild verschwindet nach dem Start.

## Offen

- Langsam-/Offline-/Fehlerzustand automatisiert testen (gedrosselte bzw. unterbrochene Verbindung).
- Benchmark „Zeit bis zum ersten Bild“.
- Flutter lädt die Ersatzschrift Roboto noch von fonts.gstatic.com – Schrift lokal einbinden (Design-System, M3-01).
