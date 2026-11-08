# Mutation-Tests – Werkzeugwahl (M0-03, 02.10.2026)

## Entscheidung

`mutation_test` (pub.dev, Version 1.8.1) als Dev-Abhängigkeit der Workspace-Wurzel, Aufruf über `tool/mutation.sh`, Konfiguration je Paket in `tool/mutation/<paket>.xml`, Schwelle 95 % erkannte Mutationen.

## Verglichene Pakete (Stand 02.10.2026)

| Paket | Version | Downloads (30 Tage) | Bewertung |
|---|---|---|---|
| mutation_test | 1.8.1 (12.09.2026) | ≈ 52.000 | ausgereift, aktiv gepflegt, Regeln/Ausschlüsse/Schwelle per XML, beliebige Testbefehle (auch `flutter test`) |
| butcher | 0.1.0 | ≈ 180 | sehr neu |
| mutate4dart | 0.12.2 | ≈ 30 | analyzer-basiert, interessant, aber jung |
| radioactive_dart | 0.1.0 | ≈ 15 | sehr neu |

## Erkenntnisse

- Je Lauf wird genau **eine** XML-Datei mit Dateien, Testbefehl und Schwelle übergeben; eine zweite XML (z. B. nur mit der Schwelle) wird nicht als Eingabe verarbeitet – deshalb steht die Schwelle in jeder Paketdatei.
- Pfade in der XML gelten relativ zum Arbeitsverzeichnis (Workspace-Wurzel), Testbefehle laufen im Paketordner.
- Die eingebauten Regeln mutieren Operatoren und Bedingungen (`==`/`!=`, `<`/`<=`, `&&`/`||`, `if`-Negation …). Code ohne solche Stellen ergibt 0 Mutationen und gilt als bestanden.
- Negativprobe: Funktion `text.length > 10` mit einem Test ohne Prüfung → 1/1 Mutation unerkannt, Bewertung F, `tool/mutation.sh` endet mit Exit-Code 1.
- Laufzeit wächst mit (Mutationen × Testdauer). Wenn die Suite größer wird: Abdeckungsdaten (`-c coverage/<paket>.info`) übergeben, damit nicht abgedeckte Zeilen übersprungen werden, und in PR-Läufen nur geänderte Dateien mutieren.

## Feature-Branches mutieren nur geänderte Dateien (26.10.2026)

**Anlass:** Der Job „Mutation-Tests (≥ 95 %)“ brauchte zuletzt 95–210 Minuten je Lauf (Feature-Branch M3-04: 3 h 29 min), vor allem wegen `packages/app` – jeder Mutant startet `flutter test` neu. Das verzögerte jeden Merge um Stunden und wuchs mit jedem Feature.

**Lösung:** `tool/mutation.sh` liest `MUTATION_BASIS` (Build-Chain: `origin/main` auf allen Branches außer `main`).

- Geänderte Dateien = `git diff --name-only --diff-filter=d $(git merge-base $MUTATION_BASIS HEAD)` plus unversionierte neue Dateien (für lokale Läufe vor dem Commit).
- Je Paket wird `mutation-test-report/konfiguration/<paket>.xml` aus `tool/mutation/<paket>.xml` erzeugt: `<directories>` wird durch `<files>` mit den geänderten `lib`-Dateien ersetzt; **Testbefehl, Timeout je Mutant, Ausschlüsse und Schwelle 95 % bleiben unverändert** (die Timeouts schützen weiter vor Endlosschleifen-Mutanten, die den Runner sonst per Speicher abschießen – Exit 143).
- Ein geänderter Test (`test/x/y_test.dart`) zieht sein `lib`-Gegenstück (`lib/x/y.dart`) mit, falls es existiert – so fällt eine abgeschwächte Prüfung schon auf dem Branch auf.
- Generierter Code (`*.g.dart`) und die in der Paket-XML ausgeschlossenen Dateien werden herausgefiltert, weil `mutation_test` mit leerer Dateiliste abbricht. Bleibt nichts übrig, wird das Paket übersprungen.
- Eine geänderte Paket-XML (Regeln, Ausschlüsse, Timeouts) löst im Push keinen Vollauf aus (Stand 31.10.2026, siehe unten).
- `checkout` im Mutations-Job mit `fetch-depth: 0`, sonst fehlt der gemeinsame Vorfahr.
- `MUTATION_NUR_KONFIGURATION=1` erzeugt nur die Konfigurationen. Darauf baut der Selbsttest `tool/mutation_auswahl_test.sh` (Wegwerf-Repository, Analyse-Job) auf.

