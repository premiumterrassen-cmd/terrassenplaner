# 14 Planungsregeln aus Firmenwissen (M1-04)

Fachregeln für den neuen Planer aus dem Firmenwissen von ALTO HOLZ. Abgleich mit den **Planungsregeln Alexander (Planungskern v6, 11.11.2026)** Abschnitte 1 und 4 am 11.11.2026 (R-B01, R-B06, R-B09, R-B14, R-B15, R-D07, R-D09; Rand-UK aus Abschnitt 3: R-C11, R-C12) sowie Abschnitte 1 und 3 zur UK (R-B16 Überlänge, R-C03, R-C10, R-C13, R-C14; ECO-UK B-230). Gelesen am 19.10.2026: Beschlussregister **v129** (`Claude-Wissen/00_Zentral`), Sortimentsmatrix 2027_07 (mit Korrektur B-212), Unternehmensprofil, technisches Merkblatt mit Klärungsliste M-01–M-15, Montagehinweise (10 Regeln) und die Antworten von Alexander aus [10](10-offene-fragen.md).

**Vertraulichkeit (B-020 ff.):** Hier stehen nur Planungsregeln. Werke, Herkunftsländer, Lieferanten, Einkaufspreise, Margen und Hersteller der Eigenmarken stehen nicht in diesem öffentlichen Repository – die Serien heißen nur BASIC, ECO SELECT, PREMIUM SELECT und MASSIV.

**Status:** **gilt** = Beschluss oder Antwort Alexander · **offen** = Quellen widersprechen sich oder fehlen, Frage unten · **Abweichung alt** = der alte Planer macht es anders (wird nicht übernommen, siehe [09](09-nicht-teil-der-kopie.md)).

Die mit ⚙ markierten Regeln sind im domain-Paket ausführbar und mit Tests belegt: holzabhängige Werte als **Daten der Holzart** (`lib/src/holzart/robinie.dart`, M2-08), holzunabhängige in `lib/src/regeln/planungsregeln.dart`. Die übrigen setzen die Feature-Issues ab M2 um.

## A Sortiment und Daten

| Nr. | Regel | Quelle | Status |
|---|---|---|---|
| R-A01 | Die Master-Artikelliste ist die eine Quelle; in den Planer nur Artikel mit „im Planer = ja“. Artikelnummern, Titel und Preise wie im Shop; Preise im Planer sind nur Anzeige, führend ist das ERP. | B-122, B-156, B-152, B-123, B-055 | gilt · Abweichung alt: veraltete Artikel |
| R-A02 | Holzart im Planer: **nur Robinie**, später Kastanie mit eigenen Planungseigenschaften. | Alexander 19.10.2026 | gilt |
| R-A03 ⚙ | Verbindlich ist die Sortimentsmatrix 2027_07; Formate außerhalb sind keine Planungsoption. | B-030 | gilt |
| R-A04 ⚙ | Dielenstärken: BASIC 21 und 26 mm (26 nur genutet, glattkant nur 21), ECO SELECT und PREMIUM SELECT 23 mm, MASSIV 25 mm. **„22 mm“ gibt es nicht** (= 21). | B-032, Matrix Z. 10/15 | gilt · Abweichung alt: „60 x 22 mm“ |
| R-A05 ⚙ | Dielenbreiten genutet: BASIC 60/80/100/110, ECO SELECT 50/60/80/100, PREMIUM SELECT 60/80/90/100/118, MASSIV 50–90 (in 10er-Schritten). Glattkant: BASIC 50/60/80/100/110, ECO SELECT 50/60/80/100/120, PREMIUM SELECT 60/80/100/118, MASSIV 50–120. | Matrix Z. 9/14, B-036, B-174 | gilt |
| R-A06 ⚙ | Lieferlängen: ECO SELECT 4/5/6/7 m, BASIC und PREMIUM SELECT 4/5/6 m; MASSIV Längenmix 0,8/1,2/1,6/2,0 m (Endlosverlegung, Verkauf je m², Paket 1,5 m²). | B-035, B-036 | gilt – **keine Zwischenlängen** (Antwort 2) · Abweichung alt: 3,0/4,5/5,5 m |
| R-A07 ⚙ | **Keine einseitig genuteten Dielen**; Anfangs- und Enddiele sind normale Dielen. | B-033 | gilt · Abweichung alt: einseitig genutete Anfangsdielen |
| R-A08 ⚙ | UK-Formate: Breite und Stärke sind tauschbar (40 × 100 = 100 × 40, ein Artikel). BASIC 45 × 40/60; PREMIUM SELECT BSH 45 × 60 und 45 × 70; ECO SELECT keilgezinkt und getrocknet nur mit 40 mm auf einer Seite (40/60/80/90/100 × 40), dazu 60 × 60, 60 × 80, 90 × 90 ungetrocknet; **entfallen** 60 × 90, 60 × 100, 90 × 80, 90 × 100. MASSIV-UK 40/60 × 40–100. | B-034, B-212, Matrix Z. 18/19 | gilt |
| R-A09 | KOPPLEX wird abverkauft und durch GUMO ersetzt; RELO-Alu bleibt normaler Artikel. | B-039 | gilt · Abweichung alt: KOPPLEX |
| R-A10 | Die mit GS gemeinsam ausgewählten Zubehör-Artikel bleiben im Planer. | B-155 | gilt |
| R-A11 | Jede Import-/Exportdatei vollständig – keine Felder weglassen (gilt für die ERP-Exporte Materialliste und Zuschnittliste, siehe [08](08-ergebnisse.md)). | B-186 | gilt |
| R-A12 | Rechengewicht Robinie 750 kg/m³ (wie die ERP-Plugins); Gewicht je lfm = Breite × Stärke (mm) × 0,00075 kg. | Unternehmensprofil | gilt |

