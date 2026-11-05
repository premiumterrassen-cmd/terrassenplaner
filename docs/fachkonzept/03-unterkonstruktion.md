# 03 Unterkonstruktion

Messwerte: Grundfall aus [00 Rahmen](00-rahmen.md) (2.066,57 €), jeweils nur eine Einstellung geändert.

## 3.1 Art der Terrasse

| Art | Vorgabehöhe | Besonderheiten |
|---|---|---|
| Normale Terrasse (Vorgabe) | 8,6 cm | – |
| Hochterrasse | 54,2 cm | doppelte UK (Lattenkreuz); UK-Holz 3000/4000/5000 mm, Bodenanker L zur Aufständerung 0–23 mm, mehr KOPPLEX-1, kein KOPPLEX-3 → 3.120,27 € |
| Vorhandene UK | 14,2 cm (Minimum) | neue UK wird **auf** die vorhandene gebaut (daher weiter UK-Holz und Bodenanker); Feld „Spannweite der Unterkonstruktion – Spannweite: cm“; 3.6 Nutzungsart entfällt; Meldung „Der Höhenreferenz Punkt unterschreitet die minimale Höhe. Er wurde korrigiert“ |

Neuer Planer (M6-01):

- Unterpunkt 3.1 „Art der Terrasse“ mit den drei Arten als Chips (Vorgabe normale Terrasse) und der Vorgabehöhe darunter; Planungsstand-Felder `terrassenart` und `spannweite` (Plätze 20 und 21, fehlend = Vorgabe). Jede Wahl ist ein Schritt für Rückgängig/Wiederherstellen.
- **Vorgabehöhen** wie im alten Planer: normal 8,6 cm, Hochterrasse 54,2 cm, vorhandene UK 14,2 cm (gemessen von Oberkante Belag bis Boden). Die Höhenpunkte (3.2, M6-02) beginnen mit der Vorgabehöhe der gewählten Art.
- **Folgeschritte:** Bei Hochterrasse und vorhandener UK entfällt 3.6 „Art der Terrassennutzung“ (F28, F29); die übrigen Unterpunkte werden lückenlos weiter nummeriert (3.6 Querstreben, 3.7 Nutzung privat oder gewerblich). Bei vorhandener UK erscheint das Feld „Spannweite der Unterkonstruktion“ in cm (Vorgabe 80 cm, 10–300 cm, Enter übernimmt); es bleibt beim Wechsel der Art erhalten.
- Die neue UK wird bei vorhandener UK auf die vorhandene gebaut – UK-Holz und Bodenanker bleiben (R-C06). Doppelte UK, Stützen und Bodenanker der Hochterrasse rechnen M6-05, M6-08 und M6-10.

## 3.2 Höhenpunkte (mit Hilfe-Symbol)

- **ohne Gefälle**: ein Feld „Alle: … cm“ (Vorgabe siehe 3.1).
- **mit Gefälle**: je Eckpunkt ein Feld (A, B, C, D …), dazu „Weiteren Höhenreferenzpunkt Einplanen“.
- Die Höhe bestimmt das Auflager je Stützpunkt. Beispiel A = B = 15 cm, C = D = 8,6 cm (Untergrund Bitumen): neu Justierkeile 14–22 mm und 18–32 mm, GUMO-Unterleger 5 mm, ROBI-LIFT-Terrassenfüße 35–55 mm und 55–95 mm; KOPPLEX-3 entfällt → 2.751,08 €.

Neuer Planer (M6-02):

