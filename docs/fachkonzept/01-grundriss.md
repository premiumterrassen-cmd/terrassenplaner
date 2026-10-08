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
- Kreisfläche wird als Vieleck gerechnet (10,150 m² statt π · 1,8² = 10,179 m²).
- Eine Seite ist rot markiert (Rechteck/O: D—C, L/T: Unterkante) – vermutlich die Hausseite (siehe [10 Offene Fragen](10-offene-fragen.md)).

### Freiform

- Punkte per Klick ins Raster setzen; Hinweis „[x] zum Schließen der Form“.
- Maßeingabe umschaltbar **Strecke | Koordinaten**.
- Werkzeugleiste: Wiederholen, Rückgängig, Zentrieren, Zoom, Belag/UK/Maße, Hinweis „Punkte setzen“.
- Schalter „Einrastfunktion deaktivieren“ und „Zeichnungshilfe deaktivieren“, je mit Hilfe-Symbol (?).

## 1.2 Terrassenmaße

Eingabefelder je Form (Tabelle oben), Einheit cm.

## 1.3 Ecken und Seiten abrunden

- „Rundungen Hinzufügen“ öffnet einen Bearbeitungsmodus: Griffpunkte innen an jeder Ecke und auf jeder Seitenmitte.
- Ecke abrunden: Griff nach innen ziehen, der Zugweg bestimmt den Radius.
- Knöpfe werden zu „Rundungen Übernehmen“ und „Rundungen Zurücksetzen“; unten „Änderungen übernehmen (ESC)“.
- Beispiel 540 × 360 mit gerundeter Ecke A: Fläche 19,099 m², Verschnitt 2,56 %, Volumen 0,575 m³.

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
