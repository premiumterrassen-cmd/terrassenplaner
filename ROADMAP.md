# ROADMAP – Terrassenplaner (ALTO HOLZ)

Kopie der GitHub-Meilensteine und -Issues, damit neue Chats den Projektstand schnell erfassen.
Führend ist GitHub: https://github.com/premiumterrassen-cmd/terrassenplaner/milestones – bei Änderungen beides pflegen.

## Ziel und Grundsatz

- Nachbau des Terrassenkonfigurators https://terrassenkonfigurator.robinienwelt.de/ als **funktionale und inhaltliche 1:1-Kopie**, Schritt für Schritt.
- **Keine technische Kopie:** kein Code, keine Architektur, keine Datenstrukturen, keine Programmierkonzepte der alten Seite. Fachliche Quellen sind nur die Bedienung, die sichtbaren Texte/Optionen und die Ergebnisse (Planungsunterlagen, Exporte).
- Technik: Flutter (Web), Dart-Server mit `connectanum_router` und `connectanum_auth_server`, Client `connectanum_client` (alle 3.0.0-beta.5, auf 3.0.0 umstellen, sobald stabil).
- Im alten Planer abgeschaltete Funktionen (3D-Ansicht, Grundriss-Upload, Podest, Gehrungsschnitt der Form, Rahmendielen, eigene UK, Teilen) sind **nicht** Teil der Kopie.

## Quellen

- Artikeldaten: `Robinienwelt/Analyse Claude/Master-Artikelliste_v14.xlsx`, Blatt „Import Terrassenplaner“ (nur Verkaufsdaten, nie Einstandspreise).
- Firmenregeln: Skills robinienwelt-unternehmensprofil, robinienwelt-sortimentsmatrix-2027, robinienwelt-beschluesse (Beschlussnummern B-xxx).
- Prüfdaten: `Robinienwelt/Dateien_Terrassenkonfigurator/Planungsunterlagen` (48 PDF) und `CSV_Downloads` – Kundendaten nur anonymisiert ins Repository.

## Arbeitsweise

- Je Issue ein Feature-Branch (Name steht im Issue). Bis zum ersten Live-Deployment **keine Pull Requests**: lokal nach `main` mergen (`--no-ff`, Merge-Commit mit `Closes #<nr>`) und pushen; danach Merge nur per Pull Request.
- Status hier: `[ ]` offen · `[~]` in Arbeit · `[x]` erledigt.

## M0 Fundament

Repository-Struktur, Qualitätsschwellen, Build- und Deployment-Chain, WAMP-Router und Auth – ein „Hallo Welt“ läuft automatisiert getestet auf dem Root-Server und im Container.

GitHub: https://github.com/premiumterrassen-cmd/terrassenplaner/milestone/1

