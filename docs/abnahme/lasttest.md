# Last- und Leistungstest (M10-02, #85)

Stand 08.11.2026, Branch `feature/m10-02-last-und-leistungstest`. Getestet wird der echte Router (`bin/server.dart`, wie in der Build-Chain mit `dart build cli` gebaut) samt ObjectBox auf der Platte – nur lokal, nie gegen `alto.terrassenplaner.eu`.

## Kurzfassung

- **Leistung des eigenen Codes reicht für den Zielserver:** Eine typische Berechnung kostet im Router rund 3 ms, Speichern/Laden wenige ms; 50 gleichzeitig arbeitende Nutzer belegen etwa einen halben Kern des Messrechners (umgerechnet ≈ 1 Kern des Zielservers), der Speicher bleibt unter 120 MiB. Durchsatz kleiner Aufrufe über den Router: rund 5 500/s mit 100 Sitzungen.
- **Engpass im eigenen Code behoben:** Der Planungsdienst rechnete im Router-Isolate. Ein großes Projekt (≈ 2 s) hielt dort alle anderen Dienste an; extreme, aber gültige Eingaben (z. B. fünf Flächen 30 × 30 m, 99-mal gebaut, mit Verschnittoptimierung) rechneten **minutenlang** und legten den ganzen Server lahm (ein einziger Aufruf genügt). Neu rechnet das **Rechenwerk** (`lib/src/dienste/rechenwerk.dart`) jede Planung in einem eigenen Isolate, höchstens so viele gleichzeitig wie Kerne, und bricht nach **20 s** mit dem neuen Fehler `…kunde.fehler.planung_zu_aufwendig` ab.
- **Zwei connectanum-Befunde verhindern die volle Abnahme** (an Alexander gemeldet, nicht umgangen):
  1. **Stau im Router:** Unter Last bleiben zeitweise *alle* Aufrufe hängen (Antwort nie oder erst nach 10–500 s), während Router und Lastwerkzeug **keine CPU** verbrauchen. Reproduzierbar mit 50 bis 500 Sitzungen, mit JSON und FlatBuffers, mit Router und Client im selben oder in getrennten Prozessen, auch auf `origin/main` ohne die Änderungen dieses Branches.
  2. **Aufrufe an eine interne Dienst-Sitzung laufen nacheinander:** Die nächste INVOCATION erreicht den Handler erst, wenn die vorige beantwortet ist – obwohl der Handler asynchron ist. Damit warten typische Berechnungen hinter einem großen Projekt, und das Rechenwerk kann (noch) nicht parallel rechnen.
- **Abnahme:** Zielwerte festgelegt; die Leistungs-Zielwerte werden in Läufen ohne Stau erreicht, die Zielwerte „0 Fehler“ und „Nebenher-Latenz bei großen Projekten“ erst nach Behebung der beiden connectanum-Befunde. M10-02 bleibt deshalb offen.

## Messumgebung

| | Messrechner | Zielserver |
|---|---|---|
| CPU | Apple M5, 10 Kerne | 2 Kerne (vServer) |
| RAM | 32 GB | 3,8 GB |
| System | macOS 26 (Darwin 25.6) | Debian 13 |
| Dart | 3.13.5, AOT (`dart build cli`) | dasselbe Bündel aus der Build-Chain |
| connectanum | 3.0.0-beta.8 | 3.0.0-beta.8 |

- Der Messrechner war während der Messungen durch andere Arbeiten stark belastet (Load Average 11–23 bei 10 Kernen). Absolute Zeiten streuen deshalb zwischen Läufen um bis zum Faktor 3; Vergleiche (vorher/nachher) wurden abwechselnd auf derselben Maschine gefahren.
- **Umrechnung auf den Zielserver:** Ein Kern des Zielservers gilt als halb so schnell wie einer des Messrechners (Faktor 2, `Zielwerte.faktor`): Zeiten und CPU-Bedarf werden verdoppelt, der Durchsatz halbiert, der Speicher bleibt. Ein Kern-Limit lässt sich auf macOS ohne Container nicht setzen; maßgeblich ist deshalb der gemessene CPU-Bedarf des Router-Prozesses (CPU-Zeit ÷ Laufzeit, per `ps`).
- Artikeldaten: kleine erfundene Artikeldatei (`Lastdaten.artikeldatei`: Diele 60 × 21 mm, UK 45 × 60 mm, Pads, Stellfüße), damit Verlegung, UK, Auflager und Materialliste vollständig gerechnet werden. Keine echten Daten.

## Werkzeuge

