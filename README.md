# Terrassenplaner (ALTO HOLZ)

Neuer Terrassenplaner – funktionaler Nachbau von https://terrassenkonfigurator.robinienwelt.de/. Regeln: [CLAUDE.md](CLAUDE.md), Plan: [ROADMAP.md](ROADMAP.md).

## Aufbau (Dart-Workspace)

| Paket | Zweck |
|---|---|
| `packages/domain` | Fachlogik ohne Oberfläche und ohne Ein-/Ausgabe (Geometrie, Artikel, Regeln, Berechnungen) |
| `packages/server` | Dart-Server: WAMP-Router (`connectanum_router`), Authentifizierung (`connectanum_auth_server`), Dienste |
| `packages/app` | Flutter-Web-Oberfläche, spricht über `connectanum_client` (WAMP) mit dem Server |

`app` und `server` hängen von `domain` ab, nie umgekehrt.

## Voraussetzungen

Flutter (stable, getestet mit 3.47.6 / Dart 3.13.5), Chrome für Web und Smoke-Tests.

## Befehle

```bash
flutter pub get                      # alle Pakete auflösen (Workspace-Wurzel)
dart analyze                         # Analyse aller Pakete, muss ohne Hinweise sein
dart format --set-exit-if-changed .  # Formatierung prüfen
(cd packages/domain && dart test)
(cd packages/server && dart test)
(cd packages/app && flutter test)
(cd packages/server && dart run bin/server.dart)
(cd packages/app && flutter run -d chrome)
```