## B Belag und Befestigung

| Nr. | Regel | Quelle | Status |
|---|---|---|---|
| R-B01 ⚙ | Verdeckte Befestigung genutet: unter 100 mm **CLIP-FIXX** (1 Schraube je Clip); genutete PREMIUM SELECT ab 100 mm **DUO-CLIP-FIXX** (2 Schrauben); ECO SELECT und BASIC 100 mm genutet: CLIP-FIXX. Schrauben sind im Clip-Lieferumfang. **Clips = Kreuzungen + 5 %**, günstigste VPE 250/100/50; **Anfangs- und Enddiele sichtbar verschraubt** (wie R-B02); TX20-Bit nur ohne Clip-Packung mit Bit, TX25-Bit nur ohne 600er-Schraubenset. Artikel und Mengen: `befestigungsbedarf`, `bits` (M5-09, [02 · 2.6](02-terrassenbelag.md)). | B-094, B-150, B-074; Planungsregeln Alexander (Planungskern v6, 11.11.2026) Regeln 4.1–4.3, Entscheidung Alexander 11.11.2026 | gilt |
| R-B02 ⚙ | Dielen über 100 mm werden empfohlen, dann **ausschließlich von oben verschraubt** (glattkant); 2 Schrauben je Auflager ab 100 mm. | B-090, Matrix Artikelbeschreibungen | gilt |
| R-B03 ⚙ | Ab 80 mm Breite Bombierung empfehlen; 60 und 80 mm sind am besten geeignet. Meldung im Planer: `belagmeldungen` (M5-10, [02 · 2.8](02-terrassenbelag.md)). | Montagehinweise Regel 7 | gilt (Hinweis) |
| R-B04 | Befestigungsmaterial wie bisher (CLIP-FIXX/DUO schwarz beschichtet), keine A4-Pflicht. | B-095 | gilt |
| R-B05 | Verschraubung von unten ist nicht zulässig. | Merkblatt M-10, Antwort 6 | gilt (Hinweis) |
| R-B06 ⚙ | Fuge (Abstand der Dielen nebeneinander): **6 mm**, eine Reihe ist Dielenbreite + Fuge (Verlegung, Preis je m², Prüfung „Fläche kleiner als Belag“, 3D-Modell) – einheitlich mit R-D05 (Breite + 6). | Planungsregeln Alexander (Planungskern v6, 11.11.2026) Regel 1.2; Entscheidung Alexander 11.11.2026 | gilt – ersetzt „mit 5 mm rechnen“ vom 19.10.2026 (Antwort 3); die Paritätstests der Verlegung rechnen weiter mit den 5 mm des alten Planers |
| R-B07 | Längsstoß (Stirnseiten) 0–2 mm, Stirnkanten fasen und paraffinieren. | Merkblatt M-06, Antwort 6 | gilt (Hinweis) |
| R-B08 | Keine Dielenüberstände – UK bis an den Rand. | B-096 | gilt |
| R-B09 ⚙ | Freidielen im Planer und ERP: **ab 25 Hauptdielen eine, ab 50 zwei, ab 100 je weitere 50 eine** (100 → 3, 150 → 4 …); gezählt und geliefert wird die Hauptdiele des Deckbelags (im alten Planer in der längsten Lieferlänge). Die Staffel bleibt, obwohl B-228 und der Planungskern v6 (Regel 1.5) nur „1 Freidiele ab 25 Dielen“ nennen. | B-228 (ersetzt B-079), Antwort 1; Entscheidung Alexander 11.11.2026 (Staffel bleibt) | gilt · Abweichung alt: Grenzfälle und große Mengen |
| R-B10 ⚙ | Dielenlänge: der Planer wählt die passende Lieferlänge automatisch (kürzeste, die die Reihe abdeckt); man kann eine Länge erzwingen (z. B. Lagerbestand). | Alexander (Frage 4) | gilt |
| R-B11 | Verschnitt = geliefert minus geplant (Diele für 480 cm in 500 cm geliefert → 20 cm), für Belag und UK. | Alexander (Frage 3) | gilt |
| R-B12 ⚙ | „Kurze Stücke verbinden“: ein Stoß muss nicht durchgehend sein, wenn bei nicht rechtwinkligen Terrassen ein kurzes Stück durch eine ganze Diele ersetzt werden kann. | Alexander (Frage 16) | gilt |
| R-B13 | Die letzte Dielenreihe wird längs auf Restbreite aufgeschnitten und markiert (rote Kante). | Alexander (Frage 1) | gilt |
| R-B14 ⚙ | **Befestigung umschaltbar:** von oben ↔ sichtverdeckt tauscht die Diele derselben Serie und Breite glattkant ↔ genutet (`gegenstueck`, `Befestigungsbedarf.wechsel`); ohne Gegenstück in den Artikeldaten bleibt es bei den Arten des Profils und der Meldung „nicht möglich“. | Planungsregeln Alexander (Planungskern v6, 11.11.2026) Regel 4.4 | gilt |
| R-B15 ⚙ | **Bohrsenker immer als optionale Position** (50-80-008, 1 Stück, Preis aus den Artikeldaten): in Materialliste, Planungsunterlagen und GrandTotal-Export als „optional – nicht in der Summe“, nicht im Warenkorb-Link; nicht, wenn er schon fest gewählt ist (`bohrsenkerAngebot`, `Materialzusatz.optional`). | Planungsregeln Alexander (Planungskern v6, 11.11.2026) Regel 4.5 | gilt |
| R-B16 ⚙ | **Überlänge 3 cm:** Dielen kommen mit 3 cm Überlänge; eine Lieferlänge nimmt Stücke bis zu ihrer Länge plus 3 cm auf, ein Dielenstoß ist erst darüber nötig (6,00 m Fläche = eine 6-m-Diele, 2 × 3,00 m aus einer 6-m-Diele). Holzfliesen ohne. Sägeschnitt (Kern 0,5 cm) offen. | Planungsregeln Alexander (Planungskern v6, 11.11.2026), Kern-Konstante Überlänge; Entscheidung 11.11.2026; vgl. B-111 | gilt – Fachkonzept 2.3/2.7 |