| Was | Wo | Wann |
|---|---|---|
| Langer Lauf (alle Szenarien je 60 s, ≈ 6 min) | `tool/lasttest.sh` → `benchmark-results/lasttest-lokal.json` | manuell, vor Releases und nach connectanum-Updates |
| Kurzer Lauf für die Build-Chain | `packages/server/benchmark/lasttest_benchmark.dart` (`server.Lasttest.gleichzeitig20`, `server.Lasttest.grossesProjekt`) | jeder Push über `tool/benchmark.sh` |
| Lastwerkzeug | `packages/server/bin/lasttest.dart`, Bibliothek `packages/server/lib/src/lasttest/` | von beiden genutzt |

`tool/lasttest.sh` baut Router und Lastwerkzeug, startet den Router auf freien Ports mit eigener Datenbank, fährt die Szenarien, misst Speicher (RSS, Spitze alle 250 ms) und CPU-Zeit des Router-Prozesses sowie die CPU des Lastwerkzeugs selbst (begrenzt das Werkzeug, statt der Router?) und prüft die Zielwerte (Exit 1 bei Verfehlung). Optionen: `--dauer <s>`, `--faktor <x>` (skaliert die Sitzungen, z. B. `--faktor 5` für die Belastungsgrenze), `--szenario <name>` (mehrfach). Sitzungen beginnen zufällig versetzt und streuen ihre Denkzeit (fester Zufall je Sitzung → wiederholbar), sonst rechnen alle im Gleichschritt.

## Szenarien

| Szenario | Last |
|---|---|
| `nutzer` | 50 Sitzungen, Bedienrunde (3 × Berechnen, Entwurf zwischenspeichern, SPEICHERN, LADEN), im Mittel 1 s Denkzeit |
| `sitzungen` | 100 Sitzungen, Bedienrunde alle 5 s |
| `gross` | 2 Sitzungen berechnen ohne Pause das große Projekt (10 Freiformen 12 × 8 m, je 10-mal gebaut, Verschnittoptimierung – ≈ 8 600 m²), 20 Nutzer arbeiten nebenher |
| `durchsatz` | 100 Sitzungen rufen ohne Pause die Hallo-Prozedur auf (Router-Rundlauf) |

## Zielwerte (Zielserver) und Begründung

Speicherbudget des Zielservers (3,8 GB): Prometheus ≤ 512 MB und Grafana ≤ 768 MB (systemd-Grenzen, M0-17), Traefik, Auth-Server, System und Journal zusammen ≈ 0,7 GB → für den Router **1 GiB** mit Reserve. CPU: Der Router soll bei der erwarteten Spitze höchstens **einen der zwei Kerne** belegen; der zweite bleibt für Traefik (TLS), Monitoring und Auth-Server.

Zur Nutzerzahl gibt es keine Messung des alten Planers; für einen Fachhandels-Planer ist eine Spitze von 20 gleichzeitig planenden Nutzern hoch angesetzt. Ziel ist das 2,5-Fache (50 aktiv) bzw. 100 verbundene Sitzungen.

| Kennung | Zielwert | Begründung |
|---|---|---|
| `*.fehler` | 0 gescheiterte Aufrufe | Jeder Fehler ist für den Nutzer ein Abbruch |
| `*.speicher` | ≤ 1024 MiB RSS | Budget oben |
| `nutzer.berechnen` | p95 ≤ 250 ms | Planen ist interaktiv: jede Änderung zeichnet neu; bis ≈ 250 ms wirkt das sofort |
| `nutzer.speichern`, `nutzer.laden` | p95 ≤ 250 ms | dito |
| `nutzer.cpu` | ≤ 1 Kern | Budget oben |
| `sitzungen.berechnen`, `sitzungen.speichern` | p95 ≤ 500 ms | doppelte Sitzungszahl darf spürbar, aber nicht störend langsamer sein |
| `gross.berechnenGross` | p95 ≤ 5 s | großes Projekt: Wartezeit mit Ladeanzeige vertretbar |
| `gross.nebenher.berechnen`, `gross.nebenher.speichern` | p95 ≤ 500 ms | ein großes Projekt darf andere Nutzer nicht anhalten |
| `durchsatz.aufrufe` | ≥ 2000 Aufrufe/s | die Bedienrunde von 100 Sitzungen braucht ≈ 120 Aufrufe/s; Reserve > 10× für Artikel-, 3D- und PDF-Aufrufe |
| `durchsatz.hallo` | p95 ≤ 100 ms | Router-Rundlauf unter Volllast |
| Rechenzeit je Berechnung | ≤ 20 s, dann Abbruch | Schutz vor extremen Eingaben (`Rechenwerk.standardHoechstdauer`) |

## Messwerte

### Rechenzeit einer Berechnung (ohne Router, ein Kern)

