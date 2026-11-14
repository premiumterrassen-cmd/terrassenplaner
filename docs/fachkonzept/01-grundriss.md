# 01 Grundriss

## 1.1 Terrassenform auswählen

Sieben Formen als Bildknöpfe. Kennzahlen jeweils mit Vorgabebelag (Diele 60 × 22 genutet, waagrecht).

| Form | Vorgabemaße (cm) | Eingabefelder | Fläche | Verschnitt | Volumen |
|---|---|---|---|---|---|
| Rechteck (Start) | 480 × 309 | A — B, B — C | 14,832 m² | 4 % | 0,435 m³ |
| Rechteck (erneut gewählt) | 540 × 360 | A — B, B — C | 19,440 m² | 1,82 % | 0,570 m³ |
| L-Form | A—B 270, B—C 180, C—D 270, D—E 180, E—F 540, F—A 360 | A—B, B—C, C—D, D—E | 14,580 m² | 1,82 % | 0,407 m³ |
| T-Form | A—B 405, B—C 180, C—D 135, D—E 180, E—F 135, F—G 180, G—H 135, H—A 180 | B—C, C—D, D—E, E—F, G—H, H—A | 9,720 m² | 1,62 % | 0,269 m³ |
| O-Form | außen 540 × 360, Ausschnitt A1 240 × 180 mittig | A—B, B—C; Ausschnitt als eigener Block (1.4) | 19,440 m² | 1,98 % | 0,421 m³ |
| U-Form | A—B 135, B—C 90, C—D 135, D—E 90, E—F 135, F—G 270, G—H 405, H—A 270 | A—B, B—C, C—D, E—F, F—G, H—A | 9,720 m² | 4,3 % | 0,267 m³ |
| Kreis | Ø 360 (Maßlinie „ø 360 cm“) | Radius | 10,150 m² | 7,44 % | 0,340 m³ |
| Freiform | leeres Raster | siehe unten | – | – | – |

- Die Maßfelder zeigen nur Platzhalter („A — B: cm“); die aktuellen Maße stehen in der Zeichnung.
- Abhängige Maße ergeben sich aus den eingegebenen (z. B. L-Form: E—F = A—B + C—D).
- Kreisfläche wird als Vieleck gerechnet (10,150 m² statt π · 1,8² = 10,179 m²) – der neue Planer rechnet exakt π·r² (Alexander, 27.10.2026; siehe [09](09-nicht-teil-der-kopie.md)).
- Eine Kante ist rot markiert (Rechteck/O: D—C, L/T: Unterkante, erst nach Formwahl): die **letzte Dielenreihe, die längs auf Restbreite aufgeschnitten wird** (Alexander, 19.10.2026).
- **Neuer Planer – Plausibilität der Fläche** (Planungsregeln Alexander (Planungskern v6, 11.11.2026) Regel 1.7, R-D09): Fläche bis 0,05 m² → Fehler „Maße fehlen oder sind falsch“; über 1.000 m² → Fehler „unplausibel groß“; außerhalb 1–300 m² → Hinweis. Die Meldung steht unter den Maßen (Unterpunkt 1.2) und in den Hinweisen der Planungsunterlagen; die Fläche rechnet der Server, die Grenzen stehen im domain-Paket (`pruefeFlaeche`, `Berechnung.flaechenmeldung`). Die Grenzen der Seitenlängen (50 cm bis 300 m je Seite) bleiben daneben bestehen.

### Freiform

