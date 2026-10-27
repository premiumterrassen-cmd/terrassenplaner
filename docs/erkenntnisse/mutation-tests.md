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
- Ändert sich die Paket-XML selbst (Regeln, Ausschlüsse, Timeouts), läuft dieses Paket vollständig.
- `main` (Push nach dem Merge) mutiert wie bisher **alles**; dort fällt auf, was die Auswahl nicht sieht (z. B. ein geänderter Test ohne gleichnamige `lib`-Datei, der andere Dateien schwächer prüft).
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