**Lokal:** `MUTATION_BASIS=origin/main tool/mutation.sh` prüft vor dem Push genau das, was die Build-Chain prüft.

**Vorsicht beim Abbrechen:** `mutation_test` mutiert die Quelldateien an Ort und Stelle. Ein abgebrochener Lauf (auch `pkill` auf `dart run`, der Snapshot-Prozess läuft weiter) hinterlässt einen Mutanten im Arbeitsbaum – vor dem nächsten Commit `git status` prüfen.

**Messwerte:**

| Lauf | Dateien | Dauer Mutations-Job |
|---|---|---|
| Feature-Branch M3-04 (vorher, alles) | alle Pakete | 3 h 29 min |
| lokal, eine geänderte domain-Datei | 1 (25 Mutanten) | 30 s |
| Build-Chain, Branch nur mit Werkzeugänderung | 0 (alle Pakete übersprungen) | 21 s |
| Build-Chain, Probe-Branch mit Inhalt von M3-05 (app) | 3 (62 Mutanten, 100 % erkannt) | 19 min 22 s |

## Endlosschleifen-Mutanten in Collection-`for` (27.10.2026)

Der Ausschluss `[\s]for[\s]*\(.*?\)[\s]*{` in `tool/mutation/*.xml` greift nur bei Schleifen mit Block. Eine Collection-`for` ohne Block (`[for (var i = 1; i < n; i += 2) …]`) wird mutiert; der Mutant `i += 2` → `i = 2` baut dann eine unendliche Liste. Lokal stürzt `dart test` schnell mit Speicherfehler ab (zählt als erkannt), auf dem GitHub-Runner wurde dagegen der ganze Job beendet (Exit 143, M4-06). Regel: In Collection-`for` nur Zählschleifen mit `i++` schreiben (`++` ist vom Mutieren ausgenommen), z. B. `for (var i = 0; i < n ~/ 2; i++) Punkt(k[2 * i], k[2 * i + 1])`.

## Vollauf nachts in Teilen, `main` nur geänderte Dateien (31.10.2026)

**Anlass:** `main` mutierte bei jedem Push alles in einem Job. Das Paket `app` wuchs auf 582 Mutanten bei 58 s je Mutant (`flutter test` wird mit jeder Datei langsamer), der Job brauchte hochgerechnet über 12 Stunden. Ab M4-14 lief er in das 6-Stunden-Limit (Run 40894211898: `cancelled`), Build, Molecule und Deployment wurden übersprungen. Letzter erfolgreicher `main`-Lauf vorher: M4-05 am 27.10. (Run 40578810003, 5 h 9 min Mutation).

**Lösung:**