| Planung | Zeit |
|---|---|
| Startfläche | 1,0 ms |
| typische Planung (3 Flächen) | 2,8 ms |
| Freiform 12 × 8 m | 2,6 ms |
| Rechteck 30 × 30 m | 11 ms |
| großes Projekt (10 × Freiform, je 10-mal, Verschnittoptimierung) | 0,6 s (JIT, ruhige Maschine) bis 2,0 s (AOT, unter Last) |
| 5 × 30 × 30 m, je 99-mal, Verschnittoptimierung | nach 6,5 min CPU noch nicht fertig (abgebrochen) |

Nur die Verschnittoptimierung (M9-01) über sehr viele gleiche Stücke ist teuer; ohne sie bleibt selbst die größte zulässige Fläche bei Millisekunden. Das Rechenwerk begrenzt den Extremfall auf 20 s.

### Langer Lauf mit dem Endstand (08.11.2026, `tool/lasttest.sh`, 60 s je Szenario, Last ≈ 11–17)

Rohdaten: `benchmarks/lasttest-lokal.json`. Werte lokal, in Klammern umgerechnet auf den Zielserver.

| Kennung | gemessen | Zielserver | Ziel | |
|---|---|---|---|---|
| nutzer.fehler | 0 von 14 142 | 0 | 0 | erreicht |
| nutzer.berechnen p95 | 96,1 ms | 192 ms | ≤ 250 | erreicht |
| nutzer.speichern p95 | 109,2 ms | 218 ms | ≤ 250 | erreicht |
| nutzer.laden p95 | 90,1 ms | 180 ms | ≤ 250 | erreicht |
| nutzer.cpu | 0,48 Kerne | 0,96 | ≤ 1 | erreicht |
| nutzer.speicher | 82,6 MiB | 82,6 | ≤ 1024 | erreicht |
| sitzungen.fehler | 0 von 4 584 | 0 | 0 | erreicht |
| sitzungen.berechnen p95 | 316,9 ms | 634 ms | ≤ 500 | verfehlt (Stau-Spitzen bis 22,6 s) |
| sitzungen.speichern p95 | 477,0 ms | 954 ms | ≤ 500 | verfehlt (dito) |
| gross.fehler | 22 | 22 | 0 | verfehlt (Stau, Aufrufe nach 60 s abgebrochen) |
| gross.berechnenGross p95 | 2 238 ms | 4 476 ms | ≤ 5000 | erreicht |
| gross.nebenher.berechnen p95 | 2 240 ms | 4 479 ms | ≤ 500 | verfehlt (Befund 2) |
| gross.nebenher.speichern p95 | 1 899 ms | 3 798 ms | ≤ 500 | verfehlt (Befund 1/2) |
| durchsatz.aufrufe | 4 761/s | 2 380/s | ≥ 2000 | erreicht |
| durchsatz.hallo p95 | 18,6 ms | 37 ms | ≤ 100 | erreicht |
| Speicher (alle Szenarien) | ≤ 96,9 MiB | | ≤ 1024 | erreicht |

Auch die „erreichten“ Szenarien zeigen einzelne Stau-Spitzen (Höchstwerte 5,3 s in `nutzer`, 15,9 s in `durchsatz`), die p95 aber nicht verschieben. Der Median bleibt überall bei 4–19 ms (außer `gross`).

### Weitere Lastläufe ohne Stau

Lauf vom 07.11. (`origin/main`-Stand, 20 s je Szenario, Last ≈ 11):

| Szenario | Vorgang | p50 | p95 | Ziel | |
|---|---|---|---|---|---|
| nutzer (50) | berechnen | 9,9 ms | 34,1 ms (68) | ≤ 250 | erreicht |
| | speichern | 13,0 ms | 38,0 ms (76) | ≤ 250 | erreicht |
| | laden | 8,7 ms | 33,0 ms (66) | ≤ 250 | erreicht |
| | CPU Router | | 0,48 Kerne (0,96) | ≤ 1 | erreicht |
| | Speicher | | 77 MiB | ≤ 1024 | erreicht |
| durchsatz (100) | Aufrufe/s | | 5 527 (2 763) | ≥ 2000 | erreicht |
| | hallo | 14,9 ms | 20,1 ms (40) | ≤ 100 | erreicht |
| sitzungen (100) | berechnen | 15,6 ms | 194 ms (388) | ≤ 500 | erreicht (erster langer Lauf 08.11.) |
| | speichern | 15,8 ms | 223 ms (446) | ≤ 500 | erreicht (erster langer Lauf 08.11.) |

Speicherspitze in allen Läufen ≤ 120 MiB (Leerlauf 32 MiB). CPU des Routers im Leerlauf ≈ 0.

### Großes Projekt: vorher/nachher (A/B, abwechselnd, je 30 s, Last ≈ 15)

