# Paritätsbericht (M10-01)

> **Nachtrag 11.11.2026 (Planungskern v6, Branch `feature/planungskern-belag-befestigung`):** Fuge 6 statt 5 mm und neue Befestigung (Anfangs- und Enddiele verschraubt, Clips + 5 %) – Abschnitt [Planungskern v6](#nachtrag-planungskern-v6-11112026) unten. Die Tabellen darunter zeigen den Stand vom 07.11.2026.

Stand 07.11.2026, Branch `feature/m10-01-paritaetsnachweis`. Alle Referenzkonfigurationen F01–F43 (M1-03, [12](../fachkonzept/12-referenzkonfigurationen.md)) und alle rechenbaren Referenzfälle aus den Planungsunterlagen (M1-02, [11](../fachkonzept/11-referenzfaelle.md)) werden im neuen Planer gerechnet und mit den Ergebnissen des alten Planers verglichen.

**Ergebnis:** 43 Konfigurationen und 26 Referenzfälle gerechnet. 15 Konfigurationen und 6 Referenzfälle stimmen in allen verglichenen Größen. Alle übrigen Abweichungen sind begründet. Eine Abweichung wurde im Code behoben (UK-Reste, siehe unten). Drei Punkte sind als **offene Fragen an Alexander** markiert. Sie sind im Test als Begründung „Frage 1–3“ hinterlegt, damit sie nicht untergehen. Entschieden sind sie damit nicht.

## Verfahren

- **Test:** `packages/server/test/paritaet_test.dart` mit den Hilfen in `paritaet_daten.dart`. Jeder Fall wird aus seinen Eingaben in einen `Planungsstand` übersetzt und über `PlanungsDienst.berechnePlanung` gerechnet, also auf demselben Weg wie in der App. Der Test kennt je Fall die erwarteten Abweichungen mit ihrem Grund. Er schlägt fehl, wenn eine neue Abweichung auftaucht, wenn eine begründete verschwindet und wenn ein Grund nicht erklärt ist.
- **Artikel:** Die echte Artikeldatei gehört nicht ins Repository (B-023, [Artikelimport](../betrieb/artikelimport.md)). Der Test nutzt deshalb ein neutrales Testsortiment in den Formaten der Fälle: Robinie mit Lieferlängen 4/5/6 m, „22 mm“ wird zu 21 mm (B-032), CLIP-FIXX VPE 50/100/250 und Alu-UK in der Länge aus dem Titel. Verglichen werden darum **Mengen und Längen, keine Artikelnummern**. Das Altsortiment ist kein Sollwert ([09](../fachkonzept/09-nicht-teil-der-kopie.md#veraltetes-sortiment-im-alten-planer)).
- **Verglichene Größen (Konfigurationen):**
  - Fläche (3 Stellen) und Verschnitt (wo angezeigt).
  - Dielen je Lieferlänge. Einseitig genutete Anfangsdielen zählen als normale Dielen (B-033).
  - Freidielen, Verblendungsdielen, UK-Hölzer je Lieferlänge und Clips in Stück.
  - Volumen: Es folgt aus Dielen und UK (M6-10). Bei gleichem Material zählt es erst ab 5 % Abweichung, denn 21 statt 22 mm (B-032) sind 4,5 % der Dielen. Weicht das Material ab, steckt die Abweichung schon dort.
  - Nicht verglichen: Zubehör des Altsortiments (KOPPLEX, Terrassenschrauben der Randdielen, Stelzlager), Auflager und Bodenanker. Sie hängen an Artikeln der Upload-Datei; die Mengenlogik ist in M6-11/M8 gegen F01, F28, F29 und F35 getestet.
- **Verglichene Größen (Referenzfälle):** Fläche sowie die Lieferung von Deckbelag und UK laut Zuschnittplänen der Unterlage. Verglichen wird nur, wo die Unterlage die Liste enthält.
- **Verschnittvariante:** Variante 1 des alten Planers entspricht der üblichen Verlegung (neu: nicht optimiert). F43 wählt Variante 2.

## Behebung im Code (M10-01)

**Kurze UK-Stücke aus den Resten der langen.** Der alte Planer schneidet Stützen, Querstreben und Blendenhalter aus den Resten der UK-Hölzer. Bei F28 kommen 309 + 39,9 + 39,9 cm aus einem 400-cm-Holz. Der neue Planer gab bisher jeder Quelle eigene Hölzer: Verlegung, zusätzliches Holz, Stützen und Anschluss. Dadurch lieferte er bei F28 137 m statt 112 m UK. Diese Abweichung war unbegründet, und die Fachregel ist eindeutig: so wenig Verschnitt wie möglich (R-B11), bei Blendenhaltern und Treppen-UK schon so umgesetzt.

- `lieferhoelzer` (domain) schneidet kurze Stücke zuerst in die Reste der langen.
- Der Planungsdienst rechnet alle UK-Stücke einer Fläche in einem gemeinsamen Zuschnitt (`_ukHoelzer`). Kein Rest wird doppelt verplant, und der Zuschnittplan enthält jedes Lieferholz.
- **Wirkung:**

| Fall | vorher | jetzt | alter Planer |
|---|---|---|---|
| F28 | 137 m | 125 m | 112 m (Rest siehe „Stützen“) |
| F31 | 13 × 4000 + 6000 + 4000 mm | 13 × 4000 mm | 15 × 4000 mm |
| F33 | Rahmen + Streben 2 × 5000 + 6000 + 4000 mm | nur Rahmen 2 × 5000 mm | 3 × 5000 + 3000 mm |
| F37, F39 | unverändert | unverändert | gleich |

- Fachkonzept 03, 04, 05 und 08 sind angepasst.

## Begründungen

| Kürzel | Begründung |
|---|---|
| B-035 | Nur Lieferlängen 4/5/6 m. Zwischen- und Überlängen des alten Planers (3,0/4,5/5,5/6,5/7,0 m) gibt es nicht (R-A06). Bei Stücken in 90er/180er-Teilung (L-, T-, U-Form) sind dann rund 10 % Verschnitt das Minimum. |
| ~~B-033~~ | *Bis 11.11.2026:* keine einseitig genuteten Randdielen, die Randreihen bekamen Clips statt Terrassenschrauben. Entfällt mit dem Planungskern v6 – siehe Nachtrag. |
| Fuge | *Seit 11.11.2026:* Fuge 6 statt 5 mm (R-B06), Reihen = Breite + 6 mm, z. B. 47 statt 48 Reihen auf 309 cm – Planungskern v6 / Entscheidung Alexander 11.11.2026. |
| Befestigung | *Seit 11.11.2026:* Anfangs- und Enddiele sichtbar verschraubt, Clips = übrige Kreuzungen + 5 % (Fachkonzept 2.6) – Planungskern v6 / Entscheidung Alexander 11.11.2026. |
| R-B09 | Freidielen nach der Staffel ab 25 Dielen (B-079, B-228; Fachkonzept 06). |
| M4-07 | Kreisfläche exakt π·r² statt als Vieleck. |
| Fehler | Fehler des alten Planers, in den Testdaten als `fehlerverdacht` markiert (F14 7000-mm-Dielen und 6500-mm-UK, F40 Fundament = Konstruktion; ebenso 7000/6500 mm in 2026-04-13-1946 und 2026-04-29-164). |
| UK-Lage | Lage der UK-Linien, im Fachkonzept 08 begründet: F10 24 statt 25 Hölzer, F20 zwei Stücke à 353 cm ohne Holz der Verlegung, 2026-07-07-2794 alt enger als 40 cm (M6-10). |
| Treppe | Nachvollziehbare Treppenkonstruktion statt der nicht ableitbaren alten (Fachkonzept 05). Die offene Frage zur Treppenkonstruktion aus M7-05 bleibt bestehen. |
| Varianten | Variante 2 des alten Planers ist 5,5 m. Die gibt es nicht, neu ist Variante 2 = 6 m (Fachkonzept 07). |
| Reste | Kurze UK-Stücke aus den Resten (Behebung oben). Neu ist weniger UK-Holz nötig als alt. |
| Stützen | Eine Stütze je Auflager (M6-11): 91, wie die 91 Bodenanker des alten Planers. Dessen Export schneidet nur 63 Stützen. Dazu sind die Stützen 40,1 statt 39,9 cm (21-mm-Diele), deshalb passen nur 9 statt 10 in 4 m. |
| Rechenweg | Verschnitt mit Teilflächen: der alte Rechenweg ist aus den Daten nicht nachvollziehbar (F21, Fachkonzept 2.7). |
| Eingaben | Die Unterlage ist unvollständig: Nutzungsart (grüne Querstücke), Terrassenart (Stützen 39,9 cm) oder die verblendeten Seiten (Blendenhalter 8,6 cm) sind nicht erfasst. Die UK-Hölzer der Verlegung selbst stimmen (M6-10: 2810, 1275, 1823, 347, 4381). |
| Frage 1–3 | offen, siehe unten |

## Referenzkonfigurationen F01–F43

Werte alt → neu. „gleich“ heißt: alle verglichenen Größen stimmen.

| Fall | Abweichung von F01 | Fläche m² | Verschnitt % | Volumen m³ | Ergebnis |
|---|---|---|---|---|---|
| F01 | Startkonfiguration | 14,832 | 4 | 0,435 → 0,433 | gleich: 48 × 5000 + 1 Freidiele, UK 13 × 4000, 637 Clips |
| F02 | senkrecht | 14,832 | 22,75 | 0,499 → 0,491 | gleich (74 × 4000, UK 9 × 5000) |
| F03 | diagonal 45° | 14,832 | 2,2 → 5,75 | 0,457 → 0,426 | Dielen B-035 (alt 4,5/5,5 m); UK 12 Stück (davon 5 in 4,5/5,5 m) → 4 × 5000 + 6 × 4000 und Clips 750 → 600: **Frage 1** |
| F04 | diagonal 135° | 14,832 | 0,32 → 0,96 | 0,462 → 0,428 | Dielen B-035; Freidielen 1 → 2 (R-B09); UK 13 → 11 Hölzer, Clips 850 → 750: **Frage 1** |
| F05 | 30° | 14,832 | 3,76 | 0,473 → 0,424 | Dielen B-035; UK 14 → 11 Hölzer, Clips 750 → 650: **Frage 1** |
| F06 | Halbverband | 14,832 | 4 | 0,445 → 0,443 | gleich |
| F07 | Drittelverband | 14,832 | 4 | 0,454 → 0,453 | gleich |
| F08 | Wechselverband | 14,832 | 4 | 0,435 → 0,433 | gleich |
| F09 | 800 × 309 | 24,72 | – → 0 | 0,713 → 0,710 | Clips 1050 → 1100 (B-033), sonst gleich |
| F10 | 800, Halbverband | 24,72 | – → 0 | 0,742 → 0,729 | UK 25 → 24 × 4000 (UK-Lage) |
| F11 | 800, Drittelverband | 24,72 | – → 0 | 0,732 → 0,729 | Clips 1150 → 1200 (B-033) |
| F12 | 800, Wechselverband | 24,72 | – → 0 | 0,722 → 0,720 | Clips 1100 → 1150 (B-033) |
| F13 | fest 400 cm | 24,72 | – → 0 | 0,673 → 0,705 | Freidielen 3 → 2 (R-B09); UK 11 × 6500 → 22 × 4000 (B-035); Clips (B-033) |
| F14 | 3 cm versetzt | 24,72 | 0,14 → 0 | 0,677 → 0,710 | **Fehler** (fehlerverdacht): 7000 mm → 48 × 6000 + 24 × 4000, UK 6500 → 4000 |
| F15 | L-Form | 10,26 | 7,31 → 11 | 0,305 → 0,304 | Dielen 5,5 m → 45 × 4000 (B-035); UK 8 × 4000 → 6 × 4000 + 6000: **Frage 1** (Innenecke) |
| F16 | T-Form | 6,84 | 0,96 → 10,75 | 0,196 → 0,204 | Dielen 4,5/5,5 m → 30 × 4000 (B-035, 90er-Teilung); Freidielen 0 → 1 (R-B09); UK/Clips **Frage 1** |
| F17 | U-Form | 6,84 | 1,74 → 11,5 | 0,194 → 0,223 | wie F16; UK 8 × 3000 → 7 × 4000 (**Frage 1**) |
| F18 | O-Form | 13,68 | 0,54 → 4,36 | 0,329 → 0,331 | Dielen B-035; UK 10 Stück (alt mit 2 × 190 cm an den Ausschnittkanten) → 9 × 4000: **Frage 1** |
| F19 | Kreis | 10,15 → 10,179 | 7,44 → 4,68 | 0,340 → 0,296 | Fläche M4-07; Dielen B-035; UK 9 Stück mit vielen 4–36-cm-Stücken am Bogen → 8 × 4000: **Frage 1** |
| F20 | 360 × 400 | 14,4 | 10 | 0,443 → 0,419 | UK 12 → 10 × 4000 (UK-Lage) |
| F21 | Ausschnitt leer | 14,4 | 4,36 → 4,57 | 0,385 → 0,362 | Verschnitt: Rechenweg; UK (alt 133-cm-Stücke an den Ausschnittkanten): **Frage 1** |
| F22 | Ausschnitt anderer Belag | 14,4 | 4,36 → 5,21 | 0,434 → 0,432 | Dielen 3000 → 4000 (B-035); Verschnitt: Rechenweg; UK 12 → 13 Hölzer, Clips 700 → 850: **Frage 1** |
| F23 | 80 × 26 | 14,832 | 4 | 0,499 → 0,520 | gleich (Volumen +4,2 %: neu Lieferlängen × Querschnitt, M6-10) |
| F24 | 100 × 22 glattkant | 14,832 | 4 | 0,455 → 0,450 | Freidielen 0 → 1 (R-B09: 30 Dielen ≥ 25) |
| F25 | Holzfliese | 14,832 | 0,99 | – | gleich: 48 Fliesen je Stück (fehlerverdacht „je lfm“ ist behoben) |
| F26 | UK 45 × 60 | 14,832 | 4 | 0,451 → 0,449 | gleich |
| F27 | ALUecofix M | 14,832 | 4 | 0,364 → 0,363 | gleich |
| F28 | Hochterrasse | 14,832 | 4 | 0,579 → 0,609 | UK 112 → 125 m (vor M10-01 137 m): Stützen |
| F29 | vorhandene UK | 14,832 | 4 | 0,459 → 0,433 | UK: alt zusätzlich 2 × 473 cm aus 5000 mm: **Frage 2** |
| F30 | Gefälle | 14,832 | 4 | 0,435 → 0,433 | gleich |
| F31 | Versteifung ohne Rahmen | 14,832 | 4 | 0,454 → 0,433 | UK 15 → 13 × 4000 (Reste) |
| F32 | Rahmen | 14,832 | 4 | 0,459 → 0,458 | gleich |
| F33 | Versteifung mit Rahmen | 14,832 | 4 | 0,478 → 0,458 | UK 3 × 5000 + 13 × 4000 + 3000 → 2 × 5000 + 13 × 4000 (Reste) |
| F34 | doppelte UK | 14,832 | 4 | 0,543 → 0,541 | gleich |
| F35 | gewerblich | 14,832 | 4 | 0,435 → 0,433 | gleich |
| F36 | Bauelement A–B | 14,832 | 4 | 0,435 → 0,433 | gleich |
| F37 | + Verblendung | 14,832 | 4 | 0,458 → 0,455 | gleich (Blende 2 × 4000 + 5000, UK 13 × 4000) |
| F38 | + Rinne | 14,256 | 4 | 0,445 → 0,443 | Clips 600 → 650 (B-033) |
| F39 | Treppe Konstruktion | 14,832 | 3,74 → 4 | 0,471 → 0,454 | Treppe: Dielen 4 × 4000 → 4000 + 2 × 6000 (16 m wie alt), UK 12 × 4500 + 4000 → 13 × 4000 |
| F40 | Treppe Fundament | 14,832 | 3,74 → 4 | 0,471 → 0,454 | **Fehler** (fehlerverdacht); neu wie F39 ohne Stützen, dieselben Lieferstücke |
| F41 | 2-teilige Fächertreppe | 14,832 | 3,43 → 4 | 0,516 → 0,478 | Treppe (alt 5,5-m-Dielen und -UK) |
| F42 | 3-teilige Fächertreppe | 14,832 | 3,31 → 4 | 0,552 → 0,516 | Treppe |
| F43 | Verschnittvariante 2 | 14,832 | 12,73 → 20 | 0,466 → 0,495 | Varianten: 46 × 5500 → 48 × 6000 |

Der Verschnitt der Treppenfälle F39–F42 zählt neu nur den Belag der Fläche (4 % wie F01), alt auch die Treppendielen.

## Referenzfälle (M1-02)

**Nicht rechenbar (21):** Freiformen (13), Ausschnitte, Rundungen oder L-/T-Formen mit anderer Lage der Aussparung. Die Unterlagen enthalten dort keine vollständigen Maße:

- 2026-03-04-524, -04-09-4323, -04-26-1265, -04-28-4836, -05-03-797, -05-05-3156, -05-11-2229
- 2026-05-28-2398, -05-29-3162, -06-01-4502, -06-03-2910, -06-08-766 (v8, v11), -06-24-363 (v3, v10)
- 2026-07-25-1952, -08-13-4194 (v3, v5, v9), -09-03-3980, -09-15-3615-v3

Ihre Fläche ist, soweit möglich, in M4-13 verglichen; Dielen nach Nummer in M5-08.

**Rechenbar (26):**

| Fall | Ergebnis |
|---|---|
| 2025-08-26-719-v2 | Dielen gleich (87 × 4000); UK 11 × 6000 + 5000 → 10 × 6000 – Eingaben (Querstücke, Blendenhalter 8,6 cm), Hölzer 10 × 565 cm gleich |
| 2026-04-13-1946-v6 | Fehler (7000/6500 mm) |
| 2026-04-28-4413-v11 | Dielen 44 × 4500 → 5000 (B-035); Alu-UK 22 → 18 × 2000: **Frage 3** |
| 2026-04-28-859-v5 | Dielen B-035; Alu-UK 13 → 12 × 2000: **Frage 3** |
| 2026-04-29-164-v4 | Fehler (7000/6500 mm) |
| 2026-04-29-2412-v5 | Dielen gleich; UK ohne Artikelangabe in der Unterlage nicht gerechnet (Eingaben) |
| 2026-05-03-347-v4 | senkrecht laut Zeichnung: Dielen gleich; UK 10 × 6000 gleich, alt dazu 2 × 5000 + 3000 (Eingaben: Verblendung) |
| 2026-05-03-4381-v2 | Drittelverband: Dielen B-035; UK 15 Hölzer (alt 4,5/5,5 m) |
| 2026-05-11-129-v2, -2842-v2, -05-18-3484-v3 | nur Fläche in der Unterlage: gleich |
| 2026-05-12-1823-v4 | Dielen gleich (54 × 6000); UK 15 × 6000 gleich, alt dazu Querstücke (Eingaben) |
| 2026-05-19-3958-v4 | Dielen 31 × 6000 + 4500 + 4000 → 49 × 4000 (B-035, je zwei 200 cm in 4 m); Alu-UK 13 × 4000 gleich |
| 2026-05-28-4655-v2 | gleich (Dielen 42 × 4000, Alu-UK 20 × 2000) |
| 2026-06-07-4340-v4 | Dielen 3000 → 4000 (B-035); UK 5 × 5500 + 10 × 4500 → 13 × 5000 (B-035, Innenecke **Frage 1**) |
| 2026-06-11-3389-v3 | Dielen 30 × 5500 → 6000 (B-035) |
| 2026-06-15-1093-v7 | Dielen B-035; UK 36 → 21 Hölzer – Eingaben: die Unterlage zeigt Stützen à 39,9 cm (Hochterrasse) und Querstücke, die Terrassenart ist nicht erfasst |
| 2026-06-25-1275-v3 | Dielen 10 × 3000 → 5 × 6000, UK 4 × 3000 → 6000 + 4000 (B-035) |
| 2026-06-30-2295-v5 | senkrecht: Dielen gleich (294 × 6000 + 294 × 4000); Alu-UK 182 → 169 × 4000: **Frage 3** |
| 2026-07-07-2794-v2 | Dielen 4500 → 5000 (B-035); UK 29 statt 31 Linien (UK-Lage) |
| 2026-07-31-3374-v3 | Dielen 3000 → 4000 (B-035); UK Eingaben (50 Blendenhalter, Querstücke) |
| 2026-07-31-3374-v5 | Dielen B-035 (alt 4,5/3,0 m); UK Eingaben |
| 2026-08-06-2810-v3 | Dielen gleich (77 × 5000); UK 13 × 5000 gleich, alt dazu Querstücke (Eingaben) |
| 2026-08-17-1838-v2 | gleich (36 Fliesen) |
| 2026-08-26-1067-v2 | Dielen 111 × 3000 → 55 × 6000 + 4000 (B-035); Alu-UK 42 → 36 × 2000: **Frage 3** |
| 2026-09-15-3615-v6 | nur Fläche: gleich |

## Offene Fragen an Alexander

1. **Unterstützung der Dielenenden an Kanten, die nicht parallel zur UK laufen.** Der neue Planer legt die UK quer zu den Dielen im Achsabstand (höchstens 40 cm). Die äußeren Hölzer liegen bündig am Rand, an Dielenstößen liegt die UK doppelt. Der alte Planer legt mehr UK:
   - **Diagonal:** F03 (45°) 12 UK-Hölzer mit rund 52 m Schnittlänge statt neu rund 37 m (10 Lieferhölzer, 44 m). Das wirkt wie ein engerer Abstand oder zusätzliche Hölzer an den schrägen Rändern.
   - **Ausschnitte:** Stücke an den Kanten (F18 2 × 190 cm, F21/F22 133 cm).
   - **Innenecken:** L-, T- und U-Form.
   - **Bogen:** viele kurze Stücke von 4–36 cm am Kreis (F19).
   - Neu enden Dielen dort bis zu einem halben Achsabstand frei. **Frage:** Soll an Ausschnitt-, Innen- und Bogenkanten sowie an schrägen Rändern zusätzlich UK liegen (wie alt), oder genügt der Achsabstand? Bei diagonaler Verlegung: Achsabstand quer zur UK gemessen (neu) oder enger (alt)? Davon hängen dort auch die Clipmengen ab.
2. **Vorhandene UK (F29):** Der alte Planer liefert zusätzlich 2 × 473 cm aus 5000 mm, wie ein Rahmen, obwohl die Nutzungsart dort entfällt. Neu nicht. Gewollt, und wenn ja, nach welcher Regel?
3. **Alu-UK (RELO, ALUecofix XL):** Der alte Planer rechnet mehr Schienen: 2026-04-28-4413 22 statt 18, -859 13 statt 12, 2026-08-26-1067 42 statt 36, 2026-06-30-2295 182 statt 169. Ursache vermutlich Achsabstand oder Stöße der Alu-UK laut Artikeldaten (`Abstand_UK`). Das lässt sich nur mit der echten Artikeldatei prüfen. Bitte bestätigen, ob für Alu-UK ein eigener (engerer) Achsabstand gilt.

Außerdem besteht weiter die offene Frage zur Treppenkonstruktion (Fachkonzept 05, M7-05).

## Nachtrag Planungskern v6 (11.11.2026)

Grund aller Änderungen: **Planungskern v6 / Entscheidung Alexander 11.11.2026** (Planungsregeln Alexander, Abschnitte 1 und 4). Das Testsortiment führt jetzt wie die echten Artikeldaten zu jeder genuteten Diele das glattkante Gegenstück; dessen Schrauben befestigen Anfangs- und Enddiele.

- **Fuge 6 mm:** Wo die Dielen vorher gleich waren, steht jetzt die Abweichung „Dielen“ mit Grund „Fuge“: F01, F02, F06–F12, F20, F21, F23, F26–F38 und die Referenzfälle 2025-08-26-719, 2026-04-29-2412, -05-03-347, -05-12-1823, -05-28-4655, -06-30-2295, -08-06-2810. Die Paritätstests der Verlegung im domain-Paket (Dielenliste, Zuschnitt, Dielen nach Nummer) rechnen weiter mit den 5 mm des alten Planers (`altplanerFuge`), damit sie den Rechenweg prüfen.
- **Befestigung:** Die Clip-Abweichungen „B-033“ von F09, F11, F12, F13 und F38 sind verschwunden – die Clip-Packungen stimmen wieder mit dem alten Planer, der die Randdielen ebenfalls verschraubte.

| Fall | vorher (neu, 07.11.) | jetzt (neu, 11.11.) | alter Planer |
|---|---|---|---|
| F01, F06–F08, F26–F37 | 48 × 5000 | 47 × 5000 | 48 × 5000 |
| F02 | 74 × 4000 | 73 × 4000 | 74 × 4000 |
| F03 | Dielen 5 × 6000 + 42 × 5000 + 2 × 4000, Verschnitt 5,75 %, 1 Freidiele | 13 × 6000 + 21 × 5000 + 16 × 4000, 6,76 %, 2 Freidielen (neu „Fuge“) | 1 Freidiele |
| F04 | 32 × 5000 + 19 × 4000, 0,96 %, 2 Freidielen | 19 × 6000 + 12 × 5000 + 15 × 4000, 1,58 %, 1 Freidiele (Abweichung entfällt) | 1 Freidiele |
| F05 | Verschnitt 3,76 % (gleich) | 5,55 % (neu „Fuge“) | 3,76 % |
| F09, F12 | 48 × 6000 + 24 × 4000, Clips 1100 | 47 × 6000 + 24 × 4000, Clips 1050 (gleich) | 48 × 6000 + 24 × 4000, 1050 |
| F10 | 24 × 6000 + 48 × 5000, Clips 1200 (gleich) | 24 × 6000 + 46 × 5000 + 4000, Clips 1150 (neu „Befestigung“) | 1200 |
| F11 | 32 × 6000 + 48 × 4000, Clips 1200 | 32 × 6000 + 46 × 4000, Clips 1150 (gleich) | 1150 |
| F13 | 96 × 4000, Clips 1100 | 94 × 4000, Clips 1050 (gleich) | 1050 |
| F15 | 45 × 4000, Clips 500 (gleich) | 44 × 4000, Clips 450 (neu „Befestigung“) | 500 |
| F16, F17 | 30 × 4000 | 29 × 4000 | – |
| F18 | 37 × 5000 + 4000 | 36 × 5000 + 4000 | – |
| F19 | 18 × 6000 + 4 × 5000 + 10 × 4000, Clips 400 | 13 × 6000 + 6 × 5000 + 15 × 4000, Clips 450 | 500 |
| F20 | 62 × 4000 | 61 × 4000 | 62 × 4000 |
| F21 | 38 × 5000 + 5 × 4000, 4,57 % | 38 × 5000 + 4 × 4000, 4,47 % | 4,36 % |
| F22 | 4 × 6000 + 38 × 5000 + 6 × 4000, 5,21 % | 4 × 6000 + 38 × 5000 + 4 × 4000, 4,0 % | 4,36 % |
| F23 | 37 × 5000 | 36 × 5000 | 37 × 5000 |
| F38 | 46 × 5000, Clips 650 | 45 × 5000, Clips 600 (gleich) | 46 × 5000, 600 |
| F39–F42 | je 48 Dielen der Fläche | je 47 | – |
| F43 | 48 × 6000 | 47 × 6000 | 46 × 5500 + 2 × 5000 |
| Referenzfälle | 87, 100, 90, 54, 42, 294 + 294, 77 Dielen (719, 2412, 347, 1823, 4655, 2295, 2810) | je eine Reihe weniger: 86, 99, 89, 53, 41, 291 + 291, 76 | wie vorher |

Die übrigen Referenzfälle mit schon begründeter Abweichung „Dielen“ ändern nur die Zahlen (z. B. 2026-05-19-3958 49 → 48 × 4000, 2026-06-11-3389 30 × 6000 → 29 × 6000 + 4000).

