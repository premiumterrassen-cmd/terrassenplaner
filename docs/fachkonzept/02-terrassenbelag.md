# 02 Terrassenbelag

Messwerte in diesem Kapitel: Rechteck 480 × 309 cm, Diele 60 × 22 genutet, sonst Vorgaben.

## 2.1 Terrassenbelag auswählen

- Anzeige des gewählten Belags: Bild, Name, „Maße: 600 x 6 x 2.2 cm“, „Fuge: 0.5 mm“ (richtig: **5 mm** – Anzeigefehler im alten Planer), Knopf „Produktauswahl“.
- Vorgabe: Terrassendiele Robinie 60 × 22 mm, genutet, keilgezinkt, bombiert.
- Dialog „Terrassenbelag auswählen“:
  - Kategorien als Bildknöpfe: **Unsichtbar befestigt** (genutet) | **Sichtbar befestigt** (glattkant) | **Holzfliese**.
  - Filter mit Mehrfachauswahl: Artikelbezeichnung, Länge, Breite, Stärke.
  - Produktkarten: Bildkarussell, Titel, Beschreibung, „Abmessungen: 6000 x 60 x 22 mm“, „Preis per lfm: … € inkl. MwSt“.
  - Ein Klick auf eine Karte wählt den Belag; „Zurück Zur Konfiguration“ schließt den Dialog.
- Sortiment des Altsystems (nur Referenz, neu gilt die Master-Artikelliste, B-122/B-030 ff.):
  - genutet und glattkant: Querschnitte 50/60/80/100 × 22, 23, 26 mm, teils „bombiert“, alle 6000 mm lang.
  - Holzfliese: Terrassenfliese Robinie 606 × 606 mm (natur / vorgeölt).

Neuer Planer (Alexander, 29.10.2026, M5-01):

- Vorgabe ist der erste Belag der Upload-Datei; die Reihenfolge steuert die Master-Artikelliste.
- Preis je m² = Preis je lfm ÷ (Breite + Fuge 5 mm).
- Filter: Material (Serie), Oberseite, Breite, Stärke, Länge, dazu Suche in Titel und Artikelnummer. Einen Filter Farbe gibt es erst mit Kastanie oder vorgeölten Varianten.

## 2.2 Soll die Dielenlänge automatisch ermittelt werden?

- **Ja** (Vorgabe): der Planer sucht die passende Lieferlänge automatisch aus (Materialliste z. B. 5000 mm).
- **Nein** dient dazu, eine bestimmte Länge zu erzwingen, z. B. weil nur diese am Lager ist.
- **Nein**: „Mögliche Originallängen (in cm):“ Einzelauswahl 300, 400, 450, 500, 550, 600.
  - Beispiel 400: Stoßfuge bei 400 cm, Reststück 80 cm → Verschnitt 0,99 %, Volumen 0,434 m³ (automatisch: 4 %, 0,435 m³).

Neuer Planer (M5-02):

- **Automatik** je Dielenreihe: die kürzeste Lieferlänge des Belags, die die Reihe abdeckt (480 cm → 5000 mm, 309 cm → 4000 mm). Reihen über der längsten Lieferlänge beginnen mit dieser, der Rest bekommt wieder die kürzeste passende (800 cm → 6000 + 4000 mm). Das entspricht den Referenzfällen; wo der alte Planer 3,0/4,5/5,5 m nahm, gilt die nächstgrößere Lieferlänge (R-A06, 440 cm → 5000 statt 4500 mm).
- **Nein:** Einzelauswahl aus den Längen des gewählten Belags (nicht mehr die feste Liste 300–600 cm); vorbelegt ist die längste. Liefert ein neu gewählter Belag die Länge nicht, gilt wieder die Automatik.
- Die Frage gibt es nur bei Dielen mit mehreren Lieferlängen, nicht bei Holzfliesen und dem Längenmix der Systemdielen.
- Reststücke auf mehrere Reihen verteilen (z. B. eine 4000-mm-Diele für zwei Reihen mit je 200 cm Rest) gehört zur Verlegung (M5-08).

## 2.3 Verlegearten

| Verlegeart (Tooltip) | Volumen |
|---|---|
| Fugenschnitt (Vorgabe, alle Stöße in einer Linie) | 0,435 m³ |
| Halbverband | 0,445 m³ |
| Drittelverband | 0,454 m³ |
| Wechselverband | – |