- Unterpunkt 3.2 mit „ohne Gefälle“ (Vorgabe, ein Feld „Alle“) und „mit Gefälle“ (je Eckpunkt A, B … ein Feld, ein Punkt je Ecke wie beim Ausgangspunkt, der Kreis hat nur A), Eingabe in cm (Enter übernimmt, über 0 bis 300 cm), Hinweis „Gemessen von Oberkante Belag bis Boden“. Planungsstand-Felder `gefaelle`, `hoehe` (fehlt = Vorgabehöhe der Art) und `eckhoehen` (Plätze 22–24); fehlt ein Eckpunkt, gilt „Alle“. Ein Wechsel der Art setzt die Höhen wie im alten Planer auf ihre Vorgabehöhe zurück; die Eckhöhen bleiben beim Ausschalten des Gefälles für später erhalten. Jede Eingabe ist ein Schritt für Rückgängig/Wiederherstellen.
- **Aufbauhöhe** (Server, `pruefeHoehen`): Dielenstärke plus UK hochkant (größere Seite), bei der Hochterrasse zwei Lagen (Lattenkreuz). Liegt ein Höhenpunkt darunter, wird die UK **gedreht** – die kleinere Seite steht, Breite und Stärke sind tauschbar (B-034) – und unter 3.2 erscheint der Hinweis. Liegt er auch unter dieser **Mindesthöhe**, wird er auf sie korrigiert: „Der Höhenreferenzpunkt unterschreitet die minimale Höhe von … cm. Er wurde korrigiert.“ Beispiel: Belag 23 mm, UK 40 × 60 mm → Aufbauhöhe 8,3 cm, gedreht 6,3 cm.
- Geprüft wird mit der gewählten UK (3.3, M6-03; Vorgabe die erste passende Robinien-UK der Serie des Belags). Ohne Belag, Dielenstärke oder UK-Maße bleiben die Höhen ungeprüft. Auflager (Pads, Stelzfüße) zählen nicht zur Mindesthöhe; ihre Höhen und Grenzen folgen mit M6-08/M6-11.
- **Annahme vorhandene UK:** Die vorhandene UK gehört nicht zur geplanten Konstruktion; die Mindesthöhe ist wie bei der normalen Terrasse Belag plus eine Lage der neuen UK. Der alte Planer korrigiert schon unter 14,2 cm (seine Vorgabehöhe) – das hängt nicht an der gewählten UK und wird nicht übernommen.
- Abnahme: In allen 18 Referenzfällen mit Höhen in den Planungsunterlagen bleiben die Höhen je Eckpunkt unverändert (keine Korrektur, z. B. 6,3 cm mit 100 × 22 mm und UK 40 × 40 mm); F30 (A = B = 15, C = D = 8,6 cm) mit UK hochkant.
- „Weiteren Höhenreferenzpunkt einplanen“ folgt mit M7-04 (Abläufe/Höhenreferenzpunkte) als eigenes Feld.

## 3.3 Unterkonstruktion auswählen

- Anzeige: „Unterkonstruktionsholz Robinie 40 x 60 mm, keilgezinkt“, „Maße: 600 x 4 x 6cm“, Knopf „Produktauswahl“.
- Dialog „Unterkonstruktion auswählen“ (ohne Filter): Robinie 40 × 60, 45 × 60, 40 × 40 (6000 mm); Alu-Systeme in den Größen S/M/L/XL (45 × 15 bis 45 × 85, blank/schwarz, 4000 mm); Alu-Schienen 56 × 40 und 56 × 27 (2000 mm). Nur Referenz (B-122).

Neuer Planer (M6-03):

- Unterpunkt 3.3 zeigt die gewählte UK mit Bild, Name und Maßen und den Knopf „Produktauswahl“; der Dialog „Unterkonstruktion auswählen“ zeigt wie beim Belag (2.1) Produktkarten mit Abmessungen, Preis je lfm (nur Anzeige, B-055) und Infobox, ohne Filter wie im alten Planer. Die Auswahl liefert der Artikeldienst (`unterkonstruktion.auswahl`, Argument der Belag) – die App hält nichts vor und lädt bei jedem Belagwechsel neu.
- **Nur zum Belag passende UK** (Abnahme, `ukPasstZuBelag`): UK-Holz Robinie derselben Holzart und Serie wie der Belag, dessen Format zur Serie gehört – Breite und Stärke tauschbar (R-A08, B-034), bei ECO SELECT auch die nur ungetrocknet lieferbaren Formate (B-212), die entfallenen nicht. Alu-Schienen und -Systeme stehen nicht zur Wahl (Sortiment nur Robinie, B-122); UK ohne Maße in den Artikeldaten auch nicht. Reihenfolge wie in den Artikeldaten, die erste ist die Vorgabe. Planungsstand-Feld `unterkonstruktion` (Platz 25, fehlt = Vorgabe); passt die gewählte UK nach einem Belagwechsel nicht mehr, gilt die Vorgabe des neuen Belags, die Wahl bleibt gespeichert.
- Die gewählte UK prüft die Höhenpunkte (3.2): Aufbauhöhe und Drehung richten sich nach ihren Maßen.
- Ohne Belag aus Robinie (z. B. MASSIV-Systemdielen, solange es keine MASSIV-UK in den Artikeldaten gibt) erscheint „Zum gewählten Belag passt keine Unterkonstruktion aus dem Sortiment.“

## 3.4 Länge der Unterkonstruktion

