# CLAUDE.md – Terrassenplaner (ALTO HOLZ)

Verbindliche Projektregeln für die Arbeit an diesem Repository. Sie gelten für jede Änderung, ohne Ausnahme.

## Projekt

- Der neue Terrassenplaner von ALTO HOLZ.
- Repository: https://github.com/premiumterrassen-cmd/terrassenplaner (privat), Standard-Branch `main`.
- Ziel: Nachbau des bestehenden Terrassenkonfigurators https://terrassenkonfigurator.robinienwelt.de/ als **funktionale und inhaltliche 1:1-Kopie**, Schritt für Schritt (gleiche Schritte, Optionen, Standardwerte, Regeln, Ergebnisse).
- **Keine technische Kopie:** Von der alten Seite werden weder Code noch Architektur, Datenstrukturen oder Programmierkonzepte übernommen. Fachliche Quellen sind nur die Bedienung, die sichtbaren Texte/Optionen und die Ergebnisse (Planungsunterlagen, Exporte). Der Programmcode der alten Seite wird nicht analysiert.
- Frontend: Flutter (Web).
- Basissoftware: connectanum (Dart, WAMP) in der neuesten Beta-Version; sobald `3.0.0` stabil erscheint, wird auf `3.0.0` umgestellt. Stand 02.10.2026: `3.0.0-beta.5`. Verwendet werden `connectanum_client` (App), `connectanum_router` (eigener WAMP-Router) und `connectanum_auth_server` (Authentifizierung); für Transport-Benchmarks `connectanum_bench`.

## Roadmap und Issues

- Planung in GitHub-Meilensteinen (M0–M10) mit konkreten Issues; eine Kopie steht in `ROADMAP.md`, damit neue Chats den Stand schnell erfassen. Bei jeder Änderung beides pflegen.
- Jedes Issue nennt seinen Feature-Branch; der Merge-Commit nach `main` schließt das Issue (`Closes #<nr>`), der Status in `ROADMAP.md` wird im selben Merge aktualisiert.

## Daten und Vertraulichkeit

- Artikeldaten kommen aus dem Blatt „Import Terrassenplaner“ der Master-Artikelliste (`Robinienwelt/Analyse Claude`). Ins Repository gelangen nur Verkaufsdaten – niemals Einstandspreise, Werks-EK, Lieferanten oder Margen.
- Testdaten aus echten Planungsunterlagen nur anonymisiert (keine Namen, Adressen, Telefonnummern, E-Mails).
- Fachliche Regeln der Firma stehen in den Skills robinienwelt-unternehmensprofil, robinienwelt-sortimentsmatrix-2027 und robinienwelt-beschluesse; Beschlussnummern (B-xxx) in Code-Kommentaren und Tests nennen, wo eine Regel umgesetzt wird.
- **Beschlussregister:** `Robinienwelt/Analyse Claude/Beschluesse_RobinienWelt_vN.md` – immer die höchste Versionsnummer gilt (Stand 02.10.2026: v30). Vor fachlichen Entscheidungen lesen; widerspricht etwas einem Beschluss mit Status „gilt“, Alexander mit Nummer und Wortlaut fragen statt abzuweichen. Für den Planer besonders relevant:
  - B-122: Master-Artikelliste ist die eine Quelle; in den Planer nur Artikel mit „im Planer = ja“.
  - B-152 / B-065 / B-123: Artikelnummern, Titel und Preise im Planer wie im Shop (Titelschema v10, PREMIUM überall 10-10-xxx-R).
  - B-055: GrandTotal ist führende Preisquelle, Planer-Preise sind nur Anzeige.
  - B-079: Freidielen im Planer fest ab 25 Dielen.
  - B-094 / B-150 / B-074 / B-153: Befestigung (CLIP-FIXX bis < 100 mm, DUO-CLIP-FIXX für PREMIUM SELECT ab 100 mm, Schrauben im Clip-Lieferumfang, CLIP-FIXX-Preise bleiben).
  - B-030–B-036: Sortiment, Längen je Werk, UK-Breite/Stärke tauschbar, keine einseitig genuteten Dielen.
  - B-020 / B-021 / B-023: Vertraulichkeit (Lieferanten, EK, Spediteur/Lager, Hersteller der Eigenmarken) – nie in Oberfläche, PDF oder Export.

