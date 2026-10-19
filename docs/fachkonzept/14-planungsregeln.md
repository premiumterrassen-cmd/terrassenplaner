# 14 Planungsregeln aus Firmenwissen (M1-04)

Fachregeln für den neuen Planer aus dem Firmenwissen von ALTO HOLZ. Gelesen am 19.10.2026: Beschlussregister **v129** (`Claude-Wissen/00_Zentral`), Sortimentsmatrix 2027_07 (mit Korrektur B-212), Unternehmensprofil, technisches Merkblatt mit Klärungsliste M-01–M-15, Montagehinweise (10 Regeln) und die Antworten von Alexander aus [10](10-offene-fragen.md).

**Vertraulichkeit (B-020 ff.):** Hier stehen nur Planungsregeln. Werke, Herkunftsländer, Lieferanten, Einkaufspreise, Margen und Hersteller der Eigenmarken stehen nicht in diesem öffentlichen Repository – die Serien heißen nur BASIC, ECO SELECT, PREMIUM SELECT und MASSIV.

**Status:** **gilt** = Beschluss oder Antwort Alexander · **offen** = Quellen widersprechen sich oder fehlen, Frage unten · **Abweichung alt** = der alte Planer macht es anders (wird nicht übernommen, siehe [09](09-nicht-teil-der-kopie.md)).

Die mit ⚙ markierten Regeln sind im domain-Paket als ausführbare Regeln umgesetzt (`lib/src/regeln/`) und mit Tests belegt; die übrigen setzen die Feature-Issues ab M2 um.

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
| R-B01 ⚙ | Verdeckte Befestigung genutet: unter 100 mm **CLIP-FIXX** (1 Schraube je Clip); genutete PREMIUM SELECT ab 100 mm **DUO-CLIP-FIXX** (2 Schrauben); ECO SELECT und BASIC 100 mm genutet: CLIP-FIXX. Schrauben sind im Clip-Lieferumfang. | B-094, B-150, B-074 | gilt |
| R-B02 ⚙ | Dielen über 100 mm werden empfohlen, dann **ausschließlich von oben verschraubt** (glattkant); 2 Schrauben je Auflager ab 100 mm. | B-090, Matrix Artikelbeschreibungen | gilt |
| R-B03 | Ab 80 mm Breite Bombierung empfehlen; 60 und 80 mm sind am besten geeignet. | Montagehinweise Regel 7 | gilt (Hinweis) |
| R-B04 | Befestigungsmaterial wie bisher (CLIP-FIXX/DUO schwarz beschichtet), keine A4-Pflicht. | B-095 | gilt |
| R-B05 | Verschraubung von unten ist nicht zulässig. | Merkblatt M-10, Antwort 6 | gilt (Hinweis) |
| R-B06 | Fuge (Abstand der Dielen nebeneinander): **5 mm** im Planer; ERP-Flächenformel rechnet mit Breite + 5 mm. | Alexander (Frage 2), ERP-Plugins, Antwort 3 | gilt – 5 mm überall („auf der sicheren Seite“) |
| R-B07 | Längsstoß (Stirnseiten) 0–2 mm, Stirnkanten fasen und paraffinieren. | Merkblatt M-06, Antwort 6 | gilt (Hinweis) |
| R-B08 | Keine Dielenüberstände – UK bis an den Rand. | B-096 | gilt |
| R-B09 ⚙ | Freidielen im Planer und ERP: **ab 25 Hauptdielen eine, ab 50 zwei, ab 100 je weitere 50 eine** (100 → 3, 150 → 4 …); gezählt und geliefert wird die Hauptdiele des Deckbelags (im alten Planer in der längsten Lieferlänge). | B-079, Antwort 1 | gilt · Abweichung alt: Grenzfälle und große Mengen |
| R-B10 | Dielenlänge: der Planer wählt die passende Lieferlänge automatisch; man kann eine Länge erzwingen (z. B. Lagerbestand). | Alexander (Frage 4) | gilt |
| R-B11 | Verschnitt = geliefert minus geplant (Diele für 480 cm in 500 cm geliefert → 20 cm), für Belag und UK. | Alexander (Frage 3) | gilt |
| R-B12 | „Kurze Stücke verbinden“: ein Stoß muss nicht durchgehend sein, wenn bei nicht rechtwinkligen Terrassen ein kurzes Stück durch eine ganze Diele ersetzt werden kann. | Alexander (Frage 16) | gilt |
| R-B13 | Die letzte Dielenreihe wird längs auf Restbreite aufgeschnitten und markiert (rote Kante). | Alexander (Frage 1) | gilt |

## C Unterkonstruktion