Auswahl, im Test nur „600 cm“. Die Materialliste verwendet trotzdem Stücke von 3000–5500 mm.

Neuer Planer (M6-03):

- Unterpunkt 3.4 mit „Automatisch“ (Vorgabe) und den Lieferlängen der gewählten UK als Chips; Planungsstand-Feld `ukLaenge` (Platz 26, fehlt = automatisch). Eine gewählte Länge, die die UK nicht liefert (etwa nach einem UK-Wechsel), gilt als automatisch.
- **Lieferlängen** (`ukLieferlaengen`): die Länge der Artikeldaten (die Upload-Datei führt je UK nur 6000 mm) und die Lieferlängen ihrer Serie (R-A06, B-035: 4/5/6 m, ECO SELECT bis 7 m). Damit ist der Fehler des alten Planers behoben, der nur 600 cm anbot, aber mit anderen Längen rechnete ([09](09-nicht-teil-der-kopie.md)).
- **Automatik** wie bei den Dielen (R-B10, `lieferlaengenFuer`): je UK-Linie die kürzeste Länge, die sie abdeckt, längere gestückelt. Gerechnet wird das mit der UK-Verlegung (M6-10); bis dahin rechnet die Befestigung (M5-09) weiter mit gleichmäßigen UK-Linien im UK-Abstand.

## 3.5 Auf welchem Untergrund wird die Terrasse aufgebaut?

Schotter (verdichtet) (Vorgabe) | Beton | Bitumenabdichtung. **Nur Information für die Planer** (richtige Unterbauhinweise an den Kunden) – keine Wirkung auf die Berechnung.

Neuer Planer (M6-04):

- Unterpunkt 3.5 mit der Frage „Auf welchem Untergrund wird die Terrasse aufgebaut?“ und den drei Untergründen als Chips (Vorgabe Schotter, F01) sowie dem Hinweis, dass der Untergrund die Materialliste nicht ändert. Planungsstand-Feld `untergrund` (Platz 80, fehlt = Schotter); jede Wahl ist ein Schritt für Rückgängig/Wiederherstellen.
- **Keine Wirkung auf die Berechnung** (R-C07, Antwort 6): Das Abnahmekriterium „Auswirkung auf Auflagen/Zubehör wie im alten Planer“ ist damit erfüllt, dass es keine gibt – die Referenzkonfigurationen haben keine Untergrund-Varianten (laut Alexander nur Information). Der Untergrund wird gespeichert, damit die Planer ihn in der Anfrage sehen.

## 3.6 Art der Terrassennutzung

| Art | Volumen | Summe | Unterschied zur Materialliste |
|---|---|---|---|
| schwimmende Verlegung (Vorgabe) | 0,435 m³ | 2.066,57 € | – |
| Versteifung ohne Rahmen | 0,454 m³ | 2.144,89 € | mehr UK-Holz 4000 mm |
| Rahmen | 0,459 m³ | 2.164,47 € | + UK-Holz 5000 mm |
| Versteifung mit Rahmen | 0,478 m³ | 2.242,79 € | + UK-Holz 5000 und 3000 mm |
| doppelte Unterkonstruktion | 0,543 m³ | 2.973,42 € | UK-Holz 5000 mm, Bodenanker, mehr KOPPLEX-1, kein KOPPLEX-3 |

Neuer Planer (M6-05):

