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
- Die UK für die Prüfung ist bis zur Auswahl (M6-03) die erste Robinien-UK der Serie des Belags. Ohne Belag, Dielenstärke oder UK-Maße bleiben die Höhen ungeprüft. Auflager (Pads, Stelzfüße) zählen nicht zur Mindesthöhe; ihre Höhen und Grenzen folgen mit M6-08/M6-11.
- **Annahme vorhandene UK:** Die vorhandene UK gehört nicht zur geplanten Konstruktion; die Mindesthöhe ist wie bei der normalen Terrasse Belag plus eine Lage der neuen UK. Der alte Planer korrigiert schon unter 14,2 cm (seine Vorgabehöhe) – das hängt nicht an der gewählten UK und wird nicht übernommen.
- Abnahme: In allen 18 Referenzfällen mit Höhen in den Planungsunterlagen bleiben die Höhen je Eckpunkt unverändert (keine Korrektur, z. B. 6,3 cm mit 100 × 22 mm und UK 40 × 40 mm); F30 (A = B = 15, C = D = 8,6 cm) mit UK hochkant.
- „Weiteren Höhenreferenzpunkt einplanen“ folgt mit M7-04 (Abläufe/Höhenreferenzpunkte) als eigenes Feld.

## 3.3 Unterkonstruktion auswählen

- Anzeige: „Unterkonstruktionsholz Robinie 40 x 60 mm, keilgezinkt“, „Maße: 600 x 4 x 6cm“, Knopf „Produktauswahl“.
- Dialog „Unterkonstruktion auswählen“ (ohne Filter): Robinie 40 × 60, 45 × 60, 40 × 40 (6000 mm); Alu-Systeme in den Größen S/M/L/XL (45 × 15 bis 45 × 85, blank/schwarz, 4000 mm); Alu-Schienen 56 × 40 und 56 × 27 (2000 mm). Nur Referenz (B-122).

## 3.4 Länge der Unterkonstruktion

Auswahl, im Test nur „600 cm“. Die Materialliste verwendet trotzdem Stücke von 3000–5500 mm.

## 3.5 Auf welchem Untergrund wird die Terrasse aufgebaut?

Schotter (verdichtet) (Vorgabe) | Beton | Bitumenabdichtung. **Nur Information für die Planer** (richtige Unterbauhinweise an den Kunden) – keine Wirkung auf die Berechnung.

## 3.6 Art der Terrassennutzung

| Art | Volumen | Summe | Unterschied zur Materialliste |
|---|---|---|---|
| schwimmende Verlegung (Vorgabe) | 0,435 m³ | 2.066,57 € | – |
| Versteifung ohne Rahmen | 0,454 m³ | 2.144,89 € | mehr UK-Holz 4000 mm |
| Rahmen | 0,459 m³ | 2.164,47 € | + UK-Holz 5000 mm |
| Versteifung mit Rahmen | 0,478 m³ | 2.242,79 € | + UK-Holz 5000 und 3000 mm |
| doppelte Unterkonstruktion | 0,543 m³ | 2.973,42 € | UK-Holz 5000 mm, Bodenanker, mehr KOPPLEX-1, kein KOPPLEX-3 |

## 3.7 Querstreben

„Möchten Sie zusätzliche Querstreben hinzufügen?“ – „Querstreben Hinzufügen“ startet einen Bearbeitungsmodus („Änderungen übernehmen (ESC)“). Wie Querstreben in der Zeichnung gesetzt werden, ließ sich nicht ermitteln. Fachlich: Querstreben kommen als **Leiterverband zwischen die UK-Hölzer** und versteifen die Unterkonstruktion.

## 3.8 Nutzung privat oder gewerblich

private Nutzung (Vorgabe) | gewerbliche Nutzung. Gewerblich: mehr Auflager (KOPPLEX-3 59,42 → 89,13 €), Summe 2.096,28 €.
