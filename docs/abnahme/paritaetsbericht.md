# Paritätsbericht (M10-01)

> **Nachtrag 11.11.2026 (Planungskern v6, Branch `feature/planungskern-belag-befestigung`):** Fuge 6 statt 5 mm und neue Befestigung (Anfangs- und Enddiele verschraubt, Clips + 5 %) – Abschnitt [Planungskern v6](#nachtrag-planungskern-v6-11112026) unten.
>
> **Nachtrag 12.11.2026 (Auflager aus der Höhe und Stellfüße an der Hauswand, Branch `feature/planungskern-auflager-hoehe`):** keine Änderung der verglichenen Werte – Abschnitt [Auflager aus der Höhe](#nachtrag-auflager-aus-der-höhe-planungskern-v6-12112026) unten.
>
> **Nachtrag 12.11.2026 (Musterverfahren und RIBOL, Branch `feature/planungskern-ribol-muster`):** Abschnitt [Musterverfahren](#nachtrag-musterverfahren-planungskern-v6-12112026) unten.
>
> **Nachtrag 12.11.2026 (Verlegemuster, Branch `feature/planungskern-v7-verband`):** Abschnitt [Verlegemuster](#nachtrag-verlegemuster-planungskern-v7-12112026) unten.
>
> **Nachtrag 11.11.2026 (UK-Regeln und Überlänge, Branch `feature/planungskern-uk-regeln`):** Abschnitt [UK-Regeln und Überlänge](#nachtrag-uk-regeln-und-überlänge-planungskern-v6-11112026) unten, gerechnet auf dem Stand mit Fuge 6 mm. Die Tabellen darunter zeigen den Stand vom 07.11.2026.

Stand 07.11.2026, Branch `feature/m10-01-paritaetsnachweis`. Alle Referenzkonfigurationen F01–F43 (M1-03, [12](../fachkonzept/12-referenzkonfigurationen.md)) und alle rechenbaren Referenzfälle aus den Planungsunterlagen (M1-02, [11](../fachkonzept/11-referenzfaelle.md)) werden im neuen Planer gerechnet und mit den Ergebnissen des alten Planers verglichen.

**Ergebnis:** 43 Konfigurationen und 26 Referenzfälle gerechnet. 15 Konfigurationen und 6 Referenzfälle stimmen in allen verglichenen Größen. Alle übrigen Abweichungen sind begründet. Eine Abweichung wurde im Code behoben (UK-Reste, siehe unten). Drei Punkte waren als **offene Fragen an Alexander** markiert (im Test „Frage 1–3“). Frage 1 ist seit 11.11.2026 beantwortet: Rand-UK an allen Kanten mit Dielenenden (Planungsregeln Alexander (Planungskern v6, 11.11.2026), Regel 3.3/3.4; Grund „Rand-UK“, siehe unten). Frage 2 und 3 sind weiter offen.

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
| Rand-UK | Planungsregeln 3.3/3.4 (Fachkonzept 3.11): an jeder Kante mit Dielenenden eine UK – Rand-UK bündig an der Kante, wo keine UK-Linie höchstens 6 cm daneben liegt (schräge Ränder, Ausschnitte, Innenecken, Bögen). Stücke und Lieferlängen weichen vom alten Planer ab (neu nur 4/5/6 m, B-035); die Dielenenden auf der Rand-UK werden befestigt. |
| Überlänge | *11.11.–12.11.2026:* Dielen kommen mit 3 cm Überlänge (R-B16) – weniger Meter; bei F04 aber 52 statt 46 Dielen und damit 2 Freidielen. Seit dem Musterverfahren ist das keine eigene Abweichung mehr (Grund „Planungskern v6“). |
| Planungskern v6 | *Seit 12.11.2026:* Musterverfahren R-B17 (Planungskern v6 Regeln 1.3/1.4): höchstens 3 Stücke je Diele, 5 mm Sägeschnitt, Reste ab 30 cm, bei höchstens 1 % Mehrlänge die Verteilung mit den wenigsten Dielen. F04: 152 Stücke brauchen mindestens 51 Dielen, nach der Staffel 2 Freidielen. |
| Planungskern v7 | *Seit 12.11.2026:* Verlegemuster R-B18 (Planungskern v7 Regel 9.3 mit 2.1): Verband nur über einer Dielenlänge (F06/F07 ohne Stoß und Doppel-UK), Wechselverband unregelmäßig mit Stücken ab 40 cm (F12), jede benutzte Stoßlinie mit Doppel-UK. Nachtrag unten. |
| Frage 2–3 | offen, siehe unten |

## Referenzkonfigurationen F01–F43

Werte alt → neu. „gleich“ heißt: alle verglichenen Größen stimmen.

| Fall | Abweichung von F01 | Fläche m² | Verschnitt % | Volumen m³ | Ergebnis |
|---|---|---|---|---|---|
| F01 | Startkonfiguration | 14,832 | 4 | 0,435 → 0,433 | gleich: 48 × 5000 + 1 Freidiele, UK 13 × 4000, 637 Clips |
| F02 | senkrecht | 14,832 | 22,75 | 0,499 → 0,491 | gleich (74 × 4000, UK 9 × 5000) |
| F03 | diagonal 45° | 14,832 | 2,2 → 4,69 (vor 11.11.: 5,75) | 0,457 → 0,453 | Dielen B-035 (alt 4,5/5,5 m; seit Überlänge 16 × 6000 + 17 × 5000 + 16 × 4000); UK 12 Stück (davon 5 in 4,5/5,5 m) → 5 × 5000 + 8 × 4000 mit vier Rand-UK, Linien enden vor der Rand-UK (Rand-UK; vor 11.11.: 6 × 5000 + 8 × 4000); Clips 750 gleich |
| F04 | diagonal 135° | 14,832 | 0,32 → 0,11 (vor 11.11.: 0,96) | 0,462 → 0,470 | Dielen B-035; Freidielen 1 → 2 (R-B09); UK 13 → 7 × 5000 + 8 × 4000 (Rand-UK); Clips 850 → 900 (Planungskern v6: 846 → 851 Punkte, eine Packung mehr; vor 11.11. gleich) |
| F05 | 30° | 14,832 | 3,76 → 2,42 (Überlänge; vor 11.11. gleich) | 0,473 → 0,462 | Dielen B-035 (seit Überlänge 35 × 6000 + 5000 + 6 × 4000); UK 14 → 6000 + 2 × 5000 + 12 × 4000 (Rand-UK); Clips 750 gleich |
| F06 | Halbverband | 14,832 | 4 | 0,445 → 0,443 | gleich |
| F07 | Drittelverband | 14,832 | 4 | 0,454 → 0,453 | gleich |
| F08 | Wechselverband | 14,832 | 4 | 0,435 → 0,433 | gleich |
| F09 | 800 × 309 | 24,72 | – → 0 | 0,713 → 0,710 | Clips 1050 → 1100 (B-033), sonst gleich |
| F10 | 800, Halbverband | 24,72 | – → 0 | 0,742 → 0,729 | UK 25 → 24 × 4000 (UK-Lage) |
| F11 | 800, Drittelverband | 24,72 | – → 0 | 0,732 → 0,729 | Clips 1150 → 1200 (B-033) |
| F12 | 800, Wechselverband | 24,72 | – → 0 | 0,722 → 0,720 | Clips 1100 → 1150 (B-033) |
| F13 | fest 400 cm | 24,72 | – → 0 | 0,673 → 0,705 | Freidielen 3 → 2 (R-B09); UK 11 × 6500 → 22 × 4000 (B-035); Clips (B-033) |
| F14 | 3 cm versetzt | 24,72 | 0,14 → 0 | 0,677 → 0,710 | **Fehler** (fehlerverdacht): 7000 mm → 48 × 6000 + 24 × 4000, UK 6500 → 4000 |
| F15 | L-Form | 10,26 | 7,31 → 11 | 0,305 → 0,309 | Dielen 5,5 m → 45 × 4000 (B-035); UK 8 × 4000 → 2 × 6000 + 5 × 4000 mit Rand-UK an der Innenecke (Rand-UK) |
| F16 | T-Form | 6,84 | 0,96 → 10,75 | 0,196 → 0,214 | Dielen 4,5/5,5 m → 30 × 4000 (B-035, 90er-Teilung); Freidielen 0 → 1 (R-B09); UK 6 × 4000 → 2 × 6000 + 3 × 4000 (Rand-UK an beiden Innenecken); Clips 400 gleich (vorher 300) |
| F17 | U-Form | 6,84 | 1,74 → 11,5 | 0,194 → 0,228 | wie F16; UK 8 × 3000 → 6000 + 6 × 4000, Clips 350 → 400 (Rand-UK an den Innenecken, Dielenenden darauf befestigt) |
| F18 | O-Form | 13,68 | 0,54 → 4,36 | 0,329 → 0,331 | Dielen B-035; UK 10 Stück (alt mit 2 × 190 cm an den Ausschnittkanten) → 9 × 4000: an beiden Ausschnittkanten liegt eine UK-Linie 2,8 cm daneben, also keine Rand-UK (Rand-UK) |
| F19 | Kreis | 10,15 → 10,179 | 7,44 → 4,68 | 0,340 → 0,306 | Fläche M4-07; Dielen B-035; UK 9 Stück mit vielen 4–36-cm-Stücken am Bogen → 9 × 4000 (vor 11.11.: 5000 + 8 × 4000; Linien enden vor der Rand-UK): 38 Rand-UK à 25,7 cm am Bogen, 6 davon von der Selbstkontrolle ergänzt (Rand-UK); Clips 500 gleich |
| F20 | 360 × 400 | 14,4 | 10 | 0,443 → 0,419 | UK 12 → 10 × 4000 (UK-Lage) |
| F21 | Ausschnitt leer | 14,4 | 4,36 → 4,57 | 0,385 → 0,367 | Verschnitt: Rechenweg; UK (alt 133-cm-Stücke an den Ausschnittkanten) → 2 × 6000 + 7 × 4000 mit Rand-UK 133 cm an beiden Ausschnittkanten, Clips 600 → 650 (Rand-UK) |
| F22 | Ausschnitt anderer Belag | 14,4 | 4,36 → 5,21 | 0,434 → 0,432 | Dielen 3000 → 4000 (B-035); Verschnitt: Rechenweg; UK 12 → 13 Hölzer, Clips 700 → 850: an den Kanten des anderen Belags enden die Dielen auf der doppelten UK (Rand-UK) |
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
| 2026-06-07-4340-v4 | Dielen 3000 → 4000 (B-035); UK 5 × 5500 + 10 × 4500 → 13 × 5000 (B-035; an der Innenecke liegt eine UK-Linie höchstens 6 cm daneben – Rand-UK) |
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

1. ~~**Unterstützung der Dielenenden an Kanten, die nicht parallel zur UK laufen.**~~ Beantwortet (11.11.2026): An jeder Kante, an der Dielen enden, liegt eine UK; schräge Kanten, Ausschnitt-, Innen- und Bogenkanten bekommen eine Rand-UK bündig entlang der Kante; eine Selbstkontrolle ergänzt fehlende und meldet sie (Planungsregeln Alexander (Planungskern v6, 11.11.2026), Regel 3.3/3.4; Fachkonzept 3.11). Bei diagonaler Verlegung bleibt der Achsabstand quer zur UK gemessen. Wirkung: siehe Grund „Rand-UK“ in den Tabellen; die UK-Mengen der Referenzfälle 2026-04-13-1946 (+ 4000), 2026-04-29-164 (+ 5000) und 2026-07-31-3374-v3 (+ 2 × 5000) steigen durch die Rand-UK (Gründe dort weiter „Fehler“ bzw. „Eingaben“).
2. **Vorhandene UK (F29):** Der alte Planer liefert zusätzlich 2 × 473 cm aus 5000 mm, wie ein Rahmen, obwohl die Nutzungsart dort entfällt. Neu nicht. Gewollt, und wenn ja, nach welcher Regel?
3. **Alu-UK (RELO, ALUecofix XL):** Der alte Planer rechnet mehr Schienen: 2026-04-28-4413 22 statt 18, -859 13 statt 12, 2026-08-26-1067 42 statt 36, 2026-06-30-2295 182 statt 169. Ursache vermutlich Achsabstand oder Stöße der Alu-UK laut Artikeldaten (`Abstand_UK`). Das lässt sich nur mit der echten Artikeldatei prüfen. Bitte bestätigen, ob für Alu-UK ein eigener (engerer) Achsabstand gilt.

Außerdem besteht weiter die offene Frage zur Treppenkonstruktion (Fachkonzept 05, M7-05).

## Nachtrag Planungskern v6 (11.11.2026)

Grund aller Änderungen: **Planungskern v6 / Entscheidung Alexander 11.11.2026** (Planungsregeln Alexander, Abschnitte 1 und 4), zusammen mit der Rand-UK (Abschnitt 3, oben). Das Testsortiment führt wie die echten Artikeldaten zu jeder genuteten Diele das glattkante Gegenstück; dessen Schrauben befestigen Anfangs- und Enddiele – auch dort, wo sie auf der Rand-UK liegen. Die übrigen Kreuzungen (UK-Linien und Rand-UK) bekommen Clips + 5 %.

- **Fuge 6 mm:** Wo die Dielen vorher gleich waren, steht jetzt die Abweichung „Dielen“ mit Grund „Fuge“: F01, F02, F06–F12, F20, F21, F23, F26–F38 und die Referenzfälle 2025-08-26-719, 2026-04-29-2412, -05-03-347, -05-12-1823, -05-28-4655, -06-30-2295, -08-06-2810. Die UK-Werte ändert die Fuge nicht. Die Paritätstests der Verlegung im domain-Paket rechnen weiter mit den 5 mm des alten Planers (`altplanerFuge`), damit sie den Rechenweg prüfen.
- **Befestigung:** Die Clip-Abweichungen „B-033“ (F09, F11, F12, F13, F38) und „Rand-UK“ (F17, F21) sind verschwunden – die Clip-Packungen stimmen wieder mit dem alten Planer, der die Randdielen ebenfalls verschraubte.

Werte gegenüber `main` mit Rand-UK und Seitenblende (Stand 3bfb094; die Seitenblende ändert keinen verglichenen Wert):

| Fall | main (5 mm, Clips + Rand) | jetzt (6 mm, Randreihen verschraubt, Clips + 5 %) | alter Planer |
|---|---|---|---|
| F01, F06–F08, F26–F37 | 48 × 5000 (gleich) | 47 × 5000 | 48 × 5000 |
| F02 | 74 × 4000 (gleich) | 73 × 4000 | 74 × 4000 |
| F03 | 5 × 6000 + 42 × 5000 + 2 × 4000, 5,75 %, 1 Freidiele | 13 × 6000 + 21 × 5000 + 16 × 4000, 6,76 %, 2 Freidielen (neu „Fuge“) | 1 Freidiele |
| F04 | 32 × 5000 + 19 × 4000, 0,96 %, 2 Freidielen, Clips 850 (gleich) | 19 × 6000 + 12 × 5000 + 15 × 4000, 1,58 %, 1 Freidiele (gleich), Clips 900 (neu „Befestigung“) | 850 |
| F05 | Verschnitt 3,76 % (gleich) | 5,55 % (neu „Fuge“) | 3,76 % |
| F09, F12 | Clips 1100 | 1050 (gleich), 47 × 6000 + 24 × 4000 | 1050 |
| F10 | Clips 1200 (gleich) | 1150 (neu „Befestigung“), 24 × 6000 + 46 × 5000 + 4000 | 1200 |
| F11 | Clips 1200 | 1150 (gleich), 32 × 6000 + 46 × 4000 | 1150 |
| F13 | Clips 1100, 96 × 4000 | 1050 (gleich), 94 × 4000 | 1050 |
| F15–F17 | 45 / 30 / 30 × 4000 | 44 / 29 / 29 × 4000; F17 Clips 400 → 350 (gleich) | – |
| F18 | 37 × 5000 + 4000 | 36 × 5000 + 4000 | – |
| F19 | 18 × 6000 + 4 × 5000 + 10 × 4000 | 13 × 6000 + 6 × 5000 + 15 × 4000 | – |
| F20, F23 | 62 × 4000 / 37 × 5000 (gleich) | 61 × 4000 / 36 × 5000 | wie main |
| F21 | 38 × 5000 + 5 × 4000 (gleich), Clips 650 | 38 × 5000 + 4 × 4000, Clips 600 (gleich) | 600 |
| F22 | 4 × 6000 + 38 × 5000 + 6 × 4000, 5,21 % | 4 × 6000 + 38 × 5000 + 4 × 4000, 4,0 % | 4,36 % |
| F38 | 46 × 5000, Clips 650 | 45 × 5000, Clips 600 (gleich) | 46 × 5000, 600 |
| F39–F43 | 48 Dielen der Fläche | 47 | – |
| Referenzfälle | 87, 100, 90, 54, 42, 294 + 294, 77 Dielen (719, 2412, 347, 1823, 4655, 2295, 2810) | je eine Reihe weniger: 86, 99, 89, 53, 41, 291 + 291, 76 | wie main |

Die übrigen Referenzfälle mit schon begründeter Abweichung „Dielen“ ändern nur die Zahlen (z. B. 2026-05-19-3958 49 → 48 × 4000, 2026-06-11-3389 30 × 6000 → 29 × 6000 + 4000).

## Nachtrag UK-Regeln und Überlänge (Planungskern v6, 11.11.2026)

Branch `feature/planungskern-uk-regeln`, gerechnet nach dem Einmergen von `main` (Fuge 6 mm, Befestigung). Planungsregeln Alexander (Planungskern v6, 11.11.2026), Regeln 1.1, 3.3, 3.5–3.7, 3.9 und Kern-Konstante Überlänge; Entscheidung 11.11.2026. Vergleich mit `main` (a56cea4) – alle übrigen F01–F43 und alle 26 Referenzfälle bleiben gleich:

| Fall | Größe | `main` (Fuge 6 mm) | jetzt (dazu Überlänge und UK-Regeln) | alter Planer | Ursache |
|---|---|---|---|---|---|
| F03 | Verschnitt | 6,76 % | 5,99 % | 2,2 % | Überlänge (R-B16) |
| F03 | Dielen | 13 × 6000 + 21 × 5000 + 16 × 4000 | 24 × 5000 + 31 × 4000 | 4,5/5,5 m | Überlänge |
| F03 | UK | 6 × 5000 + 8 × 4000 | 5 × 5000 + 8 × 4000 | 12 Stück | Linien enden vor der Rand-UK |
| F03 | Volumen | 0,475 m³ | 0,457 m³ | 0,457 m³ | Folge |
| F04 | Verschnitt | 1,58 % | 0,90 % | 0,32 % | Überlänge |
| F04 | Dielen | 19 × 6000 + 12 × 5000 + 15 × 4000 (234 m) | 3 × 6000 + 17 × 5000 + 32 × 4000 (231 m) | 4,5/5,5 m | Überlänge |
| F04 | Freidielen | 1 (gleich) | 2 | 1 | Überlänge: 52 statt 46 Dielen, Staffel ab 50 (R-B09) |
| F05 | Verschnitt | 5,55 % | 4,20 % | 3,76 % | Überlänge (Grund im Test weiter „Fuge“) |
| F05 | Dielen | 20 × 6000 + 20 × 5000 + 6 × 4000 | 12 × 6000 + 32 × 5000 + 2 × 4000 | 4,5/5,5 m | Überlänge |
| F19 | UK | 5000 + 8 × 4000 | 9 × 4000 | 9 Stück | Linien enden vor der Rand-UK |
| F19 | Volumen | 0,308 m³ | 0,306 m³ | 0,340 m³ | Folge |

Die Clips sind mit Fuge 6 mm und neuer Befestigung gleich wie auf `main` (F04 900). Vor dem Einmergen (Fuge 5 mm) hatte das Kürzen der Linien F04 von 850 auf 900 Clips gebracht (846 → 851 Punkte); mit der neuen Befestigung fällt das nicht mehr ins Gewicht.

Nicht im Vergleich, aber geändert: Lage der Auflager (erstes und letztes 5 cm vom UK-Ende, F30-Spalte 67 … 5 statt 68 … 4 mm), Querstreben (F01 mit Querstreben 48 statt 60 Querhölzer im 75-cm-Raster versetzt; F31/F33 weiter 24 Streben, nur versetzt), UK-Stöße mit Reststück mindestens 50 cm (kein Fall hat UK-Linien zwischen 6 und 6,5 m), ECO-SELECT-UK nur 4/5/6 m (das Testsortiment ist BASIC).

**Offen:** Die Verteilung zählt nach Metern; bei F04 bringt die Überlänge 3 m weniger, aber 6 Dielen mehr und damit eine Freidiele mehr. Ob bei gleicher oder fast gleicher Länge weniger Dielen zählen sollen (Planungskern Regel 1.3: bei ≤ 1 % Mehrlänge die Lösung mit den wenigsten Dielen), ist eine Frage an Alexander.

## Nachtrag Auflager aus der Höhe (Planungskern v6, 12.11.2026)

Branch `feature/planungskern-auflager-hoehe` auf `main` (187d400). Planungsregeln Alexander (Planungskern v6, 11.11.2026), Abschnitt 3a (Auflager aus der Höhe, Höchsthöhe, Fehleingaben) und Regel 3.11 (Stellfüße an der Hauswand); Fachkonzept 3.2, 3.9, 3.11, 3.12, R-C15–R-C17.

**Verglichene Werte:** Alle F01–F43 und alle 26 Referenzfälle rechnen in Fläche, Verschnitt, Dielen, Freidielen, UK und Clips **genau wie `main`** (Vergleich aller Abweichungen vorher → nachher ohne Unterschied); der Paritätstest bleibt unverändert. Gründe:

- Auflager, Pads und Stellfüße vergleicht der Test nicht (Testsortiment ohne sie, siehe Verfahren).
- Die Stützen der Hochterrasse sind 1 mm kürzer (Ausgleichshöhe mit 1 mm Gummiband: F28 40,0 statt 40,1 cm, Begründung „Stützen“ – der alte Planer hat 39,9 cm); die Lieferlängen der UK bleiben gleich.
- Kein Fall hat eine Seite an Bauelementen **und** Stellfüße (F36 hat die Hauswand, aber 8,6 cm Höhe – auf Pads bleibt die UK bündig).
- Kein Fall einer normalen Terrasse liegt über der Höchsthöhe 52,4 cm. Die 54,2 cm im Referenzfall 2026-06-15-1093 sind die Vorgabehöhe der Hochterrasse (Terrassenart nicht in der Unterlage); die Höhenprüfung der Referenzfälle rechnet ihn deshalb als Hochterrasse (offene Frage 24).

**Nicht im Vergleich, aber geändert** (Testdaten der Unit-Tests, Belag 21/22 mm, UK 40 × 60 mm): F30 Spalte 66 … 4 statt 67 … 5 mm, an C/D 2 + 2 mm statt Unterleger 5 mm, 8 + 8 mm statt Keil 14–22; F01 alle 91 Auflager auf 2 + 2 mm statt auf einem 5-mm-Pad (mit 23-mm-Diele: ein 2-mm-Pad).

## Nachtrag Musterverfahren (Planungskern v6, 12.11.2026)

Branch `feature/planungskern-ribol-muster`. Grund: **Planungskern v6** – Planungsregeln Alexander (Planungskern v6, 11.11.2026) Regeln 1.3 und 1.4, im Planer R-B17: Jeder Zuschnitt der Dielen (auch ohne gewählte Verschnittvariante) schneidet höchstens 3 Stücke je Diele mit 5 mm Sägeschnitt dazwischen, verwendet nur Reste ab 30 cm weiter und nimmt unter den gerechneten Verteilungen bei höchstens 1 % Mehrlänge die mit den wenigsten Dielen. Vergleich mit `main` (187d400) – UK, Clips, Verblendung und Fläche bleiben überall gleich, alle übrigen F01–F43 und Referenzfälle auch:

| Fall | Größe | `main` (187d400) | jetzt | alter Planer | Ursache |
|---|---|---|---|---|---|
| F03 | Dielen | 24 × 5000 + 31 × 4000 (244 m, 55 Dielen) | 30 × 6000 + 10 × 5000 + 4000 (234 m, 41 Dielen) | 4,5/5,5 m | Musterverfahren (Diele für Diele) |
| F03 | Verschnitt | 5,99 % | 1,68 % | 2,2 % | Folge |
| F03 | Freidielen | 2 | 1 (**gleich**, Abweichung „Fuge“ entfällt) | 1 | 41 statt 55 Dielen |
| F04 | Dielen | 3 × 6000 + 17 × 5000 + 32 × 4000 (231 m, 52 Dielen) | 7 × 6000 + 19 × 5000 + 25 × 4000 (237 m, 51 Dielen) | 4,5/5,5 m | höchstens 3 Stücke je Diele: 152 Stücke brauchen mindestens 51 Dielen |
| F04 | Verschnitt | 0,90 % | 2,91 % | 0,32 % | Folge |
| F04 | Freidielen | 2 (Grund „Überlänge“) | 2 (Grund „Planungskern v6“) | 1 | 51 Dielen, Staffel ab 50 (R-B09) |
| F05 | Dielen | 12 × 6000 + 32 × 5000 + 2 × 4000 (240 m) | 39 × 6000 (234 m) | 4,5/5,5 m | 1-%-Regel/je Lieferlänge |
| F05 | Verschnitt | 4,20 % | 1,51 % | 3,76 % | Folge |
| F09, F12 | Dielen | 47 × 6000 + 24 × 4000 (378 m, 71 Dielen), 0,53 % | 62 × 6000 + 4000 (376 m, 63 Dielen), 0 % | 48 × 6000 + 24 × 4000 | Musterverfahren (3 Stücke à 2 m aus 6 m) |
| F10 | Dielen | 24 × 6000 + 46 × 5000 + 4000 (378 m, 71 Dielen), 0,53 % | 41 × 6000 + 26 × 5000 (376 m, 67 Dielen), 0 % | – | Musterverfahren |
| F11 | Dielen | 32 × 6000 + 46 × 4000 (376 m, 78 Dielen) | 62 × 6000 + 4000 (376 m, 63 Dielen) | 32 × 6000 + 48 × 4000 | 1-%-Regel: gleiche Länge, weniger Dielen |
| F14 | Dielen | 48 × 6000 + 24 × 4000 (72 Dielen) | 64 × 6000 (64 Dielen) | Fehler | 1-%-Regel |
| F18 | Dielen | 36 × 5000 + 4000 (184 m), 3,72 % | 29 × 5000 + 10 × 4000 (185 m), 4,24 % | – | höchstens 3 Stücke, Sägeschnitt |
| F19 | Dielen | 13 × 6000 + 6 × 5000 + 15 × 4000 (168 m), 5,96 % | 13 × 6000 + 5 × 5000 + 16 × 4000 (167 m), 5,49 % | – | Musterverfahren |
| F21 | Dielen | 38 × 5000 + 4 × 4000 (206 m) | 19 × 6000 + 23 × 4000 (206 m), Verschnitt gleich | 38 × 5000 + 5 × 4000 | gleiche Länge und Anzahl, andere Mischung |
| F22 | Dielen | 4 × 6000 + 38 × 5000 + 4 × 4000 (230 m), 4,0 % | 19 × 6000 + 30 × 4000 (234 m), 5,64 % | 4,36 % | Teilfläche A1: 20 × 1,20 m in 7 × 4 m statt 4 × 6 m (höchstens 3 Stücke) |
| 2026-04-29-164-v4 | Dielen | 142 × 6000 + 4000 (856 m) | 128 × 6000 + 29 × 4000 (884 m) | Fehler | höchstens 3 Stücke je Diele |
| 2026-05-19-3958-v4 | Dielen | 48 × 4000 (192 m) | 32 × 6000 (192 m) | 194,5 m | 1-%-Regel: gleiche Länge, weniger Dielen |
| 2026-06-07-4340-v4 | Dielen | 48 × 5000 + 5 × 4000 (260 m) | 48 × 5000 + 3 × 6000 (258 m) | 264 m | Musterverfahren |
| 2026-07-31-3374-v3 | Dielen | 59 × 5000 + 4000 (299 m) | 53 × 5000 + 9 × 4000 (301 m) | – | höchstens 3 Stücke je Diele |

Die Abweichungen im Test bleiben dieselben bis auf **F03 Freidielen** (jetzt gleich wie der alte Planer); der Grund von **F04 Freidielen** ist jetzt „Planungskern v6“, der Grund „Überlänge“ wird von keinem Fall mehr gebraucht. Die domain-Paritätstests des Rechenwegs rechnen weiter wie der alte Planer ohne Musterverfahren (`altplanerMuster`). Die Verschnittoptimierung (F43, Variante 2) ist gleich geblieben.

**RIBOL (R-D10):** Das Öl rechnet sich jetzt aus der Ölfläche (Dielen und Blenden allseitig plus Deckseite, UK allseitig) × 44 ml/m² statt 0,2 l je m² Belagfläche. Das Zubehör des Altsortiments wird nicht verglichen (der alte Planer rechnet kein Öl), der Paritätstest ändert sich dadurch nicht.

**Offen:** Fragen 26–31 in [Fachkonzept 10](../fachkonzept/10-offene-fragen.md) – vor allem, ob die Grenze von 3 Stücken je Diele streng gelten soll (F04 bleibt bei 2 Freidielen, F22 +4 m, 2026-04-29-164 +28 m).

## Nachtrag Verlegemuster (Planungskern v7, 12.11.2026)

Branch `feature/planungskern-v7-verband`. Grund: **Planungskern v7** – Planungsregeln Alexander (Planungskern v7, 11.11.2026) Regel 9.3 mit 2.1, im Planer R-B18: Verband nur, wenn die Fläche länger als eine Diele ist; Stoßlinien je Reihe um ½ / ⅓ / ¼ der Stoßweite versetzt, Wechselverband unregelmäßig (nie wie die beiden Reihen davor), Stücke 40 cm bis Lieferlänge, jede benutzte Stoßlinie mit Doppel-UK. Der Fugenschnitt (Standard) ist unverändert – alle Fälle im Fugenschnitt rechnen wie auf `main` (dbf6f95). Vergleich mit `main`:

| Fall | Größe | `main` | jetzt | alter Planer | Grund |
|---|---|---|---|---|---|
| F06 (480 cm, Halbverband) | UK | 14 × 4000 | 13 × 4000 | 14 × 4000 | kein Verband unter einer Dielenlänge: keine Stöße, keine Doppel-UK |
| F06 | Clips | 700 | 650 | 700 | Folge |
| F07 (480 cm, Drittelverband) | UK | 15 × 4000 | 13 × 4000 | 15 × 4000 | wie F06 |
| F07 | Clips | 750 | 650 | 750 | Folge |
| F12 (800 cm, Wechselverband) | Dielen | 62 × 6000 + 4000 (376 m) | 52 × 6000 + 13 × 5000 (377 m) | 48 × 6000 + 24 × 4000 | unregelmäßig mit vier Viertel-Versätzen |
| F12 | UK | 23 × 4000 | 28 × 4000 | 23 × 4000 | Doppel-UK an vier Stoßlinien |
| F12 | Clips | 1100 | 1350 | 1100 | Folge |

F08 (480 cm, Wechselverband) hatte schon vorher keinen Stoß. F10 und F11 (Halb- und Drittelverband auf 800 cm) bleiben gleich. Die Referenzfälle werden im Fugenschnitt verglichen (2026-05-03-4381-v2 im Drittelverband nur in den Domain-Tests: 36 × 404 cm statt 134,7 + 269,3 cm, Frage 60). Offene Fragen 60–63 in [10](../fachkonzept/10-offene-fragen.md).