- Unterpunkt 3.6 mit den fünf Arten als Chips (Vorgabe schwimmende Verlegung wie F01; im Issue steht „Rahmen (Standard)“, die Referenzkonfigurationen zeigen aber schwimmend als Vorgabe). Planungsstand-Feld `nutzungsart` (Platz 81, fehlt = schwimmend); jede Wahl ist ein Schritt für Rückgängig/Wiederherstellen. Bei Hochterrasse und vorhandener UK entfällt der Unterpunkt (M6-01); die Wahl bleibt gespeichert, gilt dort aber nicht (`wirksameNutzungsart`).
- **Warnung zur Verwindung** bei schwimmender Verlegung: „Achtung: Ohne Bodenbefestigung kann sich eine schwimmend verlegte Unterkonstruktion verwinden. Eine Versteifung oder ein Rahmen hält sie in Form.“ (Annahme: nur bei schwimmend – die anderen Arten sind versteift, gerahmt oder mit Bodenankern verbunden.)
- **Zusätzliches UK-Holz** (`ukZusatz`, Server) zu den UK-Linien quer zu den Dielen (Lage wie bei der Befestigung; die eigentliche UK-Verlegung rechnet M6-10). Es steht in der Materialliste (UK je Lieferlänge, alle Flächen mal Häufigkeit) und in der Stückliste der bearbeiteten Fläche:
  - **Rahmen:** je Kante, die nicht parallel zu den UK-Linien läuft, ein Rahmenholz in ihrer Länge. F32: 2 × 480 cm → **2 × 5000 mm wie im alten Planer**.
  - **Zweite Lage** (doppelte UK, ebenso immer bei der Hochterrasse): Hölzer parallel zu den Dielen im UK-Achsabstand. F34/F28: 9 × 480 cm → **9 × 5000 mm wie im alten Planer**. Die Höhenprüfung (M6-02) rechnet dann mit zwei Lagen: Bei F34 (8,6 cm) wird der Höhenpunkt auf 10,1 cm (21 mm + 2 × 40 mm) korrigiert – der alte Planer prüfte das nicht (Fehler, nicht übernommen).
  - **Versteifung** (Leiterverband, R-C03): Querstreben zwischen benachbarten UK-Linien in Reihen höchstens 120 cm auseinander (Annahme, Planungsregel `versteifungsAbstand`: der alte Planer setzt bei 309 cm zwei Reihen; der Querstreben-Abstand von 60 cm gilt für die zusätzlichen Querstreben 3.7). Strebe = lichter Abstand der UK (Achsabstand minus schmale Seite der hochkant stehenden UK). F31: 2 Reihen × 12 Streben à 36 cm = 8,64 m → 1 × 6000 + 1 × 4000 mm; der alte Planer lieferte 2 × 4000 mm (8 m) – darin passen nur 22 solche Streben, der neue Planer rechnet die Stücke aus (R-B11). F33 (mit Rahmen): 2 × 5000 + 6000 + 4000 mm statt 3 × 5000 + 3000 mm (3000 mm gibt es nicht mehr, B-035).
  - **Lieferstücke** (`lieferstuecke`): lange Stücke (ab der halben kürzesten Lieferlänge) wie eine Dielenreihe (R-B10), kurze aus gemeinsamen Hölzern mit möglichst wenig Rest; eine erzwungene UK-Länge (3.4) gilt auch hier. Stückliste: Rahmen und zweite Lage blau bzw. rot, Querstreben grün (Querstück, M9-04).
- **Nicht hier:** Bodenanker, ROBI-LIFT und Gummiband der doppelten UK (F34) folgen mit den Auflagern (M6-08/M6-11); UK-Holz und Stützen der UK-Linien selbst mit M6-10. Der UK-Abstand bleibt bei gewerblicher Nutzung gleich (R-C09).
- Benchmark `domain.Ukzusatz.ukZusatz`: große Freiform 12 × 8 m, Versteifung mit Rahmen und doppelte UK, waagrecht und 45° ≈ 1,8–2,1 ms (lokal, unter Last).

## 3.7 Querstreben

„Möchten Sie zusätzliche Querstreben hinzufügen?“ – „Querstreben Hinzufügen“ startet einen Bearbeitungsmodus („Änderungen übernehmen (ESC)“). Wie Querstreben in der Zeichnung gesetzt werden, ließ sich nicht ermitteln. Fachlich: Querstreben kommen als **Leiterverband zwischen die UK-Hölzer** und versteifen die Unterkonstruktion.

Neuer Planer (M6-06):

- Unterpunkt 3.7 (bei Hochterrasse und vorhandener UK 3.6) mit „Möchten Sie zusätzliche Querstreben hinzufügen?“ und Nein (Vorgabe) / Ja statt des Bearbeitungsmodus des alten Planers, der nicht funktionierte ([09](09-nicht-teil-der-kopie.md)). Mit Ja: Hinweis zum Leiterverband, „Automatisch“ und das Feld „Anzahl der Quertraversen“ (ganze Zahl 1–99, Enter übernimmt; Platzhalter die wirksame Anzahl vom Server). Planungsstand-Felder `querstreben` (Platz 82) und `querstrebenReihen` (Platz 83, fehlt = automatisch); die Anzahl bleibt beim Abwählen erhalten. Jede Eingabe ist ein Schritt für Rückgängig/Wiederherstellen.
- **Automatisch:** Reihen höchstens 60 cm auseinander (R-C03, `querstrebenAbstand`), mindestens eine – F01 (309 cm): 5 Reihen à 12 Streben zu 36 cm = 21,6 m → 3 × 6000 + 1 × 5000 mm. Die Querstreben ersetzen die Reihen der Versteifung (3.6) und gelten bei jeder Art der Terrasse.
- **Mengen und Zeichnung passen sich an:** Die Streben gehen wie in M6-05 in Material- und Stückliste (grün, Querstück) und kommen als Linien zur App (Berechnung Platz 90, wirksame Anzahl Platz 91); die Zeichnung zeigt sie grün über dem Belag, solange die Ebene UK eingeschaltet ist.
- Einzelne Streben von Hand setzen oder entfernen gehört zu M6-12 (UK von Hand anpassen).