- **Push auf `main`:** `MUTATION_BASIS` ist der Stand vor dem Push (`github.event.before`, bei `workflow_dispatch` `HEAD^`). Es laufen nur die Änderungen dieses Pushes, das Deployment hängt nicht mehr am Vollauf.
- **Vollauf:** Workflow `.github/workflows/mutation-vollauf.yml`, nachts um 23:00 UTC und von Hand (`gh workflow run mutation-vollauf.yml`). Seit 08.11.2026 vierzehn Jobs: `domain` in vier, `server` in zwei und `app` in acht Teilen (`MUTATION_TEIL=<nummer>/<anzahl>`, Dateien nach Größe sortiert reihum verteilt).
- **Schwelle:** Die Teile laufen ohne Schwelle, `tool/mutation_summe.sh` summiert die xunit-Berichte und prüft 95 % **je Paket** wie bisher. Sonst würde ein einzelner schwacher Teil ein Paket rot machen, das insgesamt besteht. Die Rechnung folgt `mutation_test`: Timeouts und nicht abgedeckte Zeilen zählen als unerkannt. Ein fehlender Teil zählt als Fehler.
- **Roter Vollauf:** legt ein Issue mit Label `mutation-vollauf` an (oder kommentiert das offene). **Er stoppt das Deployment nicht** – eine Lücke außerhalb der geänderten Dateien erreicht Produktion also höchstens bis zum Ende der folgenden Nacht unerkannt. Das ist der Preis dafür, dass ein Deployment nicht an einem Lauf von 1 h 42 min hängt.
- **`--fail-fast`** nun auch in `app.xml` und `domain.xml`: Ein erkannter Mutant muss die Suite nicht zu Ende laufen (lokal `flutter test` 11 s → 6 s, gleicher Exit-Code).
- **`cancel-in-progress` nur noch außerhalb von `main`:** Der Abbruch beendete zuvor jeden laufenden `main`-Lauf beim nächsten Merge und hätte auch ein Deployment mitten im Ansible-Lauf getroffen; das eigene `concurrency` des Deploy-Jobs schützt davor nicht. Jetzt läuft der aktuelle Lauf zu Ende, wartend bleibt nur der neueste. Dessen `github.event.before` überspringt die verdrängten Pushes; die fängt der Branch-Lauf vor dem Merge und nachts der Vollauf ab.
- **Geänderte Paket-XML:** löst keinen Vollauf im Push mehr aus, weil `app` darin nicht in einen Job passt. Nach einer Änderung an Regeln oder Ausschlüssen den Vollauf von Hand starten.

**Wenn ein Teil zu lang wird:** Die Grenze liegt bei 345 Minuten (`timeout-minutes`). Dann in der Matrix die Zahl `von` erhöhen und Teile ergänzen; das geht auch für `domain` und `server`.

**Messwerte Vollauf** (Run 41212363895, Stand M5-02):

| Paket | Mutanten | unerkannt | Score | Dauer |
|---|---|---|---|---|
| domain | 1121 | 9 | 99,20 % | 1 h 05 min |
| server | 513 | 4 | 99,22 % | 1 h 42 min |
| app (8 Teile) | 600 | 8 | 98,67 % | je 18–60 min, zusammen 4 h 54 min |

Gesamtdauer 1 h 42 min statt über 12 Stunden.

## Harte Frist je Mutant: `tool/mutation/frist.sh` (04.11.2026)

Auf `feature/m6-01-art-der-terrasse` brach der Mutationsjob zweimal mit Exit 143 ab („The runner has received a shutdown signal“), jeweils in `dielenverlegung.dart`. Ursache: Einige Mutanten rechnen (fast) endlos – lokal nachgestellt Zeile 162 `anfang - laenge.mm` und Zeile 212 `p - (q - p) * …` (Sutherland-Hodgman). mutation_test beendet einen Testlauf nach dem Timeout nur mit **SIGTERM**; `dart test` wartet darauf erst die laufenden Tests ab und lief lokal noch Minuten neben den folgenden Mutanten weiter. Mehrere solcher Prozesse gleichzeitig sprengen den Speicher des Runners.

Seitdem läuft jeder Testbefehl über `bash ../../tool/mutation/frist.sh <sekunden> …`: Der Befehl wird nach der Frist (10 s vor dem Timeout aus der Paketkonfiguration: 290 s domain/app, 110 s server) mit **SIGKILL** beendet, ebenso sofort, wenn mutation_test selbst SIGTERM schickt. Ein so beendeter Lauf hat einen Exit-Code ungleich 0 und zählt als erkannt – wie ein Timeout. Timeouts und Schwellen bleiben unverändert.

