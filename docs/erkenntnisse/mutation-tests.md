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