## 3.8 Nutzung privat oder gewerblich

private Nutzung (Vorgabe) | gewerbliche Nutzung. Gewerblich: mehr Auflager (KOPPLEX-3 59,42 → 89,13 €), Summe 2.096,28 €.

Neuer Planer (M6-07):

- Unterpunkt 3.8 (bei Hochterrasse und vorhandener UK 3.7) mit privater (Vorgabe, F01) und gewerblicher Nutzung als Chips. Planungsstand-Feld `gewerblich` (Platz 84, fehlt = privat); jede Wahl ist ein Schritt für Rückgängig/Wiederherstellen.
- **Stellfußauswahl folgt dem Regelwerk** (Abnahme): Der Server liefert die Stellfüße, auf die die gewählte UK in den Artikeldaten verweist – Spalte „möglicher Stellfuß privat“ bzw. „gewerblich“, in Datenreihenfolge (`Regelwerk.stellfuesse`, Berechnung Platz 92). Die App zeigt sie unter „Passende Stellfüße:“; ohne UK oder ohne Verweise: „Für die gewählte Unterkonstruktion sind keine Stellfüße hinterlegt.“ Nichts ist im Code fest verdrahtet (B-122: die Artikeldaten sind die Quelle).
- **Belastung:** Wie im alten Planer ändert gewerbliche Nutzung den UK-Abstand nicht, sondern nur die Menge Gummiband unter der UK (F35: KOPPLEX-3 2 → 3 Rollen, R-C09); „UK zwingend versteift, nur PREMIUM SELECT“ ist zurückgestellt. Die Mengen der Auflager und Pads (samt diesem Zuschlag) und welcher Stellfuß in welcher Höhe gesetzt wird, rechnen M6-08/M6-11; bis dahin bringt die gewerbliche Nutzung nur die Stellfußauswahl.

## 3.9 Auflagen: Stelzfüße und Pads

Im alten Planer keine eigene Eingabe: Er legt unter die UK Gummi (F01: KOPPLEX-3, gewerblich mehr, F35), bei Gefälle Justierkeile, Unterleger und Terrassenfüße je nach Höhe (F30), bei Hochterrasse und vorhandener UK Bodenanker (F28: 91, F29: 65). Die neue Planer-Version bietet „Stelzlager/Pads“ und einen maximalen Stelzfußabstand.

Neuer Planer (M6-08):