## C Unterkonstruktion

| Nr. | Regel | Quelle | Status |
|---|---|---|---|
| R-C01 ⚙ | **UK-Achsabstand höchstens 40 cm**, sicherer unter 35 cm. | Montagehinweise Regel 3, Antwort 4 | gilt – max. 40 cm im Planer (auch PREMIUM-UK) |
| R-C02 | UK auf den Auflagern verschrauben (Ecken, Ränder, ausgewählte Punkte). | Montagehinweise Regel 2 | gilt (Hinweis) |
| R-C03 ⚙ | Aussteifung (nur optional, kein Standard): Leiterverband (Querstreben) oder Kopfband 45°. **Querhölzer im 75-cm-Raster, von Feld zu Feld versetzt** (bis 11.11.2026: 60 cm). | Montagehinweise Regel 5, Alexander (Frage 17); Planungsregeln Alexander (Planungskern v6, 11.11.2026), Regel 3.7; Entscheidung Alexander 11.11.2026 | gilt – Fachkonzept 3.7 |
| R-C04 | Gummiband/Pads (GUMO) zwischen Diele und UK bzw. unter der UK. | Montagehinweise Regel 8, B-039 | gilt |
| R-C05 ⚙ | Blendenträger: bei Verblendung senkrechte Hölzer aus dem UK-Holz der Serie an den Sichtseiten, höchstens 40 cm auseinander (an den Stirnenden der UK und an der anderen Seite), Länge = Höhe − 2 cm − Dielenstärke, 2 Schrauben je Holz (`verblendungsbedarf`, [04 · 4.2](04-terrassenanschluss.md)). | Alexander; Planungsregeln Alexander (Planungskern v6, 11.11.2026), Abschnitt 4a.6 | gilt · früher: kurze Stücke 8,6–11 cm über die ganze Höhe im UK-Achsabstand |
| R-C06 | Vorhandene UK: neue UK wird darauf gebaut – UK-Holz und Bodenanker bleiben. | Alexander (Frage 7) | gilt |
| R-C07 | Untergrund ist nur Information für die Beratung, keine Wirkung auf die Berechnung. | Alexander (Frage 6) | gilt |
| R-C08 | Unter einer Rinne geht die UK bis 1–2 cm vor die Hauswand; darunter Auflageprofile, darauf Ventilationsprofile. | Alexander (Frage 14) | gilt |
| R-C09 | Gewerbliche Nutzung bleibt wie im alten Planer (nur mehr Gummiband); „UK zwingend versteift, nur PREMIUM SELECT“ ist zurückgestellt. | Alexander (Frage 13) | gilt |
| R-C10 | Unterlüftung mind. 12 cm und Gefälle 1–2 % in Dielenlängsrichtung als **Hinweise**. **Wandabstand: im Plan und in den Unterlagen nur „Abstand lassen“, kein fester Wert** – der Planer rechnet mit keinem Wandabstand (die frühere Konstante 2 cm ist entfernt). Stellfüße an der Hauswand (UK 1 cm vor der Wand, Regel 3.11) folgen später. | Merkblatt M-07, Antwort 5; Planungsregeln Alexander (Planungskern v6, 11.11.2026), Regel 3.9 | gilt |
| R-C11 ⚙ | **Rand-UK an jeder Kante mit Dielenenden**, bündig entlang der Kante, kein Überstand: schräge Ränder (über 12° zur UK, über 8 cm quer zur Diele), Ausschnittkanten auf der Terrassenseite, Innenecken L/T/U, Bögen je Sehne, Ränder bei diagonaler/freier Verlegung – wo keine UK-Linie höchstens 6 cm daneben liegt. Kanten parallel zur Diele: keine. | Planungsregeln Alexander (Planungskern v6, 11.11.2026), Regel 3.3; offene Frage 19 | gilt – Fachkonzept 3.11 |
| R-C12 ⚙ | **Selbstkontrolle:** Prüfpunkte alle 10 cm entlang jeder Kante mit Dielenenden, Toleranz 6 cm; fehlt die UK an mehr als 10 % der Punkte, wird die Rand-UK ergänzt und in den Hinweisen gemeldet. | Planungsregeln Alexander (Planungskern v6, 11.11.2026), Regel 3.4 | gilt – Fachkonzept 3.11 |
| R-C13 ⚙ | **UK-Stoß mit Reststück mindestens 50 cm:** UK-Linien über der längsten Lieferlänge werden gestückelt (ganze Längen und der Rest), der Rest ist mindestens 50 cm (610 cm → 560 + 50 cm); der Stoß liegt auf einem Auflager. | Planungsregeln Alexander (Planungskern v6, 11.11.2026), Regel 3.5 | gilt – Fachkonzept 3.11 |
| R-C14 ⚙ | **Auflager an den Enden:** das erste und letzte Auflager jeder UK 5 cm vom Ende, dazwischen gleichmäßig höchstens im Auflagerabstand (60 cm); eine UK bis 12 cm bekommt ein Auflager in der Mitte. | Planungsregeln Alexander (Planungskern v6, 11.11.2026), Regel 3.6 | gilt – Fachkonzept 3.12 |