„Sollen kurze Dielenstücke miteinander verbunden werden?“ Ja | Nein (Vorgabe Nein).

Neuer Planer (M5-03):

- Die Frage steht unter 2.3 „Verlegearten“; Planungsstand-Feld `kurzeStueckeVerbinden`, Vorgabe Nein.
- **Nein:** Jede Reihe wird an allen Stoßlinien der Verlegeart geschnitten.
- **Ja** (R-B12): Ein Endstück der Reihe wird mit seinem Nachbarstück zu einer ganzen Diele verbunden, wenn beide zusammen in die längste erlaubte Länge passen (bei erzwungener Länge diese). Der Stoß ist dort nicht mehr durchgehend, das kurze Reststück entfällt (z. B. Reihe 380–800 cm, Stoßlinie 400 cm: 420 cm statt 20 + 400 cm).
- Beim Rechteck liegen die Stöße eine ganze Lieferlänge auseinander; dort wirkt die Option nie (F13).
- Die Stoßlinien liefert die Verlegeart (M5-04), die Stücke je Reihe gehen in die Verlegung und den Verschnitt (M5-08) ein.

Neuer Planer (M5-04):

- Auswahl unter 2.3 vor der Frage nach kurzen Stücken; Planungsstand-Feld `verlegeart`, Vorgabe Fugenschnitt. Der Hinweis zur Verlegeart steht im Tooltip („Auf Fuge geschnitten: alle Stöße in einer Linie“).
- Die Stoßlinien laufen quer zur Verlegerichtung über die ganze Fläche. Ihr **Raster** ist die längste erlaubte Lieferlänge (bei erzwungener Länge diese), höchstens aber die Ausdehnung der Fläche in Verlegerichtung.
- **Fugenschnitt:** in jeder Reihe dieselben Stöße im Raster vom Ausgangspunkt aus.
- **Halbverband:** jede zweite Reihe um ein halbes Raster versetzt.
- **Drittelverband:** Reihe für Reihe um ein Drittel versetzt (0, ⅓, ⅔).
- **Wechselverband:** jede zweite Reihe im Raster von der Gegenseite aus.
- Abgleich mit den Zuschnittlisten des alten Planers (48 Reihen, Diele 60 mm): 480 cm Halbverband 24 × 240 + 240 und 24 × 480 cm (F06), Drittelverband 32 × 160 + 320 und 16 × 480 cm (F07), Wechselverband = Fugenschnitt (F08); 800 cm mit 6-m-Dielen Fugenschnitt 600 + 200 cm (F09), Halbverband im Wechsel 600 + 200 und 300 + 500 cm (F10), Drittelverband 600 + 200, 200 + 600 und 400 + 400 cm (F11), Wechselverband 600 + 200 und 200 + 600 cm (F12); fest 400 cm: 400 + 400 cm (F13).
- Der Ausgangspunkt (M5-07) verschiebt den Anfang des Rasters; Richtungen siehe 2.4 (M5-05).

## 2.4 Verlegerichtungen

| Richtung | Verschnitt | Volumen |
|---|---|---|
| waagrecht (Vorgabe) | 4 % | 0,435 m³ |
| senkrecht | 22,75 % | 0,499 m³ |
| 135 Grad | 0,32 % | 0,462 m³ |
| 45 Grad | 2,2 % | 0,457 m³ |
| Individueller Verlegewinkel (Feld „Winkel“) | – | – |

Bei diagonaler Verlegung zeigt die Zeichnung eine durchgehende Stoßlinie über die Fläche.

Neuer Planer (M5-05):