| | gross p95 | nebenher berechnen p50 | nebenher entwurf p50 | nebenher laden p50 |
|---|---|---|---|---|
| vorher (`origin/main`) | 5,1 s | 3,6 s | 290 ms | 91 ms |
| nachher (Rechenwerk) | 5,0 s | 3,9 s | 129 ms | 75 ms |

Die anderen Dienste (Konfigurationen, Artikel) werden nicht mehr blockiert; typische Berechnungen warten aber weiter hinter dem großen Projekt, weil connectanum die Aufrufe an den Planungsdienst nacheinander zustellt (Befund 2, Nachweis unten). Im Rechenwerk selbst laufen Berechnungen nachweislich parallel: vier große Projekte gleichzeitig 3,3 s statt 4 × 2,0 s, eine typische Berechnung neben einem laufenden großen Projekt 5–10 ms, die größte Pause im Router-Isolate dabei 13 ms.

### Stau-Läufe (connectanum-Befund 1)

| Lauf | Sitzungen | Ergebnis |
|---|---|---|
| Router-Prozess, 1 Lastprozess | 500 (sitzungen) | 1 044 Aufrufe nach 60 s abgebrochen, Router-CPU 0,01 Kerne |
| Router-Prozess, 5 Lastprozesse à 100 | 500 | alle fünf Prozesse gleichzeitig ≈ 33 s ohne Antwort, Router-CPU 0,01 |
| Router-Prozess, Hallo | 150 / 200 / 300 / 500 | ok / alle 200 hängen / ok (max 7,8 s) / 499 hängen |
| Router und Client in einem Prozess, Hallo, FlatBuffers | 200 / 400 | einmal ok, einmal alle hängen / einmal 2,2 s max, einmal alle 400 hängen |
| dito JSON | 200 / 400 | max 26,9 s / max 9,9 s; zweiter Lauf: 399 hängen |
| A/B `nutzer`, 50 Sitzungen, je 3 Läufe | 50 | Stau in 2 von 3 Läufen auf `origin/main`, in 1 von 3 mit Rechenwerk |
| langer Lauf (alle Szenarien) | 50–100 | Stau in `nutzer`, `gross` und `durchsatz` |

Merkmale: Der Router verbraucht während des Staus keine CPU, Aufrufe bleiben unbeantwortet (kein Fehler), manche Läufe erholen sich nach 10–30 s, andere nicht innerhalb des Zeitlimits von 60 s. Häufigkeit nimmt mit der Zahl der Sitzungen zu, ist aber nicht an eine feste Schwelle gebunden.

### Aufrufe an eine Dienst-Sitzung nacheinander (connectanum-Befund 2)

Protokoll im Planungsdienst (Start/Ende je Aufruf, Millisekunden), zwei große Projekte aus zwei Sitzungen gleichzeitig, danach typische Berechnungen im 100-ms-Takt:

```text
start 65212 → fertig 66198   (großes Projekt 1)
start 66202 → fertig 67066   (großes Projekt 2 – kommt erst nach dem Ende von 1 an)
start 67068 → fertig 67072   (typische Berechnung, gestellt bei ≈ 65300)
```

Der Handler (`onLazyInvokePayload`, gibt einen Future zurück) wird von `connectanum_core` nicht abgewartet; die Serialisierung entsteht vor der Zustellung an die interne Sitzung.

## Behobener Engpass im eigenen Code

- `Rechenwerk`: frisches Isolate derselben Gruppe je Berechnung (Start < 1 ms), Warteschlange bei mehr als `parallel` (Standard: Kerne), Abbruch per `Isolate.kill` nach `hoechstdauer` (20 s) → `RechenzeitUeberschritten` → WAMP-Fehler `WampNamen.planungZuAufwendig`. Fehler im Isolate kommen mit ihrem Text zurück (`Rechenfehler`), damit die Fehlermeldungen an die App gleich bleiben.
- `PlanungsDienst`: Belag und UK werden im Router-Isolate nachgeschlagen (die Suchfunktionen hängen an Dienst-Sitzungen und sind nicht versendbar), `rechenauftrag` schließt nur versendbare Werte ein.
- Offen (eigener Code, kein Lastproblem im Normalbetrieb): Planungsunterlagen (PDF, M9-06) und Export (M9-08) rechnen weiter im Router-Isolate; bei extremen gespeicherten Planungen gilt dort dieselbe Gefahr. Sinnvoll als Folge-Issue, sobald Befund 2 geklärt ist.

## Folgerungen für M11 (Verteilung)

Auslöser für eine Verteilung liegen weit über der erwarteten Last: CPU ≈ 1 Kern bei 50 aktiven Nutzern (Zielserver), Speicher < 0,2 GB. Vor einer Verteilung sind die beiden connectanum-Befunde zu beheben; danach diesen Test mit `--faktor 2`/`--faktor 5` wiederholen und die Grenze neu bestimmen.
