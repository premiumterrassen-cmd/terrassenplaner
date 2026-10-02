# CLAUDE.md – Terrassenplaner (ALTO HOLZ)

Verbindliche Projektregeln für die Arbeit an diesem Repository. Sie gelten für jede Änderung, ohne Ausnahme.

## Projekt

- Der neue Terrassenplaner von ALTO HOLZ.
- Repository: https://github.com/premiumterrassen-cmd/terrassenplaner (privat), Standard-Branch `main`.
- Frontend: Flutter.
- Basissoftware: `connectanum` (Dart, WAMP) in der neuesten Beta-Version; sobald `3.0.0` stabil erscheint, wird auf `3.0.0` umgestellt. Stand 02.10.2026: neueste Beta `3.0.0-beta.5`.

## Repository und Branches

- Alles, was an Quellcode entsteht, wird in dieses Repository committet. Nichts lebt nur lokal.
- Jedes Feature bekommt einen eigenen Feature-Branch (`feature/<kurzer-name>`), abgezweigt von `main`.
- Zurück nach `main` nur per Pull Request, und nur wenn alle Qualitätsschwellen unten erfüllt sind und die Build-Chain grün ist.
- Kleine, in sich abgeschlossene Commits mit aussagekräftiger Nachricht.

## Qualitätsschwellen (harte Gates)

| Bereich | Anforderung |
|---|---|
| Codeabdeckung | 100 % aller Quellcodezeilen durch Unit-Tests |
| Mutation-Tests | auf der Unit-Test-Suite, Ziel ≥ 95 % Mutation-Score |
| Frontend | Smoke-Tests als Flutter-Frontend-Tests (`integration_test`), lauffähig headless in Chrome |
| Benchmarks | je Feature ein Benchmark, sofern das Feature performancerelevant ist |
| Ansible | Deployment-Skripte sind selbst getestet |

- Ein Feature ist erst fertig, wenn Tests, Abdeckung, Mutation-Score und (falls relevant) Benchmark vorliegen.
- Abdeckung und Mutation-Score werden in der Build-Chain gemessen; unterschreitet ein Wert die Schwelle, schlägt der Build fehl.
- Benchmark-Ergebnisse werden je Feature festgehalten, damit Verschlechterungen sichtbar werden.

## Build-Chain

- Automatische Build-Chain für jeden Push und jeden Pull Request: Analyse/Lint, Unit-Tests mit Abdeckung, Mutation-Tests, Frontend-Smoke-Tests (headless Chrome), Benchmarks, Build der Artefakte.
- Ein roter Build blockiert den Merge nach `main`.

## Deployment-Chain

- Deployment mit Ansible.
- Ziele: der Root-Server **und** containerbasierte Systeme – dasselbe Ansible-Setup muss beides können.
- Das Ansible-Setup wird getestet (Lint und automatisierte Tests gegen beide Zielarten), bevor es produktiv läuft.
- Deployment erfolgt aus der Build-Chain heraus, nicht von Hand.

## Clean Code

- Gängige Clean-Code-Regeln: sprechende Namen, kleine Funktionen mit einer Aufgabe, keine Duplikate, klare Trennung von UI, Logik und Datenzugriff.
- Offizielle Dart/Flutter-Stilregeln und Lints einhalten; Analyzer ohne Warnungen.
- Kein toter Code, keine auskommentierten Codeblöcke.

## Dokumentation (folgt)

- `ROADMAP.md` – wird später angelegt.
- `docs/` – wird später angelegt; dort werden aktuelle Projektverläufe zwischengespeichert sowie Erkenntnisse aus Tests und Versuchen abgelegt.