- Auswahl unter 2.4 mit fünf Richtungen; beim individuellen Winkel erscheint das Feld „Winkel in Grad“ (ganze Grad 0–179, Vorgabe 30 wie F05, Enter übernimmt). Planungsstand-Felder `verlegerichtung` und `verlegewinkel`; der Winkel bleibt beim Wechsel auf eine feste Richtung erhalten.
- Winkel gegen den Uhrzeigersinn zur Kante A–B: waagrecht 0°, senkrecht 90°, 45°, 135°, individuell. 45° und 30° laufen von A über B hinaus nach oben, 135° von A nach links oben.
- **Reihen:** Streifen aus Dielenbreite plus Fuge, ab dem Ausgangspunkt nach beiden Seiten. Was von der Fläche in einem Streifen liegt, ist eine Dielenreihe vom ersten bis zum letzten Punkt in Verlegerichtung – die Diele muss die längere Kante abdecken (45°: 309 cm ÷ sin 45° + 6,5 cm = 443,5 cm). Zerfällt die Fläche in einem Streifen in mehrere Teile (U-Form, Ausschnitte), ist jeder Teil eine eigene Reihe.
- **Stoßlinien** im Raster der Verlegeart ab dem Ausgangspunkt, auch zur anderen Seite hin: Bei 135° liegt A mitten in der Ausdehnung, eine Stoßlinie läuft durch A und teilt die Reihen (F04, 154 statt 86 Stücke). Der Wechselverband setzt jede zweite Reihe an der Gegenseite an.
- **Schmale Restreihen** unter 15 mm Breite entfallen: Der alte Planer lässt eine 14 mm breite Ecke bei 45° (F03) und 11 mm bei 30° (F05) weg, verlegt aber eine 18 mm breite Reihe (Referenzfall 2026-05-29-3162). Die genaue Grenze ist aus den Daten nicht bestimmbar.
- Abgleich: Die Stücklängen stimmen mit den Zuschnittlisten von F01–F13 auf 1 mm überein (senkrecht 74 × 309 cm, 45° 86 Stücke, 135° 154, 30° 78). Wie die Stücke auf Lieferlängen verteilt werden, gehört zur Verlegung (M5-08).
- Der Server verlegt mit dem gewählten Belag (Breite, längste oder erzwungene Länge) und liefert die Umrisse der Dielenstücke mit der Berechnung; die Zeichnung zeigt sie auf der Ebene „Belag“. Holzfliesen folgen mit M5-08.

## 2.5 Ausgangspunkt des Belags

- „Welcher Punkt soll der Ausgangspunkt des Terrassenbelages sein?“ – Auswahl eines Eckpunkts (Vorgabe A).
- „Verschieben Sie die erste ganze Diele mit dem Mauszeiger oder dem Eingabefeld nach:“ – „links/rechts um“ und „oben/unten um“ (cm), je mit Schieberegler.

Neuer Planer (M5-07):

- Auswahl der Ecke als Chips A, B, C … in derselben Zählung wie die Beschriftung der Zeichnung (`Grundriss.ecken`: Rechteck A–D, L/T/U/O und Freiform alle Eckpunkte). Der Kreis hat keine benannten Ecken und bietet nur A, den Anfang seiner Kontur. Bei einer gerundeten Ecke gilt der Schnittpunkt ihrer Kanten. Planungsstand-Felder `ausgangsecke` (Vorgabe 0 = A), `verschiebungX` und `verschiebungY` (mm); gibt es die Ecke nach einem Formwechsel nicht mehr, gilt wieder A.
- Verschoben wird in Bildschirmkoordinaten: „links/rechts um“ positiv nach rechts, „oben/unten um“ positiv nach unten, je Eingabefeld in cm (Enter übernimmt) und Schieberegler in ganzen cm. Mit der Maus zieht man den grünen Griff an der Ecke der ersten ganzen Diele (Ausgangspunkt plus Verschiebung), solange der Schritt Terrassenbelag offen ist. Jede Eingabe und jeder Zug ist ein Schritt für Rückgängig/Wiederherstellen.
- **Grenzen:** höchstens eine Belaglänge bzw. Belagbreite. Die Achse, die eher in Verlegerichtung liegt (Winkel bis 45° oder ab 135°), bekommt das Raster der Stöße (längste bzw. erzwungene Lieferlänge, höchstens die Ausdehnung der Fläche, siehe 2.3), die andere Dielenbreite plus Fuge. Der Server rechnet die Grenzen und begrenzt auch eine gespeicherte Verschiebung, die nach einem Belagwechsel zu groß ist.
- **Warnung:** Entsteht ein Dielenstück kürzer als 5 cm oder eine Randreihe schmaler als 5 cm (Reihen unter 15 mm entfallen weiter, siehe 2.4), meldet der Server das mit der Berechnung (`kurzeZuschnitte`), und unter 2.5 erscheint „Achtung: Es entstehen Zuschnitte unter 5 cm …“. Beispiel: 480 × 309 cm mit 6-cm-Dielen hat ab A eine 3,5 cm breite letzte Reihe; 5 cm nach unten verschoben bleiben oben und unten je 5 cm.
- Ohne verlegte Dielen (kein Belag, Holzfliesen bis M5-08) gibt es keine Verschiebung, nur die Wahl der Ecke.