## Repository und Branches

- Alles, was an Quellcode entsteht, wird in dieses Repository committet. Nichts lebt nur lokal.
- Jedes Feature bekommt einen eigenen Feature-Branch (`feature/<kurzer-name>`), abgezweigt von `main`.
- **Entwicklungsphase (bis zum ersten Live-Deployment): keine Pull Requests.** Feature-Branches werden lokal nach `main` gemergt (`git merge --no-ff`) und gepusht – nur wenn alle Qualitätsschwellen unten erfüllt sind und die Build-Chain grün ist. Nach dem ersten Live-Deployment: Merge nach `main` nur per Pull Request (Vorgabe Alexander 02.10.2026).
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

- Automatische Build-Chain für jeden Push (und nach dem Go-Live für jeden Pull Request): Analyse/Lint, Unit-Tests mit Abdeckung, Mutation-Tests, Frontend-Smoke-Tests (headless Chrome), Benchmarks, Build der Artefakte.
- Ein roter Build blockiert den Merge nach `main`.

## Deployment-Chain

- Deployment mit Ansible.
- Ziele: der Root-Server **und** containerbasierte Systeme – dasselbe Ansible-Setup muss beides können.
- Das Ansible-Setup wird getestet (Lint und automatisierte Tests gegen beide Zielarten), bevor es produktiv läuft.
- Deployment erfolgt aus der Build-Chain heraus, nicht von Hand.
- **Zielserver (Root-Server):** `v2202610430314532119.happysrv.de` (IP 62.83.40.123), Debian 13 „trixie“, 2 Kerne, 3,8 GB RAM, 62 GB Platte; Stand 02.10.2026 frisch: Python 3.13 vorhanden, kein Docker/Podman/Traefik, nur Port 22 offen. Domain: **`alto.terrassenplaner.eu`** – A-Record zeigt auf 62.83.40.123 (geprüft 02.10.2026, kein AAAA, kein CAA-Eintrag; DNS bei united-domains). Zugang per SSH als `root` mit Schlüssel (lokaler SSH-Alias `happysrv`). Passwort-Anmeldung ist noch an – Abschalten (nur Schlüssel) gehört ins Ansible-Setup. Das automatische Deployment aus der Build-Chain bekommt einen eigenen Deploy-Schlüssel.
- **Reverse Proxy: Traefik** (Vorgabe Alexander 02.10.2026) – auf dem Root-Server und im Container-Betrieb gleichermaßen; die Ansible-Rollen richten Traefik mit ein.
  - TLS-Zertifikate automatisch über **Let's Encrypt** (ACME-Resolver in Traefik), automatische Verlängerung; HTTP wird auf HTTPS umgeleitet.
  - Traefik ist der einzige von außen erreichbare Dienst (Ports 80/443); WAMP-Router, Server-Dienste und Web-App laufen nur intern dahinter. WebSocket-Verbindungen für WAMP laufen über Traefik.
  - Zertifikatsspeicher (`acme.json`) bleibt dauerhaft erhalten (eigenes Volume/Verzeichnis, Rechte 600) und wird nie ins Repository übernommen.
  - Domain und Let's-Encrypt-E-Mail sind Ansible-Variablen je Inventory; in Tests und Testumgebung wird die Let's-Encrypt-Staging-Umgebung oder ein lokales ACME-Testsystem genutzt, um die Rate-Limits der Produktiv-CA nicht zu belasten.

## Clean Code

- Gängige Clean-Code-Regeln: sprechende Namen, kleine Funktionen mit einer Aufgabe, keine Duplikate, klare Trennung von UI, Logik und Datenzugriff.
- Offizielle Dart/Flutter-Stilregeln und Lints einhalten; Analyzer ohne Warnungen.
- Kein toter Code, keine auskommentierten Codeblöcke.

## Dokumentation (folgt)

- `ROADMAP.md` – angelegt (Kopie der GitHub-Meilensteine und Issues).
- `docs/` – wird später angelegt; dort werden aktuelle Projektverläufe zwischengespeichert sowie Erkenntnisse aus Tests und Versuchen abgelegt.