| Nr. | Regel | Quelle | Status |
|---|---|---|---|
| R-C01 ⚙ | **UK-Achsabstand höchstens 40 cm**, sicherer unter 35 cm. | Montagehinweise Regel 3, Antwort 4 | gilt – max. 40 cm im Planer (auch PREMIUM-UK) |
| R-C02 | UK auf den Auflagern verschrauben (Ecken, Ränder, ausgewählte Punkte). | Montagehinweise Regel 2 | gilt (Hinweis) |
| R-C03 | Aussteifung: Leiterverband (Querstreben) oder Kopfband 45°. **Querstreben-Abstand 60 cm.** | Montagehinweise Regel 5, Alexander (Frage 17) | gilt |
| R-C04 | Gummiband/Pads (GUMO) zwischen Diele und UK bzw. unter der UK. | Montagehinweise Regel 8, B-039 | gilt |
| R-C05 | Blendenhalter: bei Verblendung kurze UK-Stücke (8,6–11 cm) im 90°-Winkel an den Sichtseiten. | Alexander | gilt |
| R-C06 | Vorhandene UK: neue UK wird darauf gebaut – UK-Holz und Bodenanker bleiben. | Alexander (Frage 7) | gilt |
| R-C07 | Untergrund ist nur Information für die Beratung, keine Wirkung auf die Berechnung. | Alexander (Frage 6) | gilt |
| R-C08 | Unter einer Rinne geht die UK bis 1–2 cm vor die Hauswand; darunter Auflageprofile, darauf Ventilationsprofile. | Alexander (Frage 14) | gilt |
| R-C09 | Gewerbliche Nutzung bleibt wie im alten Planer (nur mehr Gummiband); „UK zwingend versteift, nur PREMIUM SELECT“ ist zurückgestellt. | Alexander (Frage 13) | gilt |
| R-C10 ⚙ | Unterlüftung mind. 12 cm und Gefälle 1–2 % in Dielenlängsrichtung als **Hinweise**; der Planer rechnet mit **2 cm Wandabstand**. | Merkblatt M-07, Antwort 5 | gilt |

## D Anschluss, Treppen, Zubehör

| Nr. | Regel | Quelle | Status |
|---|---|---|---|
| R-D01 | Rinne ist fest im Artikel verankert, nur an den Seiten, als Ventilationsprofil oder Entwässerungsrinne; die Lageauswahl wählt die Artikelvariante. | Alexander (Frage 9) | gilt |
| R-D02 | Treppe „Fundament“: Betontreppe vorhanden, wird nur belegt; „Konstruktion“: Planer berechnet die Treppe. | Alexander (Frage 11) | gilt · Abweichung alt: F40 |
| R-D03 | Treppenhöhe unabhängig von der Terrassenhöhe (andere Bauteile vorhanden). | Alexander (Frage 8) | gilt |
| R-D04 | Zubehör „Tatsächlich“: berechneter Wert, änderbar; der geänderte Wert erscheint im Angebot unter dem berechneten. | Alexander (Frage 10) | gilt |
| R-D05 | Mengenfaktoren aus realen Projekten (Prüfgröße, nicht Rechenweg): Dielen-lfm ≈ m² × 1000 / (Breite + 6) × 1,07; UK-lfm ≈ m² / 0,40 × 1,1; Clips ≈ Dielen-lfm / 0,4; GUMO/Pads ≈ UK-lfm (alle 50 cm); Öl 0,2 l/m². | Unternehmensprofil | gilt (Plausibilitätsprüfung) |
| R-D06 | Pflege: vor der Montage alle Seiten inkl. Stirnseiten ölen, danach mindestens jährlich und vor dem Winter (Hinweistext, Öl als Zubehör). | B-091, B-182, B-221 | gilt (Hinweis) |
| R-D07 | Freidielen werden nur im Planer und ERP gerechnet – nie im Shop oder Chat zugesagt. | B-079 | gilt |

## Widersprüche zum alten Planer

Werden **nicht** übernommen (Liste in [09](09-nicht-teil-der-kopie.md)): einseitig genutete Anfangsdielen (R-A07), KOPPLEX statt GUMO (R-A09), „22 mm“ (R-A04), Zwischenlängen 3,0/4,5/5,5 m sowie Dielen 7000 mm bei Serien mit 4/5/6 m und UK 6500 mm (R-A06, F14), abweichende Freidielen-Anzahl bei Grenzfällen und großen Mengen (R-B09), Treppe Fundament wie Konstruktion (R-D02, F40), veraltete Artikel (R-A01).

## Antworten Alexander (19.10.2026)

1. **Freidielen:** „bei 25 eine Diele, bei 50 zwei Dielen bis 100 und dann aller 50 Stück eine Freidiele“; sie beziehen sich immer auf die Hauptdiele des Deckbelags → R-B09.
2. **Zwischenlängen:** gibt es nicht mehr, es gilt B-035 → R-A06.
3. **Fuge:** überall 5 mm, „da sind wir auf der sicheren Seite“ → R-B06.
4. **UK-Achsabstand:** maximal 40 cm im Planer → R-C01.
5. **Unterlüftung, Gefälle:** nur Hinweise; Wandabstand im Planer 2 cm → R-C10.
6. **Längsstoß 0–2 mm, keine Verschraubung von unten:** beides korrekt (Hinweise) → R-B07, R-B05.