Die Frist allein reichte nicht: Der nächste Lauf brach wieder in `dielenverlegung.dart` ab. Einzelne Mutanten (etwa falsche Schnittpunkte im Sutherland-Hodgman, Zeile 212) erzeugen Punkte weit außerhalb der Fläche; nachgelagerte Listen (z. B. die UK-Linien der Befestigungspunkte) werden dann so groß, dass der Prozess binnen Sekunden den Speicher des Runners belegt – lokal fängt das der Auslagerungsspeicher ab, der Runner wird beendet. Darum laufen domain und server zusätzlich mit begrenztem Heap: `dart --old_gen_heap_size=1024 test --fail-fast` (die ganze Suite braucht unter 512 MB). Ein Mutant mit Speicherexplosion endet so mit „Out of Memory“ und zählt als erkannt. `DART_VM_OPTIONS` wirkt auf die Test-Isolate von `dart test` nicht, nur die Option direkt nach `dart`.

## Build-Chain mutiert in parallelen Teilen; Ladebild-Prüfung mit Frist (05.11.2026)

**Anlass:** Große Feature-Stapel änderten so viele Dateien, dass der eine Mutationsjob das 6-Stunden-Limit erreichte: M6-04–11 (Run 42054431252) und M9-01/02 wurden `cancelled`, obwohl alle übrigen Prüfungen grün waren. M8-01–04 brauchte 4 h 20 min (app allein 2 h 34 min).

**Lösung:** Der Job `mutation-teil` läuft als Matrix (domain 4, server 2, app 6 Teile). `tool/mutation.sh` erlaubt dafür `MUTATION_TEIL` zusammen mit `MUTATION_BASIS`: Die geänderten Dateien werden wie im Vollauf nach Größe reihum verteilt, jeder Teil läuft ohne Schwelle. Ein Teil ohne Dateien legt einen leeren Bericht ab. Der Job `mutation-tests` (Name unverändert, Abhängigkeit von Build und Deployment bleibt) summiert mit `tool/mutation_summe.sh` und prüft die 95 % je Paket; fehlt ein Teil, ist er rot. Geprüft in `tool/mutation_auswahl_test.sh`.

**Ladebild-Prüfung:** Im selben Lauf hing `tool/ladebild/pruefung.mjs` nach dem Start der WebAssembly-Umgebung 32 Minuten ohne Ausgabe, bis der Smoke-Job nach 40 Minuten abbrach (alle Flutter-Smoke-Tests waren grün). Jeder Fall, der Chrome-Start und die DevTools-Verbindung haben jetzt eine Frist von 120 s; nach einer Zeitüberschreitung startet ein frisches Chrome und der Fall wird einmal wiederholt („WIEDER“). Hängt er erneut, ist er rot statt endlos.

## Vollauf: domain und server ebenfalls in Teilen (08.11.2026)

**Anlass:** Der nächtliche Vollauf war ab 06.11.2026 rot (Issue #132): `domain` lief als ein Job und wurde nach 5 h 45 min am Limit abgebrochen (Run 42436256055), `server` brauchte 5 h 22 min. Die gemessenen Werte selbst waren gut (server 99,22 %, app 96,88 %).

**Lösung:** In `.github/workflows/mutation-vollauf.yml` läuft `domain` in vier und `server` in zwei Teilen, wie in der Build-Chain. Die Auswertung (`tool/mutation_summe.sh`) prüft die 95 % weiter je Paket über alle Teile.

## Frist beendet die ganze Prozessgruppe (08.11.2026, #135)

**Anlass:** Lokal liefen 108 verwaiste Dart-Prozesse (85 × `bin/auth_server.dart`, 23 Test-Runner) mit je rund 5 % CPU, Last ~16; Tests liefen dadurch in Zeitüberschreitungen. Sie stammten aus Mutationsläufen: `frist.sh` beendete nach Ablauf nur `dart test`, nicht dessen Test-Runner und die von Tests gestarteten Server.

**Lösung:** `frist.sh` startet den Befehl mit `set -m` in einer eigenen Prozessgruppe und beendet bei Ablauf, bei SIGTERM von `mutation_test` und nach dem Ende des Befehls die ganze Gruppe. Geprüft in `tool/mutation_auswahl_test.sh`.