- Punkte per Klick ins Raster setzen; Hinweis „[x] zum Schließen der Form“.
- Maßeingabe umschaltbar **Strecke | Koordinaten**.
- Werkzeugleiste: Wiederholen, Rückgängig, Zentrieren, Zoom, Belag/UK/Maße, Hinweis „Punkte setzen“.
- Schalter „Einrastfunktion deaktivieren“ und „Zeichnungshilfe deaktivieren“, je mit Hilfe-Symbol (?).
- **Neuer Planer (#128, Alexander 04.11.2026): Punkte landen genau am Klickort.** Beide Hilfen wirken nur magnetisch, innerhalb von 8 Bildpunkten (bei jedem Zoom gleich): Zeichnungshilfe = Strahl in 15°-Schritten vom letzten Punkt, Länge dann auf volle 10 cm; Einrastfunktion = 10-cm-Rasterlinie je Achse, höchstens 2,5 cm. Vorher drehte die Zeichnungshilfe jeden Klick auf 15° (3 m rechts, 45 cm tiefer → rund 40 cm daneben).
- Vorschau beim Zeichnen: Linie vom letzten Punkt zur Maus, Zielkreis dort, wo der Punkt landen würde, Live-Maß „Länge cm · Winkel°“.

## 1.2 Terrassenmaße

Eingabefelder je Form (Tabelle oben), Einheit cm.

**Plausibilität (Planungsregeln Alexander (Planungskern v7, 11.11.2026) Regel 9.6, R-D23):** Ein Maß über 50 m wird nicht angewendet – vermutlich in mm eingegeben; das Feld bittet „Über 50 m – bitte das Maß in cm angeben“ (`groesstesEingabemass`). Daneben gelten die Grenzen der Seitenlängen 50–3000 cm weiter (Frage 18; 0 cm ist damit gesperrt). Kanten zwischen den Ecken unter 10 cm oder über 30 m – auch abgeleitete, z. B. bei der Freiform – erscheinen als Hinweis unter den Maßen und in den Hinweisen der Planungsunterlagen („Kante B–C ist nur 5,5 cm lang …“, `pruefeKanten`, `Berechnung.kantenwarnungen`). Gelbe Warnung „wirklich?“ ab 30 m bei der Eingabe: siehe Frage 50 in [10](10-offene-fragen.md).

## 1.3 Ecken und Seiten abrunden

- „Rundungen Hinzufügen“ öffnet einen Bearbeitungsmodus: Griffpunkte innen an jeder Ecke und auf jeder Seitenmitte.
- Ecke abrunden: Griff nach innen ziehen, der Zugweg bestimmt den Radius.
- Knöpfe werden zu „Rundungen Übernehmen“ und „Rundungen Zurücksetzen“; unten „Änderungen übernehmen (ESC)“.
- Beispiel 540 × 360 mit gerundeter Ecke A: Fläche 19,099 m², Verschnitt 2,56 %, Volumen 0,575 m³.
- **Neuer Planer – Bogen mit Radius je Seite** (Planungsregeln Alexander (Planungskern v12, 12.11.2026), Regel 14.1): Ist eine Seite gewählt, gibt es neben dem Stich (wie im alten Planer) das Feld **Radius** und den Haken **„innen“**; Radius leer bzw. „Rundung entfernen“ = gerade. Stich und Radius ersetzen sich je Seite (`Rundungen.mitRadius`, Transportformat Art 2 in den Dreiergruppen der Rundungen, negativ = innen – kein neuer Platz). Der Bogen liegt zwischen den Rundungen der Ecken; seine Richtung „außen“ ergibt sich aus dem Umlaufsinn der Ecken. Ein Radius unter der halben Seite ergibt einen **Halbkreis** mit Hinweis im Rundungsmodus (`zuKleineRadien`); ein Halbkreis ist mit Radius erlaubt, mit Stich weiter nur bis knapp darunter. Der Griff auf der Seite sitzt am Scheitel (`stichAn`); Ziehen macht aus dem Radius wieder einen Stich. Die Kontur führt Bögen über 180° ohne Teilung (die Wölbung ist eindeutig); die Teilung am Scheitel aus dem Kern ist dort nur technisch nötig. Plan: „Bogen ‹Länge› · R ‹Radius›“ statt der Sehne (R-E40). Ein Halbkreis an der Wand mit nur zwei Punkten geht nicht (Freiform ab 3 Punkten), siehe Frage 90.
- **Ecke abrunden** (Planungsregeln Alexander (Planungskern v15, 13.11.2026), Abschnitt 17, R-B60/R-B61, M10-01q): Je Ecke Radius in cm (leer = eckig) und Haken „innen (Hohlkehle um die Ecke)“. Die Planung kürzt beide Nachbarkanten um t = r / tan(θ/2) (bei 90° um r, bei 135° um 0,41 · r) und setzt einen tangentialen Bogen – konvex wird die Fläche kleiner, einspringend größer; „innen“ ist ein Bogen um die alte Ecke, die Kanten je um r gekürzt (`Rundungen.mitEcke(innen:)`, negativer Radius im bestehenden Rundungs-Vektor, kein neuer Platz). t = Kantenlänge ist erlaubt (der Nachbarpunkt wird Bogenanfang/-ende; zwei Ecken einer 4-m-Kante mit R 2 m = Halbkreis), darüber nicht – Meldung „Radius zu groß – an dieser Ecke höchstens … cm“ (`groessterRadius`). Nur Ecken mit zwei geraden Nachbarkanten, keine Ecken an der Hauswand (Griffe fehlen dort, eine neue Hauswand nimmt die Rundung ihrer Ecken weg, `eckeRundbar`); neben einer abgerundeten Ecke keine Seitengriffe – ihr Bogen ist keine eigene Seite. Die Buchstaben bleiben: der Bogenanfang behält den Buchstaben der Ecke, das Bogenende bekommt den nächsten freien (in der Reihenfolge der Abrundung), Aussparungen danach (Fachkonzept 08). Formänderung (17.6): gleiche Eckenzahl → Rundungen bleiben je Ecke/Seite; sonst behält eine neue Seite, deren Endpunkte auf einem bisherigen Bogen liegen, den Bogen (gleiche Seite: Stich, Teil des Bogens: dessen Radius), eine abgerundete Ecke am selben Ort ihre Rundung. Kurzanleitung als Hilfetext am Hinweis des Rundungsmodus (17.5 sinngemäß). Neu gegenüber M4-11: Eckrundung neben einer gewölbten Seite wird abgewiesen (Frage 133).

## 1.4 Ausschnitte und Teilflächen in der Fläche

„Weitere Flächen Hinzufügen“ legt einen Block „Ausschnitt A1“ an (weitere A2 …), ein- und ausklappbar.

| Feld | Inhalt |
|---|---|
| Form der Fläche | Rechteck, Dreieck, Sechseck, Kreis, Freiform |
| Ecken und Seiten abrunden | „Rundungen Hinzufügen“ |
| Koordinaten der Fläche | X, Y in cm – „Der Punkt A ist im Koordinatensystem (0\|0). Negative Werte sind möglich. Die Fläche kann mit der Maus verändert und verschoben werden.“ |
| Flächenmaße | Länge (Vorgabe 180 cm), Breite (Vorgabe 120 cm) |
| Funktion der Fläche | „leere Fläche“ (Vorgabe) oder „anderer Terrassenbelag“ |
| Inhalt der Fläche | nur bei leerer Fläche: sechs Füllungen (leer/weiß, Kies hell, Stein dunkel, Pool, Rasen, Erde) – nur Darstellung |
| Flächenbezeichnung | max. 10 Zeichen, Vorgabe „A1“ |

- Meldung, sobald der Ausschnitt über den Rand ragt: „Der Ausschnitt darf nicht außerhalb der Terrasse sein!“ (SCHLIESSEN).
- Wirkung am Beispiel 540 × 360 (Ecke A gerundet), Ausschnitt 180 × 120 bei X 200 / Y 100:
  - anderer Terrassenbelag: Fläche 19,099 m², Verschnitt 2,71 %, Volumen 0,577 m³.
  - leere Fläche: Fläche bleibt 19,099 m², Volumen sinkt auf 0,514 m³.
  - Die angezeigte Fläche ist also die Außenfläche; das Material wird ohne den leeren Ausschnitt berechnet.