- Unterpunkt 3.9 (bei Hochterrasse und vorhandener UK 3.8) „Auflagen“ mit „Mit Stelzfüßen“ und „Mit Stelzfüßen und Pads“ (Vorgabe, weil der alte Planer in F01 Gummi unter die UK legt) als Chips. Planungsstand-Feld `auflagen` (Platz 100, fehlt = Stelzfüße und Pads); jede Wahl ist ein Schritt für Rückgängig/Wiederherstellen.
- **Abstände aus dem Regelwerk** (Abnahme, `auflagerabstand`): höchstens der Abstand der Stelzfüße der gewählten UK laut Artikeldaten (Spalte `Abstand_Stelzfuesse`, Robinien-UK 60 cm, 40 × 40 mm 50 cm), ohne Angabe 60 cm (`auflagerAbstandVorgabe`; damit stehen in F28 13 × 7 = 91 Auflager wie die 91 Bodenanker des alten Planers). Bei vorhandener UK ist es die Spannweite (F29: 13 × 5 = 65). **Annahme gewerblich:** zwei Drittel des Abstands, also anderthalbmal so viele Auflager – wie im alten Planer, der gewerblich anderthalbmal so viel Gummi unter die UK legt (F35: 2 → 3 Rollen, R-C09); der UK-Achsabstand bleibt.
- **Höhenbereiche** (`auflagerbereiche`): die Stellfüße der Nutzung (privat/gewerblich, M6-07) und mit Pads die Unterlegpads der UK (Spalte „mögliche Unterlegpads“, nur Artikel der Art Pad), je mit Min-/Max-Höhe aus den Artikeldaten; Artikel ohne Höhenangabe zählen nicht. Gleiche Bereiche in verschiedenen Packungen (Terrassenfuß 35–55 mm zu 10, 30, 125 Stück) sind ein Bereich – die Packungen wählt die Materialliste (M6-11, `verpackt`). Die App zeigt Abstand, Bereiche und die mögliche Höhe von Oberkante Belag bis Boden (Aufbauhöhe aus 3.2 plus kleinster bzw. größter Bereich).
- **Wahl je Spalt** (`auflagerFuer`, rechnet M6-11 je Auflager): zuerst das dünnste Pad, das reicht (F30: Spalt 4 mm → Unterleger 5 mm wie im alten Planer; liegt die UK genau auf Höhe, das dünnste Pad), sonst der erste Stelzfuß in Datenreihenfolge, dessen Bereich den Spalt enthält, in einer Lücke zwischen zwei Bereichen der nächstgelegene.
- **Höhengrenzen mit Meldung** (Abnahme, `auflagermeldungen`): „Ein Höhenpunkt liegt unter der Mindesthöhe von … cm mit Stelzfüßen …“ (nur ohne Pads: der niedrigste Fuß, z. B. Justierkeil 14 mm, passt nicht unter die UK) und „… über der Höchsthöhe von … cm …“ (über dem höchsten Fuß, z. B. 200 mm: dann Hochterrasse). Geprüft werden die Höhenpunkte; dazwischen ist die Höhe linear (M6-11), die Grenzen liegen also an den Eckpunkten.
- Bei Hochterrasse und vorhandener UK gibt es keine Stelzfüße: Hinweis auf Stützen aus UK-Holz mit Bodenankern bzw. Bodenanker auf den vorhandenen Trägern (Mengen M6-11).
- Berechnung Platz 110 (`Unterbau`): Abstand, Bereiche, mögliche Höhe und Meldungen.

## 3.10 Maximale Feldbreite

Im alten Planer nicht einstellbar (er rechnet mit 40 cm UK-Achsabstand); die neue Planer-Version bietet eine Feldbreite von 40, 50 oder 60 cm. Firmenregel M1-04: UK-Achsabstand höchstens 40 cm, sicherer unter 35 cm (R-C01, Antwort 4).

Neuer Planer (M6-09):

- Unterpunkt 3.10 (bei Hochterrasse und vorhandener UK 3.9) „Maximale Feldbreite“ mit „Automatisch“ (Vorgabe) und den Feldbreiten, die der Server für den Belag erlaubt, als Chips; Hinweis „Höchster Abstand der UK-Hölzer (Achsabstand). Firmenregel: höchstens 40 cm, sicherer unter 35 cm.“ Planungsstand-Feld `feldbreite` (Platz 101, fehlt = automatisch, 10–100 cm); jede Wahl ist ein Schritt für Rückgängig/Wiederherstellen. Ohne Belag aus Holz: „Die Feldbreite hängt vom Belag ab …“.
- **Regel aus M1-04 umgesetzt** (Abnahme): Zur Wahl stehen 30, 35, 40, 50 und 60 cm (`feldbreitenAuswahl`: die der neuen Planer-Version und die sichereren unter 35 cm), aber nur bis zur höchsten Feldbreite des Belags (`hoechsteFeldbreite`: UK-Abstand des Belags laut Artikeldaten, höchstens der der Holzart, Robinie 40 cm). Für Robinie also 30, 35 und 40 cm; 50 und 60 cm verbietet die Firmenregel. Eine gespeicherte breitere Wahl (etwa aus einer anderen Holzart) gilt nicht: gerechnet wird mit der höchsten, die App meldet „Die gewählte Feldbreite überschreitet die Firmenregel; gerechnet wird mit 40 cm.“
- **Wirkung** (`wirksameFeldbreite`): Sie ist der UK-Achsabstand für die Befestigungspunkte (M5-09), das zusätzliche UK-Holz der Nutzungsart (M6-05: zweite Lage, Leiterverband) und die UK-Verlegung (M6-10). F01 mit 30 cm: 17 statt 13 UK-Linien (624 → 816 Befestigungspunkte), doppelte UK 12 statt 9 Hölzer in der zweiten Lage.
- Berechnung (Unterbau, Plätze 5–7): wählbare Feldbreiten, wirksame Feldbreite, ob begrenzt.