## D Anschluss, Treppen, Zubehör

| Nr. | Regel | Quelle | Status |
|---|---|---|---|
| R-D01 | Rinne ist fest im Artikel verankert, nur an den Seiten, als Ventilationsprofil oder Entwässerungsrinne; die Lageauswahl wählt die Artikelvariante. | Alexander (Frage 9) | gilt |
| R-D02 | Treppe „Fundament“: Betontreppe vorhanden, wird nur belegt; „Konstruktion“: Planer berechnet die Treppe. | Alexander (Frage 11) | gilt · Abweichung alt: F40 |
| R-D03 | Treppenhöhe unabhängig von der Terrassenhöhe (andere Bauteile vorhanden). | Alexander (Frage 8) | gilt |
| R-D04 | Zubehör „Tatsächlich“: berechneter Wert, änderbar; der geänderte Wert erscheint im Angebot unter dem berechneten. | Alexander (Frage 10) | gilt |
| R-D05 | Mengenfaktoren aus realen Projekten (Prüfgröße, nicht Rechenweg): Dielen-lfm ≈ m² × 1000 / (Breite + 6) × 1,07; UK-lfm ≈ m² / 0,40 × 1,1; Clips ≈ Dielen-lfm / 0,4; GUMO/Pads ≈ UK-lfm (alle 50 cm); Öl 0,2 l/m². | Unternehmensprofil | gilt (Plausibilitätsprüfung) |
| R-D06 | Pflege: vor der Montage alle Seiten inkl. Stirnseiten ölen, danach mindestens jährlich und vor dem Winter (Hinweistext, Öl als Zubehör). | B-091, B-182, B-221 | gilt (Hinweis) |
| R-D07 | Freidielen: im Planer, in GrandTotal und in den Planungsunterlagen als eigene Position mit 0,00 € (Staffel R-B09); **nicht im Warenkorb-Link**. Im Shop werden sie nicht erwähnt oder zugesagt, im Chat dürfen sie erwähnt werden. | B-228 (ersetzt B-079) | gilt |
| R-D08 ⚙ | Seitenblende: glattkante Diele der Serie in Belagstärke; Breite = breiteste Breite der Serie unter der Aufbauhöhe (steht nicht auf dem Boden auf), höchstens 100 mm (90 mm gibt es nicht → 80 mm); über ca. 13 cm zwei Blenden à 60 mm mit Zwischenraum; fehlt die Breite → Rückfrage statt raten; Ecken auf Gehrung (+5 cm je Kante im Zuschnitt); „Blende an allen Kanten“ = alle Kanten außer Hauswand/angrenzender Seite. Umsetzung: `blendenZumBelag`, `blendenreihen`, `verblendungsbedarf` ([04 · 4.2](04-terrassenanschluss.md)). | Planungsregeln Alexander (Planungskern v6, 11.11.2026), Abschnitt 4a.1–4a.5, 4a.7 | gilt · Abweichung alt: Verweis „moeglicheVerblendung“, nur 19–23 mm, Reihen bis zur Blendenhöhe |
| R-D09 ⚙ | **Plausibilität der Fläche** (m²): bis 0,05 m² Fehler „Maße fehlen oder sind falsch“, über 1.000 m² Fehler „unplausibel groß“, außerhalb 1–300 m² Hinweis – im Schritt Grundriss und in den Hinweisen der Planungsunterlagen (`pruefeFlaeche`). Die Grenzen der Seitenlängen (50 cm bis 300 m) bleiben. | Planungsregeln Alexander (Planungskern v6, 11.11.2026) Regel 1.7 | gilt |

