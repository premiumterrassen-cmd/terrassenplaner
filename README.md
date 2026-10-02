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

Jedes performancerelevante Feature bekommt einen Benchmark in `packages/<paket>/benchmark/<name>_benchmark.dart` (`benchmark_harness`, Name im Format `<paket>.<Thema>`). `tool/benchmark.sh` führt alle aus, schreibt `benchmark-results/<umgebung>.json` und vergleicht mit `benchmarks/baseline-<umgebung>.json` (Umgebung `BENCH_ENV`, Standard `lokal`, in der Build-Chain `ci`; Schwelle `BENCH_THRESHOLD`, Standard 20 %). `--strict` lässt den Lauf bei Verschlechterung scheitern, `--update-baseline` speichert neue Vorwerte (bewusst committen). Transport-Benchmarks des WAMP-Routers mit `connectanum_bench` folgen mit M0-07.