## 2.6 Befestigungsart

Im alten Planer ergibt sich die Befestigung aus dem Belag: genutete Dielen mit CLIP-FIXX (Packungsmix VPE 250 + 100 + 50), dazu einseitig genutete Randdielen mit Terrassenschrauben 5,0 × 50 mm (je UK-Kreuzung eine); glattkante Dielen von oben verschraubt (F24: 806 Schrauben für 30 Reihen × 13 UK).

Neuer Planer (M5-09):

- Unterpunkt 2.6 „Befestigungsart“ mit den Arten, die zum Profil des Belags passen: **Mit Clips** nur bei genuteten Dielen (B-094), glattkante Dielen **direkt verschraubt** (Vorgabe) oder **verschraubt mit Abstandshaltern** (B-090). Planungsstand-Feld `befestigungsart` (Vorgabe Clips wie im alten Planer); gilt die gewählte Art für den Belag nicht, gilt die Vorgabe seines Profils, die Wahl bleibt aber für einen späteren Belagwechsel erhalten. Was wählbar ist und was gebraucht wird, rechnet der Server; die Oberfläche zeigt die Befestigungspunkte und die Artikel mit Anzahl.
- **Artikel** aus den Befestigungsverweisen des Belags in der Upload-Datei (B-122), Preise und Verkaufseinheiten unverändert (B-153): genutet unter 100 mm und genutete ECO SELECT/BASIC ab 100 mm **CLIP-FIXX**, genutete PREMIUM SELECT ab 100 mm **DUO-CLIP-FIXX** (B-094, B-150; R-B01). Die Clipschrauben sind im Lieferumfang und keine eigene Position (B-074). Glattkant: Terrassenschrauben in der kürzesten Länge, die mindestens die doppelte Dielenstärke hat (21–25 mm → 50 mm, 26 mm → 60 mm). Abstandshalter: der erste Artikel der Artikeldaten, dessen Titel mit „Abstandshalter“ beginnt – die Upload-Datei hat dafür noch keine Beziehung (offen).
- **Befestigungspunkte:** jede Kreuzung eines Dielenstücks mit einer UK-Linie. Bis die Unterkonstruktion gerechnet wird (M6), liegen die UK-Linien quer zur Verlegerichtung gleichmäßig über die Ausdehnung der Verlegung, höchstens im UK-Abstand des Belags (Artikeldaten 40 cm, höchstens 40 cm der Holzart, R-C01) auseinander, die äußeren am Rand (B-096). Jedes Stück liegt an beiden Enden auf – am Stoß zwei UK nebeneinander – und dazwischen auf jeder Linie, die es überdeckt. F01: 48 Reihen × 13 = 624 Punkte; F09 (800 cm, Stoß bei 600 cm): 48 × 22.
- **Mengen:** Clips je Punkt einer, dazu einer je Punkt der äußeren Reihe für deren freie Längskante (Anfangs- und Enddiele sind normale genutete Dielen, B-033) – F01: 637 Clips. Schrauben je Punkt eine, ab 100 mm Breite zwei (R-B02) – F24: 390 Punkte, 780 Schrauben. Abstandshalter je Punkt einer.
- **Verkaufseinheiten:** so wenig Überhang wie möglich, dann so wenig Packungen wie möglich: F01 637 Clips → 2 × VPE 250 + VPE 100 + VPE 50 (wie der alte Planer), 780 Schrauben → 4 × 200 Stück.
- **Abweichungen vom alten Planer** (Fehler nicht übernommen): keine einseitig genuteten Randdielen mit Terrassenschrauben (B-033) – die Randreihen bekommen Clips, daher F09 1100 statt 1050 Clips und keine 26/44 Terrassenschrauben bei genuteten Dielen; glattkant ohne die 26 zusätzlichen Schrauben aus F24 (806 → 780).
- Holzfliesen (Verbinder) folgen mit M5-08; die echten UK-Linien liefert M6.
