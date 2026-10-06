# Terrassenplaner (ALTO HOLZ)

[![Build-Chain](https://github.com/premiumterrassen-cmd/terrassenplaner/actions/workflows/build-chain.yml/badge.svg)](https://github.com/premiumterrassen-cmd/terrassenplaner/actions/workflows/build-chain.yml)

Neuer Terrassenplaner – funktionaler Nachbau von https://terrassenkonfigurator.robinienwelt.de/. Regeln: [CLAUDE.md](CLAUDE.md), Plan: [ROADMAP.md](ROADMAP.md).

## Aufbau (Dart-Workspace)

| Paket | Zweck |
|---|---|
| `packages/domain` | Fachlogik ohne Oberfläche und ohne Ein-/Ausgabe (Geometrie, Artikel, Regeln, Berechnungen) |
| `packages/server` | Dart-Server: WAMP-Router (`connectanum_router`), Authentifizierung (`connectanum_auth_server`), Dienste |
| `packages/app` | Flutter-Web-Oberfläche, spricht über `connectanum_client` (WAMP) mit dem Server |

`app` und `server` hängen von `domain` ab, nie umgekehrt.

## Voraussetzungen

Flutter (stable, getestet mit 3.47.6 / Dart 3.13.5), Chrome für Web und Smoke-Tests, dazu ein zur Chrome-Hauptversion passender `chromedriver` (offiziell von „Chrome for Testing“; das Homebrew-Cask ist seit 01.09.2026 gesperrt). `tool/smoke.sh` sucht ihn auch in `~/.local/bin`.

## Befehle

```bash
flutter pub get                      # alle Pakete auflösen (Workspace-Wurzel)
dart analyze                         # Analyse aller Pakete, muss ohne Hinweise sein
dart format --set-exit-if-changed .  # Formatierung prüfen
(cd packages/domain && dart test)
(cd packages/server && dart test)
(cd packages/app && flutter test)
tool/coverage.sh                     # Unit-Tests aller Pakete mit Abdeckung, bricht unter 100 % ab
tool/mutation.sh                     # Mutation-Tests aller Pakete, bricht unter 95 % ab
tool/smoke.sh                        # Frontend-Smoke-Tests headless in Chrome
tool/benchmark.sh                    # Feature-Benchmarks, Vergleich mit dem Vorwert
(cd packages/server && dart run bin/server.dart)
(cd packages/app && flutter run -d chrome)
```

## Abdeckung

`tool/coverage.sh` misst die Abdeckung je Paket, führt sie in `coverage/lcov.info` zusammen und bricht ab, wenn eine Zeile ungetestet ist oder eine Quelldatei mit Code in keinem Bericht auftaucht. Ausnahmen (nur reine Startpunkte) stehen begründet in `tool/coverage_exclude.txt`.

## Mutation-Tests

`tool/mutation.sh [paket …]` führt `mutation_test` je Paket mit `tool/mutation/<paket>.xml` aus (Schwelle 95 %, Bericht in `mutation-test-report/<paket>`). Werkzeugwahl und Erkenntnisse: [docs/erkenntnisse/mutation-tests.md](docs/erkenntnisse/mutation-tests.md).

## Frontend-Smoke-Tests

`tool/smoke.sh` startet `chromedriver` und führt jede Datei in `packages/app/integration_test/` per `flutter drive` headless in Chrome aus (Exit-Code 1 bei Fehler).

## Benchmarks

Jedes performancerelevante Feature bekommt einen Benchmark in `packages/<paket>/benchmark/<name>_benchmark.dart` (`benchmark_harness`, Name im Format `<paket>.<Thema>`). `tool/benchmark.sh` führt alle aus, schreibt `benchmark-results/<umgebung>.json` und vergleicht mit `benchmarks/baseline-<umgebung>.json` (Umgebung `BENCH_ENV`, Standard `lokal`, in der Build-Chain `ci`; Schwelle `BENCH_THRESHOLD`, Standard 20 %). `--strict` lässt den Lauf bei Verschlechterung scheitern, `--update-baseline` speichert neue Vorwerte (bewusst committen). Der Router hat einen eigenen Rundlauf-Benchmark (`server.Router.rpcRundlauf`); `connectanum_bench` ist ein internes Werkzeug des connectanum-Projekts und wird nicht genutzt (siehe docs/erkenntnisse/wamp-router.md).

## Build-Chain

`.github/workflows/build-chain.yml` läuft bei jedem Push: Format und Analyse, Unit-Tests mit 100-%-Abdeckung, Mutation-Tests, Smoke-Tests headless in Chrome, Benchmarks (`BENCH_ENV=ci`) und – wenn alles grün ist – Build von Web-App und Server. Berichte und Build-Ergebnisse liegen als Artefakte am Lauf. Bis zum Go-Live wird erst nach grünem Lauf auf dem Feature-Branch lokal nach `main` gemergt.

## Server starten

Zwei getrennte Dienste – zuerst der Auth-Server, dann der Router; beide mit denselben Geheimnissen und je eigenem `TMPDIR` (connectanum erlaubt eine Transportschicht je temporärem Verzeichnis):

```bash
export PLANER_AUTH_TOKEN=… PLANER_AUTH_DIENST_TICKET=…
(cd packages/server && TMPDIR=/tmp/planer-auth/ dart run bin/auth_server.dart)
(cd packages/server && TMPDIR=/tmp/planer-router/ dart run bin/server.dart)
```

- Router: `PLANER_HOST` (127.0.0.1), `PLANER_PORT` (8080), `PLANER_WS_PFAD` (/ws), `PLANER_REALM`, `PLANER_HEALTH_LISTEN` (127.0.0.1:8081), `PLANER_AUTH_ADRESSE` (127.0.0.1:8082).
- Auth-Server: `PLANER_AUTH_LISTEN` (127.0.0.1:8082), `PLANER_AUTH_HEALTH_LISTEN` (127.0.0.1:8083), `PLANER_REALM`, `PLANER_MITARBEITER_DATEI` (JSON-Liste; Eintrag erzeugen mit `dart run bin/mitarbeiter_zugang.dart <authid>`).
- Rollen und Rechte: [docs/erkenntnisse/authentifizierung.md](docs/erkenntnisse/authentifizierung.md). Health-Prüfung: `curl http://127.0.0.1:8081/healthz`.

## connectanum-Versionen

`tool/connectanum_versionen.py` vergleicht die aufgelösten connectanum-Versionen mit pub.dev (mit `--issue`: legt ein GitHub-Issue an). Der Workflow `connectanum-versionen.yml` führt das täglich aus.

## Deployment

Ansible unter `deploy/` (Root-Server mit systemd oder Container-Betrieb, Traefik mit Let's Encrypt, Router und Auth-Server als getrennte Dienste): [deploy/README.md](deploy/README.md).