## Widersprüche zum alten Planer

Werden **nicht** übernommen (Liste in [09](09-nicht-teil-der-kopie.md)): einseitig genutete Anfangsdielen (R-A07), KOPPLEX statt GUMO (R-A09), „22 mm“ (R-A04), Zwischenlängen 3,0/4,5/5,5 m sowie Dielen 7000 mm bei Serien mit 4/5/6 m und UK 6500 mm (R-A06, F14), abweichende Freidielen-Anzahl bei Grenzfällen und großen Mengen (R-B09), Treppe Fundament wie Konstruktion (R-D02, F40), veraltete Artikel (R-A01).

## Antworten Alexander (19.10.2026)

1. **Freidielen:** „bei 25 eine Diele, bei 50 zwei Dielen bis 100 und dann aller 50 Stück eine Freidiele“; sie beziehen sich immer auf die Hauptdiele des Deckbelags → R-B09.
2. **Zwischenlängen:** gibt es nicht mehr, es gilt B-035 → R-A06.
3. **Fuge:** überall 5 mm, „da sind wir auf der sicheren Seite“ → R-B06. *Ersetzt am 11.11.2026: 6 mm (Planungskern v6, Entscheidung Alexander).*
4. **UK-Achsabstand:** maximal 40 cm im Planer → R-C01.
5. **Unterlüftung, Gefälle:** nur Hinweise; Wandabstand ohne festen Wert („Abstand lassen“, Planungskern v6 Regel 3.9) → R-C10.
6. **Längsstoß 0–2 mm, keine Verschraubung von unten:** beides korrekt (Hinweise) → R-B07, R-B05.