- [x] **M0-01 Workspace anlegen: App, Server, gemeinsames Fachmodul** ([#1](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/1)) – `feature/m0-01-workspace-anlegen-app-server-gemeinsames`
  - Dart/Flutter-Workspace mit drei Paketen: `app` (Flutter Web), `server` (Dart, WAMP-Router + Auth + Dienste), `domain` (reine Fachlogik ohne UI/IO, von App und Server genutzt). Abhängigkeiten auf connectanum 3.0.0-beta.5 (`connectanum_client`, `connectanum_router`, `connectanum_auth_server`).
  - Abnahme: `dart analyze` ohne Hinweise mit strengem Lint-Set; Jedes Paket hat mindestens einen Test; README beschreibt Aufbau und lokale Befehle
- [x] **M0-02 Unit-Tests mit Abdeckungs-Gate 100 %** ([#2](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/2)) – `feature/m0-02-unit-tests-mit-abdeckungs-gate-100`
  - Abdeckung für alle Pakete messen (lcov), zusammenführen und hart prüfen. Generierter Code wird ausgeschlossen, alles andere zählt.
  - Abnahme: Skript `tool/coverage` liefert Gesamtwert und bricht unter 100 % mit Fehler ab; Bericht als Build-Artefakt
- [ ] **M0-03 Mutation-Tests mit Ziel ≥ 95 %** ([#3](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/3)) – `feature/m0-03-mutation-tests-mit-ziel-95`
  - Werkzeug für Mutation-Tests in Dart auswählen und begründen (Erkenntnis in docs/), auf die Unit-Test-Suite anwenden, Mutation-Score messen.
  - Abnahme: Mutation-Score wird je Paket berichtet; Gate in der Build-Chain (Startwert dokumentiert, Ziel 95 %); Laufzeit für PRs vertretbar (ggf. nur geänderte Dateien)
- [ ] **M0-04 Frontend-Smoke-Tests headless in Chrome** ([#4](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/4)) – `feature/m0-04-frontend-smoke-tests-headless-in-chrome`
  - Flutter-Frontend-Tests (`integration_test`) gegen die Web-App, headless in Chrome, lokal und in der Build-Chain.
  - Abnahme: Ein Smoke-Test startet die App und prüft den Eingangsdialog; Läuft headless in der CI
- [ ] **M0-05 Benchmark-Rahmen** ([#5](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/5)) – `feature/m0-05-benchmark-rahmen`
  - Einheitlicher Rahmen für Feature-Benchmarks (Fachlogik) plus Transport-Benchmarks mit `connectanum_bench`; Ergebnisse versioniert ablegen und gegen Vorwert vergleichen.
  - Abnahme: Beispiel-Benchmark läuft lokal und in CI; Ergebnisse als JSON-Artefakt, Verschlechterung > Schwelle wird gemeldet
- [ ] **M0-06 Build-Chain (GitHub Actions)** ([#6](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/6)) – `feature/m0-06-build-chain-github-actions`
  - Pipeline für Push und PR: Format, Analyse, Unit-Tests + Abdeckung, Mutation-Tests, Smoke-Tests, Benchmarks, Build Web-App und Server-Artefakt.
  - Abnahme: Alle Schritte grün auf `main`; Bis Go-Live lokaler Merge nach grüner Pipeline auf dem Feature-Branch; Branch-Schutz (Merge nur per PR) wird beim Go-Live (M10-03) aktiviert
- [ ] **M0-07 WAMP-Router aufsetzen** ([#7](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/7)) – `feature/m0-07-wamp-router-aufsetzen` · Benchmark
  - `connectanum_router` (3.0.0-beta.5) als Server-Prozess mit Konfiguration (Realm, Transport WebSocket, Serialisierung), Healthcheck und Logging.
  - Abnahme: Router startet mit Konfigurationsdatei; Client aus Test verbindet sich, ruft RPC auf, empfängt Event; Healthcheck-Endpunkt für Deployment
- [ ] **M0-08 Authentifizierung mit connectanum_auth_server** ([#8](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/8)) – `feature/m0-08-authentifizierung-mit-connectanum-auth-s` · Benchmark
  - Auth-Konzept: Kunden anonym mit eingeschränkter Rolle; Mitarbeiter mit Anmeldung (der alte Planer hat eine Login-Funktion). Rollen und erlaubte RPC/Topics je Rolle festlegen.
  - Abnahme: Anonymer Client darf nur Kunden-RPCs; Angemeldeter Mitarbeiter darf zusätzlich Mitarbeiter-RPCs; Tests für erlaubte und verbotene Aufrufe
- [ ] **M0-09 Ansible: Deployment Root-Server und Container** ([#9](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/9)) – `feature/m0-09-ansible-deployment-root-server-und-conta`
  - Ansible-Rollen für (a) Root-Server: Benutzer, systemd-Dienste Router/Server, Auslieferung der Web-App; (b) containerbasiert: Image(s) bauen und starten. In beiden Zielarten **Traefik als Reverse Proxy** mit automatischen **Let's-Encrypt-Zertifikaten** (HTTP → HTTPS, nur Ports 80/443 offen, WebSocket für WAMP, `acme.json` persistent mit Rechten 600). Gemeinsame Variablen (u. a. Domain, Let's-Encrypt-E-Mail), zwei Inventories.
  - Abnahme: Beide Zielarten mit demselben Playbook-Satz deploybar; Traefik liefert die App per HTTPS mit gültigem Zertifikat aus, WAMP-WebSocket funktioniert durch Traefik; Router und Dienste von außen nicht direkt erreichbar; Keine Secrets im Repository (Vault/Umgebung, hinterlegt durch Alexander)
- [ ] **M0-10 Ansible testen: Lint und Molecule** ([#10](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/10)) – `feature/m0-10-ansible-testen-lint-und-molecule`
  - `ansible-lint` und Molecule-Szenarien für beide Zielarten (Root-Server simuliert, Container), inkl. Idempotenz-Prüfung, in der Build-Chain. Traefik und Zertifikatsbezug werden gegen die Let's-Encrypt-Staging-Umgebung bzw. ein lokales ACME-Testsystem geprüft.
  - Abnahme: Lint ohne Befund; Molecule converge + idempotence + verify für beide Szenarien grün in CI
- [ ] **M0-11 Deployment-Chain aus der CI** ([#11](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/11)) – `feature/m0-11-deployment-chain-aus-der-ci`
  - Automatisches Deployment nach Merge auf `main` in eine Testumgebung; Produktiv-Deployment per Freigabe.
  - Abnahme: Merge auf `main` deployt Testumgebung; Produktiv nur nach manueller Freigabe; Rollback dokumentiert
- [ ] **M0-12 „Hallo Welt“ Ende-zu-Ende** ([#12](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/12)) – `feature/m0-12-hallo-welt-ende-zu-ende`
  - Web-App verbindet sich über WAMP mit dem Router, ruft einen Dienst auf und zeigt das Ergebnis – automatisiert deployt.
  - Abnahme: Smoke-Test gegen die deployte Testumgebung grün

## M1 Fachkonzept & Prüfdaten

Der alte Planer ist fachlich vollständig beschrieben (Schritte, Optionen, Standardwerte, Grenzen, Hinweise, Ergebnisse) und es gibt Referenzfälle mit erwarteten Ergebnissen. Ausschließlich aus Bedienung, sichtbaren Texten und Planungsunterlagen – keine Code-Analyse.

GitHub: https://github.com/premiumterrassen-cmd/terrassenplaner/milestone/2

- [ ] **M1-01 Funktionsinventar des alten Planers** ([#13](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/13)) – `feature/m1-01-funktionsinventar-des-alten-planers`
  - Jeden Schritt des alten Planers bedienen und fachlich beschreiben: Eingaben, Auswahlmöglichkeiten, Standardwerte, Grenzwerte, Hinweise/Warnungen, Auswirkungen auf Zeichnung und Material. Quelle: Bedienung und sichtbare Texte/Optionen – keine Analyse des Programmcodes.
  - Abnahme: `docs/fachkonzept/` mit einem Kapitel je Schritt (Grundriss … Zubehör, Ergebnisse); Liste der im alten Planer abgeschalteten Funktionen (z. B. 3D, Grundriss-Upload, Podest, Gehrungsschnitt) als „nicht Teil der Kopie“
- [ ] **M1-02 Referenzfälle aus Planungsunterlagen** ([#14](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/14)) – `feature/m1-02-referenzfaelle-aus-planungsunterlagen`
  - Die 48 Planungsunterlagen-PDFs und Exporte (`Dateien_Terrassenkonfigurator`) auswerten: Eingaben (Form, Maße, Belag, Richtung, UK, Höhen) und erwartete Ergebnisse (Stücklisten, Zuschnitt, Mengen) als maschinenlesbare Referenzfälle. Kundendaten werden anonymisiert.
  - Abnahme: Referenzfälle als Testdaten im Repo, ohne Namen/Adressen/Telefon/E-Mail; Je Fall: Eingaben, erwartete Mengen je Artikel, Quelle
- [ ] **M1-03 Referenzkonfigurationen im alten Planer nachstellen** ([#15](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/15)) – `feature/m1-03-referenzkonfigurationen-im-alten-planer`
  - Gezielte Testfälle im alten Planer durchspielen (jede Form, jede Verlegeart/-richtung, Gefälle, Ausschnitt, Rundung, Treppe, Verblendung, Rinne) und Ergebnisse (PDF, Materialliste) festhalten.
  - Abnahme: Mind. ein Fall je Option aus M1-01; Ergebnisse als Referenz neben M1-02
- [ ] **M1-04 Planungsregeln aus Firmenwissen** ([#16](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/16)) – `feature/m1-04-planungsregeln-aus-firmenwissen`
  - Regeln aus Unternehmensprofil, Sortimentsmatrix und Beschlussregister als Fachregeln beschreiben: UK-Achsabstand max. 40 cm, Befestigung nach B-094 (CLIP-FIXX bis < 100 mm, DUO-CLIP-FIXX für PREMIUM SELECT ab 100 mm), Freidielen ab 25 Dielen (B-079), keine einseitig genuteten Dielen/Anfangs-/Enddiele = normale Diele (B-033), Längen je Werk (B-035), UK Breite/Stärke tauschbar (B-034), Nummern wie im Shop (B-152).
  - Abnahme: Regelkatalog mit Quelle (Beschluss-Nr.) je Regel; Widersprüche zum alten Planer sind markiert und von Alexander entschieden

## M2 Artikeldaten & Regelwerk

Artikel aus dem Blatt „Import Terrassenplaner“ der Master-Artikelliste werden eingelesen, geprüft und über WAMP bereitgestellt; die Abhängigkeiten zwischen Artikeln sind als eigenes Regelwerk modelliert.

GitHub: https://github.com/premiumterrassen-cmd/terrassenplaner/milestone/3

- [ ] **M2-01 Fachmodell Artikel** ([#17](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/17)) – `feature/m2-01-fachmodell-artikel`
  - Eigenes Fachmodell für Dielen, Unterkonstruktion, Befestigung, Stellfüße, Pads, Verbinder (längs, quer, Eck, variabel), Verblendung, Rinnen, Zubehör – mit Einheiten (mm, lfm, Stück, VPE) und Preisangaben (Anzeige).
  - Abnahme: Modell im Paket `domain`, unabhängig vom Importformat; Einheiten typsicher (keine nackten Zahlen für mm/cm)
- [ ] **M2-02 Import aus „Import Terrassenplaner“** ([#18](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/18)) – `feature/m2-02-import-aus-import-terrassenplaner` · Benchmark
  - Importer für das Blatt „Import Terrassenplaner“ der Master-Artikelliste (xlsx) → geprüfte Artikeldatei für den Server. Nur Verkaufsdaten, niemals Einstandspreise/Werks-EK (B-020).
  - Abnahme: Import der aktuellen Liste (234 Zeilen) ohne Fehler; Test: EK-Spalten werden nie übernommen; Hinweis: Maßspalten heißen _cm, enthalten aber mm
- [ ] **M2-03 Datenprüfung beim Import** ([#19](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/19)) – `feature/m2-03-datenpruefung-beim-import`
  - Prüfungen: Pflichtfelder, plausible Maße, doppelte Artikelnummern, Verweise auf nicht vorhandene Artikel, unbekannte Artikeltypen; verständlicher Prüfbericht.
  - Abnahme: Prüfbericht listet jeden Befund mit Zeile und Feld; Import bricht bei kritischen Fehlern ab
- [ ] **M2-04 Regelwerk Abhängigkeiten** ([#20](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/20)) – `feature/m2-04-regelwerk-abhaengigkeiten` · Benchmark
  - Eigenes Regelwerk für „was passt zu was“: Befestigung je Belag, Zubehör, Stellfüße privat/gewerblich, Unterlegpads, Längs-/Quer-/Eck-/variable Verbinder, Verblendung, Entwässerung, Pflichtzubehör mit Anzahl; Abstände (UK, Stellfüße, Randabstand), Min-/Max-Höhe.
  - Abnahme: Für jeden Belag liefert das Regelwerk dieselben Auswahlmöglichkeiten wie der alte Planer (Abgleich mit M1); Regeln datengetrieben aus dem Import, nicht im Code fest verdrahtet
- [ ] **M2-05 Artikelnummern vereinheitlichen (B-152)** ([#21](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/21)) – `feature/m2-05-artikelnummern-vereinheitlichen-b-152`
  - Verweise in den Abhängigkeiten nutzen teils EAN, teils Artikelnummern. Zuordnungstabelle EAN → Shop-Artikelnummer erstellen; Lücken Alexander zur Entscheidung vorlegen.
  - Abnahme: Alle Verweise auf Shop-Artikelnummern abgebildet oder als offen markiert; Freigabe Alexander dokumentiert
- [ ] **M2-06 Artikeldienst über WAMP** ([#22](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/22)) – `feature/m2-06-artikeldienst-ueber-wamp` · Benchmark
  - RPCs zum Abruf von Artikeln, Filtern (Material, Farbe, Oberseite) und Regelwerk; Client-seitiges Zwischenspeichern; Versionskennung der Artikeldaten.
  - Abnahme: App lädt Artikel nur über WAMP; Neue Artikeldaten ohne App-Update wirksam
- [ ] **M2-07 Artikelbilder bereitstellen** ([#23](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/23)) – `feature/m2-07-artikelbilder-bereitstellen`
  - Abbildung 1–3 je Artikel (Planer_Bilder) ausliefern, für Web optimiert.
  - Abnahme: Jeder Artikel mit Bild oder definiertem Platzhalter

## M3 Oberfläche: Grundgerüst

Rahmen der App mit Schrittleiste, nummeriertem Menü, Zeichenfläche, Ansichtsoptionen und Eingangsdialog – funktional wie der alte Planer, in eigenem Design-System.

GitHub: https://github.com/premiumterrassen-cmd/terrassenplaner/milestone/4

- [ ] **M3-01 App-Rahmen und Design-System** ([#24](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/24)) – `feature/m3-01-app-rahmen-und-design-system`
  - Kopfbereich mit Logo, Schrittleiste mit sieben Stationen (Fortschritt), nummeriertes Bearbeitungsmenü (ein-/ausklappbar), Zeichenfläche, Anzeige Fläche/Volumen; Markenfarben (#B0864B, #95c11c), Schrift. Eigenes Design-System.
  - Abnahme: Smoke-Test: alle Stationen erreichbar; Layout Desktop und Tablet
- [ ] **M3-02 Eingangsdialog** ([#25](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/25)) – `feature/m3-02-eingangsdialog`
  - Neu konfigurieren · Konfiguration laden (Nummer + Version) · „Weiterplanen“, wenn eine zwischengespeicherte Konfiguration gefunden wird.
  - Abnahme: Alle drei Wege funktionieren (Laden ab M9-05)
- [ ] **M3-03 Zeichenfläche: Zoom, Verschieben, Rückgängig, Zurücksetzen** ([#26](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/26)) – `feature/m3-03-zeichenflaeche-zoom-verschieben-rueckgae` · Benchmark
  - Vergrößern/Verkleinern, Zoom zurücksetzen, Fläche verschieben, rückgängig, Konfiguration zurücksetzen mit Sicherheitsabfrage.
  - Abnahme: Rückgängig stellt den vorherigen Planungsstand exakt wieder her; Zurücksetzen nur nach Bestätigung
- [ ] **M3-04 Ansichtsoptionen** ([#27](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/27)) – `feature/m3-04-ansichtsoptionen`
  - Terrassenbelag, Unterkonstruktion, Terrassenmaße ein-/ausblenden; Beschriftungen für Seitenlängen, Winkel, Punkte, Abläufe schaltbar.
  - Abnahme: Jede Option wirkt sofort auf die Zeichnung
- [ ] **M3-05 Hinweis bei beibehaltenen Standardwerten** ([#28](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/28)) – `feature/m3-05-hinweis-bei-beibehaltenen-standardwerten`
  - Vor dem Weitergehen Hinweis, bei welchen Schritten Standardwerte beibehalten wurden (fortfahren/zurück).
  - Abnahme: Hinweis listet die betroffenen Schritte korrekt
- [ ] **M3-06 Rechtliche Links und Fußbereich** ([#29](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/29)) – `feature/m3-06-rechtliche-links-und-fussbereich`
  - Links AGB, Datenschutz, Impressum; Schaltflächen „Konfiguration anfordern“, „Montageanleitung“, „PDF“, „Video-Beratung buchen“.
  - Abnahme: Links zeigen auf die aktuellen Seiten von robinienwelt.de
- [ ] **M3-07 Mehrsprachigkeit vorbereiten** ([#30](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/30)) – `feature/m3-07-mehrsprachigkeit-vorbereiten`
  - Alle Texte über Übersetzungsdateien (Deutsch zuerst); der alte Planer hat eine Sprachauswahl.
  - Abnahme: Keine fest im Code stehenden Oberflächentexte
- [ ] **M3-08 Ladebildschirm mit echtem Fortschritt** ([#90](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/90)) – `feature/m3-08-ladebildschirm-mit-echtem-fortschritt` · Benchmark
  - Vorbild https://www.dls-gmbh.biz/mein-essen (nur Verfahren): HTML-Ladebildschirm in `web/index.html` mit Hintergrundbild, Karte, Fortschrittsbalken und Prozent; echter Fortschritt aus beim Build erzeugter Größenliste der Startdateien und mitgezählten Bytes; Statusphasen, Langsam/Offline/Fehler mit „Erneut versuchen“; Ausblenden nach erstem Bild.
  - Abnahme: sofort sichtbar; Prozent monoton bis 100 % auch mit Cache; Größenliste automatisch im Build; Fehlerzustände getestet; barrierefrei

## M4 Grundriss

Alle im alten Planer aktiven Terrassenformen, Freiform-Zeichnen, Eckpunkt-/Kantenbearbeitung, Rundungen und Ausschnitte inkl. Flächen- und Volumenberechnung.

GitHub: https://github.com/premiumterrassen-cmd/terrassenplaner/milestone/5

- [ ] **M4-01 Geometrie-Kern** ([#31](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/31)) – `feature/m4-01-geometrie-kern` · Benchmark
  - Polygone mit Bögen, Fläche, Umfang, Winkel, Punkt-in-Fläche, Schnitt/Vereinigung/Differenz, Abstands- und Kollisionsprüfung – Grundlage für Grundriss, Belag und UK.
  - Abnahme: Eigenschaftsbasierte Tests (z. B. Fläche invariant unter Drehung); Benchmark für komplexe Formen mit Ausschnitten
- [ ] **M4-02 Rechteck mit Maßen** ([#32](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/32)) – `feature/m4-02-rechteck-mit-massen`
  - Rechteck als Standardform, Maße A–B und B–C in cm.
  - Abnahme: Fläche und Zeichnung stimmen mit Eingabe überein
- [ ] **M4-03 L-Form** ([#33](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/33)) – `feature/m4-03-l-form`
  - L-Form (im alten Planer ist eine L-Variante aktiv) mit allen Seitenmaßen.
  - Abnahme: Seitenmaße editierbar, Fläche korrekt
- [ ] **M4-04 T-Form** ([#34](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/34)) – `feature/m4-04-t-form`
  - T-Form mit allen Seitenmaßen.
  - Abnahme: Seitenmaße editierbar, Fläche korrekt
- [ ] **M4-05 U-Form** ([#35](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/35)) – `feature/m4-05-u-form`
  - U-Form mit allen Seitenmaßen.
  - Abnahme: Seitenmaße editierbar, Fläche korrekt
- [ ] **M4-06 O-Form** ([#36](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/36)) – `feature/m4-06-o-form`
  - O-Form (Fläche mit innerer Aussparung).
  - Abnahme: Innen- und Außenmaße editierbar
- [ ] **M4-07 Kreis** ([#37](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/37)) – `feature/m4-07-kreis`
  - Kreisförmige Terrasse mit Durchmesser.
  - Abnahme: Fläche korrekt, Verblendung „Fläche verblenden“ statt Seiten (M7)
- [ ] **M4-08 Freiform zeichnen** ([#38](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/38)) – `feature/m4-08-freiform-zeichnen`
  - Punkte setzen, Form schließen (mind. 3 Punkte), Einrastfunktion, Zeichnungshilfe (Seitenlänge/Winkel korrigieren), letzten Punkt entfernen, Rückmeldungen.
  - Abnahme: Form lässt sich nur mit ≥ 3 Punkten schließen; Zeichnungshilfe korrigiert Länge und Winkel auf Eingabewert
- [ ] **M4-09 Eckpunkte und Kanten bearbeiten** ([#39](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/39)) – `feature/m4-09-eckpunkte-und-kanten-bearbeiten`
  - Eckpunkte hinzufügen/entfernen (min. 3)/ziehen, Kanten verschieben, Maße per Eingabe; Umschalter Koordinaten/Strecke.
  - Abnahme: Mindestens 3 Eckpunkte erzwungen; Eingabe per Koordinaten und per Strecke
- [ ] **M4-10 Form drehen und zentrieren** ([#40](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/40)) – `feature/m4-10-form-drehen-und-zentrieren`
  - Form rotieren (Hinweis: Ausschnitte werden zurückgesetzt), zentrieren.
  - Abnahme: Ausschnitte werden nach Bestätigung zurückgesetzt
- [ ] **M4-11 Ecken und Seiten abrunden** ([#41](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/41)) – `feature/m4-11-ecken-und-seiten-abrunden`
  - Rundungen an Ecken und Seiten im eigenen Bearbeitungsmodus; übernehmen/zurücksetzen; unzulässige Rundungen abweisen.
  - Abnahme: Unzulässige Rundung wird gemeldet; Verlassen des Modus fragt nach Übernehmen/Zurücksetzen
- [ ] **M4-12 Ausschnitte und Teilflächen** ([#42](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/42)) – `feature/m4-12-ausschnitte-und-teilflaechen` · Benchmark
  - Weitere Flächen: Form, Maße/Radius, Koordinaten (A = 0|0, negative Werte möglich), Bezeichnung (max. 10 Zeichen), Funktion „leere Fläche“ oder „anderer Terrassenbelag“; Prüfungen: nicht außerhalb, keine Kollision, keine Teilung des Grundrisses; Einrasten.
  - Abnahme: Alle drei Prüfungen mit Meldung; Teilfläche mit anderem Belag wird in M5 separat belegt
- [ ] **M4-13 Fläche und Volumen** ([#43](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/43)) – `feature/m4-13-flaeche-und-volumen`
  - Laufende Anzeige Terrassenfläche (m²) und Holzvolumen (m³).
  - Abnahme: Werte stimmen mit Referenzfällen (M1-02) überein

## M5 Terrassenbelag

Belagauswahl, Längen, Verlegearten und -richtungen, Ausgangspunkt, Befestigungsart und die Berechnung der Dielenverlegung.

GitHub: https://github.com/premiumterrassen-cmd/terrassenplaner/milestone/6

- [ ] **M5-01 Belagauswahl** ([#44](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/44)) – `feature/m5-01-belagauswahl`
  - Dialog „Produktauswahl“: Holzdielen mit Filtern (Material, Farbe, Oberseite) und Suche; Infobox (Artikelinfo, Ober-/Unterseite, Abmessungen, Preis je lfm und je m², Artikelnummer); Anzeige Maße und Fuge.
  - Abnahme: Nur Artikel aus M2 mit Typ Belag; Infobox zeigt alle Felder
- [ ] **M5-02 Dielenlängen** ([#45](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/45)) – `feature/m5-02-dielenlaengen` · Benchmark
  - „Dielenlänge automatisch ermitteln?“ ja/nein; bei nein bevorzugte Längen auswählen (feste Längen je Artikel).
  - Abnahme: Automatik wählt Längen wie der alte Planer (Referenzfälle)
- [ ] **M5-03 Kurze Dielenstücke verbinden** ([#46](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/46)) – `feature/m5-03-kurze-dielenstuecke-verbinden`
  - Option „Sollen kurze Dielenstücke miteinander verbunden werden?“ ja/nein mit Auswirkung auf Stöße und Verschnitt.
  - Abnahme: Beide Varianten ergeben die Ergebnisse der Referenzfälle
- [ ] **M5-04 Verlegearten** ([#47](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/47)) – `feature/m5-04-verlegearten` · Benchmark
  - Fugenschnitt (Standard), Halbverband, Drittelverband, Wechselverband; „Auf Fuge geschnitten“.
  - Abnahme: Stoßmuster je Verlegeart wie im alten Planer
- [ ] **M5-05 Verlegerichtungen** ([#48](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/48)) – `feature/m5-05-verlegerichtungen` · Benchmark
  - Waagerecht (Standard), senkrecht, 45°, 135°, individueller Winkel.
  - Abnahme: Jede Richtung in Zeichnung und Mengen korrekt
- [ ] **M5-06 Stoßdielen im Gehrungsschnitt** ([#49](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/49)) – `feature/m5-06-stossdielen-im-gehrungsschnitt`
  - Option „Möchten Sie Stoßdielen im Gehrungsschnitt verwenden?“ (im alten Planer aktiv).
  - Abnahme: Option wirkt auf Zeichnung und Zuschnitt
- [ ] **M5-07 Ausgangspunkt der Verlegung** ([#50](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/50)) – `feature/m5-07-ausgangspunkt-der-verlegung`
  - Eckpunkt als Ausgangspunkt wählen; erste ganze Diele links/rechts und oben/unten verschieben (Maus oder Eingabe, max. eine Belagbreite/-länge); Warnung bei Zuschnitten < 5 cm.
  - Abnahme: Grenzen und Warnung wie beschrieben
- [ ] **M5-08 Berechnung der Dielenverlegung** ([#51](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/51)) – `feature/m5-08-berechnung-der-dielenverlegung` · Benchmark
  - Dielen in der Fläche inkl. Ausschnitten, Rundungen und Teilflächen verlegen, nummerieren, Längen und Fugen berücksichtigen.
  - Abnahme: Dielenliste je Referenzfall entspricht der Planungsunterlage; Benchmark: große Freiform mit Ausschnitten
- [ ] **M5-09 Befestigungsart** ([#52](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/52)) – `feature/m5-09-befestigungsart`
  - Mit Clips / direkt verschraubt / verschraubt mit Abstandshaltern; Befestigungsartikel und Mengen nach Regelwerk (inkl. B-094).
  - Abnahme: PREMIUM SELECT genutet ab 100 mm → DUO-CLIP-FIXX, sonst CLIP-FIXX
- [ ] **M5-10 Grenzwerte und Meldungen Belag** ([#53](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/53)) – `feature/m5-10-grenzwerte-und-meldungen-belag`
  - Grenzen für Belagbreite, -länge, -stärke und Profile mit verständlichen Meldungen.
  - Abnahme: Jede Grenze getestet

## M6 Unterkonstruktion

Terrassenart, Höhenpunkte/Gefälle, UK-Auswahl, Untergrund, Nutzungsart, Querstreben, Stellfüße/Pads und die Berechnung der UK-Verlegung.

GitHub: https://github.com/premiumterrassen-cmd/terrassenplaner/milestone/7

- [ ] **M6-01 Art der Terrasse** ([#54](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/54)) – `feature/m6-01-art-der-terrasse`
  - Normale Terrasse / Hochterrasse / vorhandene UK – mit Auswirkungen auf die folgenden Schritte.
  - Abnahme: Folgeschritte passen sich an
- [ ] **M6-02 Höhenpunkte und Gefälle** ([#55](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/55)) – `feature/m6-02-hoehenpunkte-und-gefaelle`
  - Ohne Gefälle (eine Höhe für alle) / mit Gefälle (je Eckpunkt); gemessen von Oberkante Belag bis Boden; Aufbauhöhe; Hinweis, wenn die UK zur Einhaltung der Aufbauhöhe gedreht wird.
  - Abnahme: Höhen an den Eckpunkten wie in den Planungsunterlagen
- [ ] **M6-03 UK-Auswahl und UK-Länge** ([#56](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/56)) – `feature/m6-03-uk-auswahl-und-uk-laenge`
  - Produktauswahl Unterkonstruktion mit Maßen/Material; Länge der UK (feste Längen).
  - Abnahme: Nur zum Belag passende UK
- [ ] **M6-04 Untergrund** ([#57](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/57)) – `feature/m6-04-untergrund`
  - Schotter (verdichtet, Standard), Beton, Bitumenabdichtung.
  - Abnahme: Auswirkung auf Auflagen/Zubehör wie im alten Planer
- [ ] **M6-05 Art der Terrassennutzung** ([#58](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/58)) – `feature/m6-05-art-der-terrassennutzung` · Benchmark
  - Schwimmende Verlegung, Versteifung ohne Rahmen, Rahmen (Standard), Versteifung mit Rahmen, doppelte UK; Warnung zur Verwindung ohne Bodenbefestigung.
  - Abnahme: Jede Variante ergibt die Konstruktion der Referenzfälle
- [ ] **M6-06 Querstreben** ([#59](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/59)) – `feature/m6-06-querstreben`
  - Querstreben hinzufügen, Anzahl der Quertraversen manuell ändern.
  - Abnahme: Mengen und Zeichnung passen sich an
- [ ] **M6-07 Private oder gewerbliche Nutzung** ([#60](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/60)) – `feature/m6-07-private-oder-gewerbliche-nutzung`
  - Steuert Stellfüße (privat/gewerblich) und Belastung.
  - Abnahme: Stellfußauswahl folgt dem Regelwerk
- [ ] **M6-08 Auflagen: Stelzfüße und Pads** ([#61](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/61)) – `feature/m6-08-auflagen-stelzfuesse-und-pads`
  - Mit Stelzfüßen / mit Stelzfüßen und Pads; Abstände, Min-/Max-Höhe mit Meldungen.
  - Abnahme: Höhengrenzen mit Meldung; Abstände aus dem Regelwerk
- [ ] **M6-09 Maximale Feldbreite** ([#62](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/62)) – `feature/m6-09-maximale-feldbreite`
  - Feldbreite 40/50/60 cm; Firmenregel UK-Achsabstand max. 40 cm (M1-04).
  - Abnahme: Regel aus M1-04 umgesetzt
- [ ] **M6-10 Berechnung der UK-Verlegung** ([#63](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/63)) – `feature/m6-10-berechnung-der-uk-verlegung` · Benchmark
  - Lage der UK-Hölzer, Stöße, Randabstand, Längsverbinder, Farbkennzeichnung im Plan, Stückliste.
  - Abnahme: UK-Stückliste je Referenzfall entspricht der Planungsunterlage; Benchmark: große Fläche mit Gefälle
- [ ] **M6-11 Berechnung Stelzfüße/Pads mit Höhenzuordnung** ([#64](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/64)) – `feature/m6-11-berechnung-stelzfuesse-pads-mit-hoehenzu` · Benchmark
  - Anzahl und Höhe je Stelzfuß aus Höhenpunkten, Tabelle der Höhenzuordnung.
  - Abnahme: Höhen je Stelzfuß nachvollziehbar und getestet

## M7 Anschluss, Entwässerung, Treppen

Angrenzende Seiten, Verblendung, Entwässerungsrinnen, bodentiefe Elemente, Abläufe und Treppen.

GitHub: https://github.com/premiumterrassen-cmd/terrassenplaner/milestone/8

- [ ] **M7-01 Angrenzende Seiten** ([#65](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/65)) – `feature/m7-01-angrenzende-seiten`
  - Seiten, die an Bauelemente grenzen, auswählen (grau dargestellt).
  - Abnahme: Auswirkung auf Verblendung/Rinnen
- [ ] **M7-02 Verblendung** ([#66](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/66)) – `feature/m7-02-verblendung`
  - Seiten verblenden (gelb dargestellt), bei Kreis „Fläche verblenden“; nur bei Belagstärke 19–23 mm; Warnungen (Unterlüftung, keine Verblendung ohne Höhenunterschied).
  - Abnahme: Regeln und Warnungen wie beschrieben; Verblendungsmaterial in der Materialliste
- [ ] **M7-03 Entwässerungsrinnen und bodentiefe Elemente** ([#67](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/67)) – `feature/m7-03-entwaesserungsrinnen-und-bodentiefe-elem`
  - Rinnen je Seite; bodentiefe Elemente mit Optionen (gesamte Seite innen/außen, im/außerhalb des Elements, nur vor dem Element).
  - Abnahme: Alle Optionen mit Material
- [ ] **M7-04 Abläufe / Höhenreferenzpunkte** ([#68](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/68)) – `feature/m7-04-ablaeufe-hoehenreferenzpunkte`
  - Weitere Höhenreferenzpunkte setzen (Position waagerecht/senkrecht, ab Punkt A, negative Werte möglich).
  - Abnahme: Punkte per Maus und Eingabe
- [ ] **M7-05 Treppen** ([#69](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/69)) – `feature/m7-05-treppen`
  - Treppe an einer Seite: Startpunkt, Maße L × B × H, Anzahl Stufen, individuelle Stufenmaße (Höhe, Tiefe).
  - Abnahme: Treppe in Zeichnung und Material

## M8 Zubehör

Die acht Zubehörgruppen mit automatischer Mengenermittlung und Pflichtzubehör.

GitHub: https://github.com/premiumterrassen-cmd/terrassenplaner/milestone/9

- [ ] **M8-01 Zubehör-Bereich mit acht Gruppen** ([#70](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/70)) – `feature/m8-01-zubehoer-bereich-mit-acht-gruppen`
  - Allgemein, Anlieferung, Clips & Schrauben, Höhenausgleich, Pads & EPDM-Bänder, Rhombusleisten, Terrassenfliesen, Terrassenöl RIBOL.
  - Abnahme: Gruppen aus den Artikeldaten, Reihenfolge wie im alten Planer
- [ ] **M8-02 Automatische Mengen** ([#71](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/71)) – `feature/m8-02-automatische-mengen` · Benchmark
  - Mengen für Clips/Schrauben, Pads/EPDM, Öl (nach Deckfläche) usw. aus Belag, UK und Fläche; manuelle Anpassung möglich.
  - Abnahme: Mengen entsprechen den Referenzfällen
- [ ] **M8-03 Pflichtzubehör** ([#72](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/72)) – `feature/m8-03-pflichtzubehoer`
  - Benötigtes Zubehör mit fester Anzahl je Artikel automatisch ergänzen.
  - Abnahme: Pflichtartikel nicht abwählbar
- [ ] **M8-04 Freidielen** ([#73](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/73)) – `feature/m8-04-freidielen`
  - Feste Regel im Planer: ab 25 Dielen kostenlose Freidielen als eigene Position mit Preis 0 (B-079).
  - Abnahme: Regel getestet, Position im Export

## M9 Ergebnisse

Verschnittoptimierung, Zuschnittspläne, Material- und Stückliste, Konfigurationsnummer, Speichern/Laden, Planungsunterlagen-PDF, Angebotsanfrage, GrandTotal-Export, Shop-Warenkorb.

GitHub: https://github.com/premiumterrassen-cmd/terrassenplaner/milestone/10

- [ ] **M9-01 Verschnittoptimierung** ([#74](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/74)) – `feature/m9-01-verschnittoptimierung` · Benchmark
  - Verschnittvariante auswählen, Optimierung erstellen/zurücksetzen, Ergebnis „benötigte Dielen“, Erinnerung, falls nicht optimiert.
  - Abnahme: Dielenbedarf ≤ Referenzfälle; Benchmark: Laufzeit für große Projekte
- [ ] **M9-02 Zuschnittspläne Belag und UK** ([#75](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/75)) – `feature/m9-02-zuschnittsplaene-belag-und-uk`
  - Je Artikel: Ausgangslänge, Menge, Schnittmaße.
  - Abnahme: Zuschnittspläne wie in den Planungsunterlagen
- [ ] **M9-03 Materialliste** ([#76](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/76)) – `feature/m9-03-materialliste`
  - Bild, Artikel, Menge, Einzelpreis, Positionspreis, Preis je lfm, Gesamt-lfm, Position, Preise inkl. MwSt.
  - Abnahme: Summen korrekt gerundet; Preise nur Anzeige (B-055)
- [ ] **M9-04 Stückliste** ([#77](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/77)) – `feature/m9-04-stueckliste`
  - Artikel, Länge, Menge, Farbe (Zuordnung zum Plan).
  - Abnahme: Farben stimmen mit der Zeichnung überein
- [ ] **M9-05 Konfigurationsnummer, Speichern und Laden** ([#78](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/78)) – `feature/m9-05-konfigurationsnummer-speichern-und-laden` · Benchmark
  - Nummer im Format JJJJ-MM-TT-NNNN mit Version; Speichern/Laden über WAMP; automatisches Zwischenspeichern.
  - Abnahme: Gespeicherte Konfiguration lädt identisch; Versionen bleiben erhalten
- [ ] **M9-06 Planungsunterlagen-PDF** ([#79](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/79)) – `feature/m9-06-planungsunterlagen-pdf` · Benchmark
  - Deckblatt (Briefpapier), Kundendaten, Konfigurationsnummer, Zusammenfassung, Terrasse, Eckpunkthöhen, UK mit Stückliste, Zuschnitt UK, Belag mit Dielenliste, Zuschnitt Belag, Materialliste mit Preistabelle, Stelzfußhöhen, rechtliche Hinweise, Grußtext.
  - Abnahme: Alle Kapitel wie in den Planungsunterlagen; PDF für Referenzfälle erzeugt
- [ ] **M9-07 Angebot anfordern und E-Mail** ([#80](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/80)) – `feature/m9-07-angebot-anfordern-und-e-mail`
  - Formular: Name, PLZ, Ort, Telefon, E-Mail (Pflicht), Notiz, Konfigurationsnummer, Kopie an mich, Einverständnis zur Weitergabe; Versand an anfrage@robinienwelt.de mit PDF und Export.
  - Abnahme: Pflichtfelder geprüft; Mail mit Anhängen kommt an (Testumgebung)
- [ ] **M9-08 Export für GrandTotal** ([#81](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/81)) – `feature/m9-08-export-fuer-grandtotal`
  - Projektexport mit 17 Spalten (Bezeichnung, Nomenklatur, Body HTML, Anzahl, Breite, Stärke, Länge mm, Artikelnummer, Netto, Brutto, Bild-Link, Volumen, Gewicht, m², Gesamt-lfm, Artikeltyp, Einheit), Freidielen als eigene Zeile mit Netto 0.
  - Abnahme: Export lässt sich mit dem ImportZuLaufmeter-Plugin einlesen; Artikelnummern wie im Shop (B-152)
- [ ] **M9-09 Warenkorb im Shop** ([#82](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/82)) – `feature/m9-09-warenkorb-im-shop`
  - Materialliste als Warenkorb an shop.robinienwelt.de übergeben.
  - Abnahme: Warenkorb enthält alle Shop-Artikel mit Mengen
- [ ] **M9-10 Mitarbeiter-Anmeldung** ([#83](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/83)) – `feature/m9-10-mitarbeiter-anmeldung`
  - Anmeldung für Mitarbeiter (Funktion im alten Planer vorhanden); Umfang in M1-01 klären.
  - Abnahme: Umfang dokumentiert und umgesetzt

## M10 Abnahme & Go-Live

Paritätsnachweis gegen die Referenzfälle, Produktivbetrieb, Umstellung vom alten Planer.

GitHub: https://github.com/premiumterrassen-cmd/terrassenplaner/milestone/11

- [ ] **M10-01 Paritätsnachweis** ([#84](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/84)) – `feature/m10-01-paritaetsnachweis`
  - Alle Referenzfälle (M1-02/M1-03) im neuen Planer durchrechnen und mit den alten Ergebnissen vergleichen; Abweichungen begründen oder beheben.
  - Abnahme: Paritätsbericht in docs/, keine unbegründete Abweichung
- [ ] **M10-02 Last- und Leistungstest** ([#85](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/85)) – `feature/m10-02-last-und-leistungstest` · Benchmark
  - Gleichzeitige Nutzer, große Projekte, Router-Durchsatz.
  - Abnahme: Zielwerte festgelegt und erreicht
- [ ] **M10-03 Produktivbetrieb** ([#86](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/86)) – `feature/m10-03-produktivbetrieb`
  - Produktiv-Deployment auf dem Root-Server, Domain, Let's-Encrypt-Produktivzertifikat über Traefik, Überwachung, Sicherung der Konfigurationen.
  - Abnahme: Wiederherstellung aus Sicherung getestet
- [ ] **M10-04 Umstellung vom alten Planer** ([#87](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/87)) – `feature/m10-04-umstellung-vom-alten-planer`
  - Links in Shop und Webseite umstellen, alter Planer aus (Vertrag mit Agentur beachten).
  - Abnahme: Neue Adresse live, alte leitet um
- [ ] **M10-05 Statistik und Datenschutz** ([#88](https://github.com/premiumterrassen-cmd/terrassenplaner/issues/88)) – `feature/m10-05-statistik-und-datenschutz`
  - Entscheidung zu Webanalyse und Cookie-Hinweis (alter Planer nutzt eine Analyse des Agenturanbieters).
  - Abnahme: Entscheidung Alexander umgesetzt
