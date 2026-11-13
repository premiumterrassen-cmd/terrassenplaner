# 02 Terrassenbelag

Messwerte in diesem Kapitel: Rechteck 480 × 309 cm, Diele 60 × 22 genutet, sonst Vorgaben.

## 2.1 Terrassenbelag auswählen

- Anzeige des gewählten Belags: Bild, Name, „Maße: 600 x 6 x 2.2 cm“, „Fuge: 0.5 mm“ (gemeint 5 mm – Anzeigefehler im alten Planer; der neue Planer rechnet mit **6 mm**, R-B06, Planungskern v6, Entscheidung Alexander 11.11.2026), Knopf „Produktauswahl“.
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
- Preis je m² = Preis je lfm ÷ (Breite + Fuge 6 mm, R-B06).
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
- **Vorgabe Dielenlänge** (Planungskern v9 Regel 11.1, R-B19): bei **Ja** zusätzlich „Dielen höchstens (in cm)“ und „Dielen mindestens (in cm)“ – „beliebig“ (Vorgabe) oder eine Lieferlänge des Belags. Die Automatik nimmt dann nur Längen innerhalb der Grenzen, auch für Treppe, Setzstufen und Blenden (nicht für UK und MASSIV). Passt keine Länge, gelten alle Lagerlängen mit Hinweis „Keine Lieferlänge dieses Belags erfüllt die Vorgabe Dielenlänge“.
- Reststücke auf mehrere Reihen verteilen (z. B. eine 4000-mm-Diele für zwei Reihen mit je 200 cm Rest) gehört zur Verlegung (M5-08).

## 2.3 Verlegearten

| Verlegeart (Tooltip) | Volumen |
|---|---|
| Fugenschnitt (Vorgabe, alle Stöße in einer Linie) | 0,435 m³ |
| Halbverband | 0,445 m³ |
| Drittelverband | 0,454 m³ |
| Viertelverband (neu, Planungskern v7) | – |
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
- Die Stoßlinien laufen quer zur Verlegerichtung über die ganze Fläche. Ihr **Raster** ist die längste erlaubte Lieferlänge (bei erzwungener Länge diese), höchstens aber die Ausdehnung der Fläche in Verlegerichtung. **Überlänge 3 cm** (R-B16, Planungsregeln Alexander (Planungskern v6, 11.11.2026), Planungskern-Konstante Überlänge; Entscheidung 11.11.2026): Dielen kommen mit 3 cm Überlänge, ein Stoß ist erst über der längsten Lieferlänge plus 3 cm nötig – eine 6,00-m- bis 6,03-m-Reihe liegt ohne Stoß auf einer 6-m-Diele (`stossraster`, `dielenUeberlaenge`); auch „Kurze Stücke verbinden“ verbindet bis zur längsten Länge plus 3 cm. Holzfliesen haben keine Überlänge.
- **Verlegemuster nach dem Planungskern v7 (R-B18, Planungsregeln Alexander (Planungskern v7, 11.11.2026) Regel 9.3, seit 12.11.2026):** Fugenschnitt (Standard), Halb-, Drittel-, Viertel- und Wechselverband (`Verlegeart`, Rechnung `Verbandwahl` im Server, die App zeigt nur die Auswahl).
- **Fugenschnitt:** in jeder Reihe dieselben Stöße im Raster vom Ausgangspunkt aus – unverändert, die Parität bleibt.
- **Verband nur, wenn die Fläche länger als eine Diele ist** (längste bzw. erzwungene Lieferlänge plus 3 cm Überlänge); sonst liegt jede Reihe ganz (480 cm mit 6-m-Dielen: kein Stoß, auch im Halb- oder Drittelverband). Ein Abschnitt einer Reihe, der in eine Diele passt (U-Schenkel, Ausschnitte), bleibt ebenfalls ganz.
- **Halb-, Drittel-, Viertelverband:** Reihe für Reihe um ½ / ⅓ / ¼ der Stoßweite (Raster) versetzt, reihum ab dem Ausgangspunkt (Halb: 0, ½, 0 …; Viertel: 0, ¼, ½, ¾, 0 …).
- **Wechselverband:** unregelmäßig – je Reihe einer der vier Viertel-Versätze, nie derselbe wie in den beiden Reihen davor; die Folge ist fest (gleiche Fläche, gleiche Planung).
- **Stücke mindestens 40 cm, höchstens Lieferlänge** (plus Überlänge): Passt der bevorzugte Versatz nicht (Reihe beginnt oder endet kurz vor einer Linie), prüft der Planer die übrigen Versätze, je vom Ausgangspunkt und gespiegelt von der Gegenseite, und nimmt die erste gültige Lage, deren Stöße nicht neben denen der Vorreihe liegen (Abstand mindestens 30 cm bzw. der halbe Versatz; Drittel/Viertel: die 2 bzw. 3 Reihen davor, Wechsel: die 2 Reihen davor). Gibt es keine gültige Lage, wird der Abschnitt in gleich lange Stücke geteilt. Holzfliesen: Mindeststück eine halbe Fliese.
- **Doppel-UK an jeder benutzten Stoßlinie** (Regel 2.1): Die UK legt an jedem Dielenstoß je ein Holz links und rechts (`ukVerlegung`), die Pläne zeigen jede Stoßlinie (R-E01), Clips und Schrauben folgen aus den Kreuzungen. MASSIV-Systemdielen behalten ihren Längenmix (2.7, R-B50): Stöße mittig auf einer UK, keine Doppel-UK.
- Abgleich mit den Zuschnittlisten des alten Planers (48 Reihen, Diele 60 mm): Fugenschnitt 480 cm (F01), 800 cm mit 6-m-Dielen 600 + 200 cm (F09), Halbverband im Wechsel 600 + 200 und 300 + 500 cm (F10), Drittelverband 600 + 200, 200 + 600 und 400 + 400 cm (F11), fest 400 cm: 400 + 400 cm (F13) – wie der alte Planer. **Abweichend nach Planungskern v7:** 480 cm im Halb-/Drittel-/Wechselverband ohne Stoß (alt 240 + 240 bzw. 160 + 320 cm, F06–F08), Wechselverband 800 cm unregelmäßig (alt 600 + 200 und 200 + 600 cm im Wechsel, F12).
- Benchmarks (12.11.2026, lokal): `domain.Verlegeart.reihenstuecke` ≈ 8,6 ms (vorher ≈ 3,4 ms – jetzt fünf Verlegearten und die Wahl je Reihe), `domain.Belagverlegung.verlegeBelag` ≈ 229 ms (vorher ≈ 238 ms), `domain.Verschnittoptimierung.verschnittvarianten` ≈ 178 ms (vorher ≈ 245 ms; die Teilflächen des Benchmarks sind kürzer als eine Diele und bekommen keinen Verband mehr – weniger Stücke), `domain.Dielenverlegung.verlegeDielen` ≈ 567 ms (gleich).
- Der Ausgangspunkt (M5-07) verschiebt den Anfang des Rasters; Richtungen siehe 2.4 (M5-05).

Neuer Planer – **Stoßlinie durch Eckpunkt** (R-B20, Planungsregeln Alexander (Planungskern v13, 13.11.2026), Regel 15):

- Unter 2.3 nach „kurze Stücke verbinden“: „Stoßlinie durch Eckpunkt (optional)“ – eine oder mehrere Ecken (A, B …) als Mehrfachauswahl; gibt es Ausschnitte mit anderem Belag, dazu „Gilt für“: jede Teilfläche mit dieser Ecke (Vorgabe), die Fläche ohne Ausschnitte oder ein Ausschnitt (A1 …). Planungsstand-Felder `stossecken` (Platz 143) und `stossflaeche` (Platz 144); andere Eckenzahl → Vorgabe entfällt, andere Anzahl Ausschnitte → wieder „jede Teilfläche“. Die App zeigt nur Auswahl und Meldungen.
- **Lage:** je Ecke eine Stoßlinie quer zu den Dielen genau durch den Punkt (`festeStosslinien`). Sie ersetzt das Raster der Stoßlinien. Eine Ecke am Anfang oder Ende der Fläche in Verlegerichtung (näher als 20 cm) ergibt keine Linie; passt die ganze Fläche in eine Diele, auch nicht.
- **Welche Teilflächen:** ohne Auswahl die Hauptfläche (sie hat alle Ecken) und jeder Ausschnitt mit anderem Belag, an dessen Umriss die Ecke liegt (1 mm Toleranz); mit Auswahl nur diese.
- **Nur lange Reihen:** Gestoßen wird nur ein Reihenabschnitt, der länger als die längste zulässige Lieferlänge (erzwungene Länge bzw. Vorgabe Dielenlänge R-B19) plus 3 cm Überlänge ist; kürzere Reihen bleiben ohne Stoß – anders als im Raster des Fugenschnitts ohne Vorgabe, das unverändert bleibt. Kurze Stücke werden nicht über eine feste Linie hinweg verbunden.
- **Zusätzliche Stöße:** Wäre ein Stück zwischen zwei festen Linien (oder Linie und Rand) länger als Lieferlänge plus Überlänge, wird es in gleich lange Stücke geteilt (L-Form 16 m, Linie bei 2 m: weitere Stöße bei 6,67 und 11,33 m). Die Meldung nennt die Anzahl (`Berechnung.zusatzstoesse`, Platz 170).
- **Doppel-UK** an jeder Stoßlinie wie immer (Regel 2.1, `ukVerlegung` aus den Dielenstößen).
- **Gilt nicht** bei MASSIV (Längenmix), in den Verbänden (R-B18) und bei Holzfliesen – dort Hinweis; das Stoßraster am Rand (135°, `ecke`) und der Verband bleiben dann unverändert.
- Ohne Vorgabe ändert sich nichts (Parität unverändert).

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
- **Stoßlinien** im Raster der Verlegeart ab der Ausgangsecke, wenn dort eine gerade Kante quer zur Verlegerichtung liegt (waagrecht und senkrecht im Rechteck; L-Form ab B: Stoß entlang der Innenkante, Referenzfall 2026-06-07-4340). Sonst beginnt das Raster am näheren Rand der Fläche (Alexander 13.11.2026): Bei 135° liegt A mitten in der Ausdehnung; der alte Planer zog eine Stoßlinie durch A und erzeugte Stücke bis 1,5 cm (F04, 154 statt 86 Stücke) – das übernimmt der neue Planer nicht. Eine Verschiebung des Ausgangspunkts (2.5) verschiebt das Raster mit. Im Verband wählt `Verbandwahl` die Linien Reihe für Reihe (siehe oben).
- **Schmale Restreihen** unter 15 mm Breite entfallen: Der alte Planer lässt eine 14 mm breite Ecke bei 45° (F03) und 11 mm bei 30° (F05) weg, verlegt aber eine 18 mm breite Reihe (Referenzfall 2026-05-29-3162). Die genaue Grenze ist aus den Daten nicht bestimmbar.
- Abgleich: Die Stücklängen stimmen mit den Zuschnittlisten von F01–F13 auf 1 mm überein (senkrecht 74 × 309 cm, 45° 86 Stücke, 30° 78); 135° neu ohne Stoß durch A mit 86 Stücken in derselben Gesamtlänge statt 154. Wie die Stücke auf Lieferlängen verteilt werden, gehört zur Verlegung (M5-08).
- Der Server verlegt mit dem gewählten Belag (Breite, längste oder erzwungene Länge) und liefert die Umrisse der Dielenstücke mit der Berechnung; die Zeichnung zeigt sie auf der Ebene „Belag“. Holzfliesen verlegt M5-08 (siehe 2.7).

## 2.5 Ausgangspunkt des Belags

- „Welcher Punkt soll der Ausgangspunkt des Terrassenbelages sein?“ – Auswahl eines Eckpunkts (Vorgabe A).
- „Verschieben Sie die erste ganze Diele mit dem Mauszeiger oder dem Eingabefeld nach:“ – „links/rechts um“ und „oben/unten um“ (cm), je mit Schieberegler.

Neuer Planer (M5-07):

- Auswahl der Ecke als Chips A, B, C … in derselben Zählung wie die Beschriftung der Zeichnung (`Grundriss.ecken`: Rechteck A–D, L/T/U/O und Freiform alle Eckpunkte). Der Kreis hat keine benannten Ecken und bietet nur A, den Anfang seiner Kontur. Bei einer gerundeten Ecke gilt der Schnittpunkt ihrer Kanten. Planungsstand-Felder `ausgangsecke` (Vorgabe 0 = A), `verschiebungX` und `verschiebungY` (mm); gibt es die Ecke nach einem Formwechsel nicht mehr, gilt wieder A.
- Verschoben wird in Bildschirmkoordinaten: „links/rechts um“ positiv nach rechts, „oben/unten um“ positiv nach unten, je Eingabefeld in cm (Enter übernimmt) und Schieberegler in ganzen cm. Mit der Maus zieht man den grünen Griff an der Ecke der ersten ganzen Diele (Ausgangspunkt plus Verschiebung), solange der Schritt Terrassenbelag offen ist. Jede Eingabe und jeder Zug ist ein Schritt für Rückgängig/Wiederherstellen.
- **Grenzen:** höchstens eine Belaglänge bzw. Belagbreite. Die Achse, die eher in Verlegerichtung liegt (Winkel bis 45° oder ab 135°), bekommt das Raster der Stöße (längste bzw. erzwungene Lieferlänge, höchstens die Ausdehnung der Fläche, siehe 2.3), die andere Dielenbreite plus Fuge. Der Server rechnet die Grenzen und begrenzt auch eine gespeicherte Verschiebung, die nach einem Belagwechsel zu groß ist.
- **Warnung:** Entsteht ein Dielenstück kürzer als 5 cm oder eine Randreihe schmaler als 5 cm (Reihen unter 15 mm entfallen weiter, siehe 2.4), meldet der Server das mit der Berechnung (`kurzeZuschnitte`), und unter 2.5 erscheint „Achtung: Es entstehen Zuschnitte unter 5 cm …“. Beispiel: 480 × 309 cm mit 6-cm-Dielen hat ab A eine 3,5 cm breite letzte Reihe; 5 cm nach unten verschoben bleiben oben und unten je 5 cm.
- Ohne verlegte Dielen (kein Belag) gibt es keine Verschiebung, nur die Wahl der Ecke; bei MASSIV-Systemdielen nur quer zu den Dielen (die Stöße liegen fest auf dem Raster ab dem Rand, 2.7).

## 2.6 Befestigungsart

Im alten Planer ergibt sich die Befestigung aus dem Belag: genutete Dielen mit CLIP-FIXX (Packungsmix VPE 250 + 100 + 50), dazu einseitig genutete Randdielen mit Terrassenschrauben 5,0 × 50 mm (je UK-Kreuzung eine); glattkante Dielen von oben verschraubt (F24: 806 Schrauben für 30 Reihen × 13 UK).

Neuer Planer (M5-09):

- Unterpunkt 2.6 „Befestigungsart“ mit den Arten, die zum Profil des Belags passen: **Mit Clips** nur bei genuteten Dielen (B-094), glattkante Dielen **direkt verschraubt** (Vorgabe) oder **verschraubt mit Abstandshaltern** (B-090). Planungsstand-Feld `befestigungsart` (Vorgabe Clips wie im alten Planer); gilt die gewählte Art für den Belag nicht, gilt die Vorgabe seines Profils, die Wahl bleibt aber für einen späteren Belagwechsel erhalten. Was wählbar ist und was gebraucht wird, rechnet der Server; die Oberfläche zeigt die Befestigungspunkte und die Artikel mit Anzahl.
- **Artikel** aus den Befestigungsverweisen des Belags in der Upload-Datei (B-122), Preise und Verkaufseinheiten unverändert (B-153): genutet unter 100 mm und genutete ECO SELECT/BASIC ab 100 mm **CLIP-FIXX**, genutete PREMIUM SELECT ab 100 mm **DUO-CLIP-FIXX** (B-094, B-150; R-B01). Die Clipschrauben sind im Lieferumfang und keine eigene Position (B-074). Glattkant: Terrassenschrauben in der kürzesten Länge, die mindestens die doppelte Dielenstärke hat (21–25 mm → 50 mm, 26 mm → 60 mm). Verschraubt mit Abstandshaltern: eine Packung **Montagehilfe Abstandshalter** (wiederverwendbar, 5–8 mm einstellbar) für die Fuge von **6 mm** (R-B06) – bei Clips geben die Clips sie vor (Alexander 04.11.2026; gerechnet wird seit dem 11.11.2026 mit 6 mm). Einweg-Abstandshalter 4/7 mm passen nicht zur Fuge und werden nicht gewählt.
- **Befestigungspunkte:** jede Kreuzung eines Dielenstücks mit einer UK-Linie – mit gewählter UK auf den Hölzern der UK-Verlegung (M6-10, `befestigungspunkteAufUk`). Ohne UK-Artikel (Übergangs-UK), liegen die UK-Linien quer zur Verlegerichtung gleichmäßig über die Ausdehnung der Verlegung, höchstens im UK-Abstand des Belags (Artikeldaten 40 cm, höchstens 40 cm der Holzart, R-C01) auseinander, die äußeren am Rand (B-096). Jedes Stück liegt an beiden Enden auf – am Stoß zwei UK nebeneinander – und dazwischen auf jeder Linie, die es überdeckt. F01: 48 Reihen × 13 = 624 Punkte; F09 (800 cm, Stoß bei 600 cm): 48 × 22.
- **Mengen (Planungsregeln Alexander (Planungskern v6, 11.11.2026) Abschnitt 4, Entscheidung Alexander 11.11.2026):**
  - **Genutet:** Anfangs- und Enddiele (erste und letzte Reihe) werden **sichtbar verschraubt** – Schraube und Anzahl wie bei der Verschraubung von oben (R-B02: je UK-Kreuzung eine, ab 100 mm zwei; Kreuzungen mit der Rand-UK, R-C11, zählen mit; Schrauben aus den Befestigungsverweisen des Gegenstücks derselben Serie und Breite glattkant). **Clips = übrige Kreuzungen + 5 %**, aufgerundet (`clipsMitZuschlag`), dann VPE 250/100/50. Ohne glattkantes Gegenstück in den Artikeldaten bekommen auch die Randreihen Clips. F01 (5 mm Fuge, 48 Reihen): (624 − 26) × 1,05 → 628 Clips + 26 Schrauben (vorher 637 Clips ohne Schrauben); mit 6 mm Fuge (47 Reihen): (611 − 26) × 1,05 → 615 Clips + 26 Schrauben.
  - **Glattkant:** Schrauben je Punkt eine, ab 100 mm Breite zwei (R-B02) – F24: 390 Punkte, 780 Schrauben. Montagehilfe eine Packung je Planung.
- **Verkaufseinheiten:** so wenig Überhang wie möglich, dann so wenig Packungen wie möglich: F01 628 Clips → 2 × VPE 250 + VPE 100 + VPE 50 (wie der alte Planer), 780 Schrauben → 4 × 200 Stück. (Der Planungskern packt gierig – volle 250er, volle 100er, Rest in 50ern; das ergibt nur in Grenzfällen etwas anderes, z. B. 180 → 100 + 50 + 50 statt 2 × 100.)
- **Abweichungen vom alten Planer:** keine einseitig genuteten Randdielen (B-033) – Anfangs- und Enddiele sind normale genutete Dielen, die nach der **Entscheidung Alexander 11.11.2026** (weicht von der bisherigen Auslegung von B-033 ab, nach der die Randreihen Clips bekamen) wie im alten Planer sichtbar verschraubt werden; die Clips bekommen 5 % Zuschlag; glattkant ohne die 26 zusätzlichen Schrauben aus F24 (806 → 780).
- **Befestigung umschalten** (Planungsregeln Alexander (Planungskern v6, 11.11.2026) Regel 4.4, R-B14): Gibt es zur Diele das Gegenstück derselben Serie und Breite mit dem anderen Profil (genutet ↔ glattkant; bei mehreren gewinnt gleiche Stärke, dann gleiche Oberseite, dann die Reihenfolge der Daten – `gegenstueck`), bietet 2.6 auch dessen Arten an. Die Wahl „von oben“ bei einer genuteten bzw. „mit Clips“ bei einer glattkanten Diele setzt dann auch den Belag auf das Gegenstück (`Befestigungsbedarf.wechsel`, Berechnung Platz 36; die App übernimmt nur die Nummer vom Server). Ohne Gegenstück bleibt es bei den Arten des Profils; eine gespeicherte Art, die nicht passt, meldet weiter „Befestigungsart nicht möglich“.
- Holzfliesen (Verbinder) siehe 2.7; die echten UK-Linien liefert M6.

## 2.7 Berechnung der Dielenverlegung

Ergebnis der Schritte 2.1–2.5: die verlegten, nummerierten Stücke, die Planungsunterlage „Dielen/Platten nach Nummer“, der Deckbelag-Zuschnitt und die Kennzahl Verschnitt.

Neuer Planer (M5-08):

- **Teilflächen:** Die Hauptfläche spart alle Ausschnitte aus – leere Flächen bekommen kein Material (1.4). Ein Ausschnitt mit anderem Terrassenbelag ist eine eigene Teilfläche, verlegt ab seiner Ecke oben links in derselben Richtung und Verlegeart; bis er einen eigenen Belag wählen kann, mit dem Belag der Fläche (F22). Ragt ein Ausschnitt nur in einen Teil einer Reihe, wird die Diele ausgeklinkt und bleibt ein Stück; liegt er ganz in einer Reihe (Pfosten unter der Dielenbreite), endet die Diele an ihm. Rundungen gehen über die Kontur ein, mehrere Flächen (M4-14) jede für sich.
- **Nummern:** je Teilfläche ab 1 in Verlegereihenfolge; gleiche Länge (auf 1 mm) und gleiche zugeschnittene Breite tragen dieselbe Nummer. Die zugeschnittene Breite ist die Ausdehnung des Stücks quer zur Verlegerichtung ohne Fuge (Randreihe: Restbreite − 5 mm, R-B13). Die Zeichnung schreibt die Nummer längs ins Stück, wo sie auf dem Bildschirm hineinpasst.
- **Zuschnitt (Reststücke verteilen):** Die Stücke einer Teilfläche werden absteigend auf Lieferdielen verteilt. Ein Stück kommt in den kleinsten passenden Rest einer angefangenen Diele; sonst beginnt eine neue in der Lieferlänge mit dem kleinsten Rest nach dem Auffüllen mit den folgenden Stücken (bei Gleichstand die kürzere); am Ende bekommt jede Diele die kürzeste Länge, die ihre Stücke aufnimmt. Jede Lieferlänge nimmt Stücke bis zu ihrer Länge plus 3 cm Überlänge auf (R-B16: 603 cm aus 6000 mm); die Überlänge zählt im Verschnitt nicht als geliefert (geplant höchstens die Lieferlänge). **Musterverfahren (R-B17, seit 12.11.2026 immer):** höchstens 3 Stücke je Diele, 5 mm Sägeschnitt zwischen zwei Stücken (2 × 300 cm aus 6 m, 2 × 301,5 cm nicht mehr), ein weiteres Stück nur aus einem Rest ab 30 cm; am Ende bekommt jede Diele die kürzeste Länge, aus der ihre Stücke so geschnitten werden können. Gerechnet werden die Verteilung oben mit allen Lieferlängen, je Lieferlänge, die jedes Stück aufnimmt, und Diele für Diele (`musterZuschnitte`: größte Füllung bzw. kürzestes Stück dazu); es gilt bei höchstens 1 % Mehrlänge die mit den wenigsten Dielen (`besteVerteilung`). F04 (152 Stücke): 51 Dielen, 237 m (vorher 52 Dielen, 231 m ohne Grenze der Stücke). Die Paritätstests des Rechenwegs gegen den alten Planer rechnen wie dieser ohne Musterverfahren (`Musterregel.frei`: ohne Zugabe, 2 × 200 cm aus 4000 mm; Überlänge nur als Angebot, F19 168 m). Beispiele (Rechenweg ohne Musterverfahren, Fuge 5 mm): F09 600 + 200 cm → 48 × 6000 + 24 × 4000 mm, F06 Halbverband → 48 × 5000 mm, F21 → 38 × 5000 + 5 × 4000 mm – jeweils wie der alte Planer; mit Musterverfahren und Fuge 6 mm F09 62 × 6000 + 4000 mm (378 m wie 47 × 6000 + 24 × 4000, aber 63 statt 71 Dielen).
- **Dielenliste:** Anzahl je Lieferlänge über alle Teilflächen; über die Planung je Belag, jede Fläche mal ihrer Häufigkeit. Freidielen (R-B09) kommen mit dem Zubehör (M8) als eigene Position mit Preis 0 in die Materialliste (M9-03, [08](08-ergebnisse.md#materialliste)).
- **Verschnitt** (R-B11) = (geliefert − geplant) ÷ geliefert über die Längen, für die ganze Planung; Kennzahl rechts oben zwischen Fläche und Volumen („Verschnitt: 4 %“, höchstens zwei Nachkommastellen) und unter 7.1 mit „Benötigte Dielen“. F01 4 %, F02 22,75 %, F20 10 %, F23/F24 4 %, F25 0,99 % stimmen.
- **Holzfliesen** (606 × 606 mm) liegen wie Dielen in Reihen aus Kantenlänge plus Fuge (alter Planer 5 mm, neu 6 mm – R-B06) und werden längs ohne Fuge gestoßen (F25: 7 × 60,6 + 55,8 cm, 6 Reihen, 48 Fliesen; Referenzfall 2026-08-17-1838: Randreihe 25,1 cm, 36 Fliesen). Kurze Stücke werden bei Fliesen nie verbunden.
- **MASSIV-Systemdielen** (Planungskern v13 Abschnitt 1a, B-036, B-232; R-B50–R-B52, R-C50, R-C51): Endlosverlegung im Längenmix 0,8 / 1,2 / 1,6 / 2,0 m aus den Lieferlängen der Serie. Je Reihe fair gemischt (die am wenigsten gelegte Länge zuerst, feste Zufallsfolge), jeder Stoß auf dem 40-cm-Raster ab dem Rand (bei Feldbreite 30/35 cm in diesem Raster, Frage 102), nicht neben dem Stoß der Vorreihe (möglichst auch nicht der Reihe davor), Anfangs- und Reststück mindestens 30 cm; jede Reihe bis 2,005 m ohne Stoß. Jedes Stück kommt aus einer eigenen Lieferlänge (die Dielenliste zeigt den Mix, verkauft wird je m²). Verlegeart, Dielenlänge, Verschiebung in Verlegerichtung und die feste Stoßlinie (Kern Regel 15.4) gelten nicht. Die UK (ECO SELECT, Frage 100) liegt am Rand bündig und auf jeder Rasterlinie – jeder Stoß mittig auf **einer** UK (Ausnahme von Regel 2.1), Clips = UK-Linien je Reihe. Menge: belegte Fläche + 5 % (Rechteck) bzw. 10 % (Schrägen, Bögen, Aussparungen, mehrere Flächen) auf ganze Pakete à 1,5 m² für die ganze Planung, keine Freidiele, keine Verschnittoptimierung; die Seitenblende kommt aus MASSIV glattkant je m² (+5 %, R-D50).
- **Befestigung:** Die Befestigungspunkte (2.6) zählt der Server über die Stücke aller Teilflächen. Fliesenverbinder (F25: 63 Verbinder für 48 Fliesen) bleiben offen – die Regel lässt sich aus einem Fall nicht ableiten.
- **Volumen:** bleibt „–“, bis die Unterkonstruktion gerechnet wird (M6-10); der alte Planer zeigt Belag plus UK. Hinweis aus F02: 74 × 4000 mm Dielen (0,391 m³) plus 9 × 5000 mm UK 40 × 60 (0,108 m³) ergeben die angezeigten 0,499 m³ – das Volumen rechnet mit den gelieferten Längen.
- **Grenze zu M9-01:** Die Verteilung ist eine Regel je Teilfläche, keine Optimierung; sie gilt, solange unter 7.1 keine Optimierung erstellt ist. Varianten, Rest-Ausgleich über Teilflächen und Flächen hinweg und Längenmischungen nach Verschnitt rechnet die Verschnittoptimierung ([07](07-verschnittoptimierung.md), M9-01).
- **Abgleich Referenzfälle (M1-02, Rechtecke, L- und T-Formen ohne Rundung):** „Dielen nach Nummer“ stimmt bei 18 von 23 vergleichbaren Fällen genau; bei 8 davon auch die Lieferung, bei 10 liegen nur die Zwischenlängen 3,0/4,5/5,5 m des alten Planers auf der nächsten Lieferlänge (R-A06). Abweichungen: 2026-04-13-1946 und 2026-04-29-164 verlegen mit 7000 mm für Dielen mit 4/5/6 m (Fehler wie F14, B-035; mit 7 m stimmen die Stücke), 2026-07-31-3374-v5 nennt an Ausklinkungen die schmale Breite (neu: die volle Breite des Stücks, die man zum Zuschneiden braucht), 2026-06-15-1093 lässt sich ohne Angabe der Verlegeart nicht nachstellen; 2026-06-03-2910 hat einen Ausschnitt ohne Lage. In zwei der verglichenen Unterlagen steht „Waagrecht“, die Zeichnung zeigt senkrecht – verglichen wird die Zeichnung (2026-05-03-347, 2026-06-30-2295). Drittel- und Halbverband runden den Versatz auf ganze mm (404 cm: 134,7 + 269,3 cm wie 2026-05-03-4381).
- **Abweichung Verschnitt F21:** gleiche Lieferung wie der alte Planer, aber 4,57 statt 4,36 % (geplant 43 × 360 + 19 × (100 + 140) cm); der alte Rechenweg ist aus den Daten nicht nachvollziehbar.

## 2.8 Grenzwerte und Meldungen

Der alte Planer wechselt still auf Vorgaben oder verlegt nichts, ohne es zu sagen. Der neue Planer meldet es dort, wo die Eingabe passiert.

Neuer Planer (M5-10):

- **Wo geprüft wird:** Die Sortimentsgrenzen der Beläge prüft schon der Import (M2-03): Breite × Stärke je Serie und Profil (B-030, B-032, B-036), Lieferlängen je Serie (B-035) und – neu – keine einseitig genuteten Dielen (B-033, Titel mit „einseitig“ ist ein kritischer Befund). Ein Belag außerhalb kommt gar nicht in die Auswahl. Alles, was erst aus Fläche, Belag und Wahl entsteht, prüft der Server mit jeder Berechnung (`belagmeldungen`) und liefert die Meldungen mit; die App zeigt nur an.
- **Meldungen** (⚠ = Warnung, ℹ = Hinweis), Unterpunkt und Text:

| Meldung | Unterpunkt | Bedingung | Text (Deutsch) |
|---|---|---|---|
| ℹ Belag ersetzt | 2.1 | Belag des Planungsstands nicht mehr in den Artikeldaten; es gilt die Vorgabe (M5-01) | „Der gewählte Belag ist nicht mehr im Sortiment. Geplant wird mit dem Vorgabebelag – wählen Sie bei Bedarf über „Produktauswahl“ einen anderen.“ |
| ⚠ Belag ohne Maße | 2.1 | Diele oder Fliese ohne Breite oder Lieferlänge – nicht verlegt | „Für diesen Belag fehlen Breite oder Lieferlängen, er kann nicht verlegt werden. Bitte wählen Sie einen anderen Belag.“ |
| ℹ Systemdiele | 2.1 | MASSIV-Systemdiele im Längenmix (B-036, B-232, 2.7) | „MASSIV-Systemdielen liegen im Längenmix 0,8 / 1,2 / 1,6 / 2,0 m mit je Reihe versetzten Stößen; jeder Stoß liegt mittig auf einer UK (Raster 38 / 40 cm). Verlegemuster und Dielenlänge gelten dafür nicht.“ |
| ⚠ Fläche kleiner als Belag | 2.1 | Eine Teilfläche (Hauptfläche oder Ausschnitt mit anderem Belag) hat kein ganzes Stück: keine volle Reihenbreite (Breite + 6 mm Fuge, 1 mm Spielraum), bei Fliesen auch keine volle Kantenlänge 606 mm. In der Länge wird jede Diele zugeschnitten – das ist keine Grenze. | „Die Fläche oder eine Teilfläche ist kleiner als eine Diele bzw. Fliese: Es passt keine ganze Belagbreite hinein, nur ein Zuschnitt.“ |
| ⚠ Holzfliesen mit spitzen Ecken | 2.1 | Holzfliese und eine Ecke der Fläche oder einer Teilfläche mit anderem Belag unter 90° (Grenze 89,5°; Freiform, Dreieck) | „Die Fläche hat Ecken unter 90°. Holzfliesen müssen dort schräg zugeschnitten werden – für solche Formen eignen sich Dielen besser.“ |
| ℹ Bombierung empfohlen | 2.1 | Glatte Diele ab 80 mm Breite (R-B03) | „Ab 8 cm Breite empfehlen wir bombierte (leicht gewölbte) Dielen.“ |
| ℹ Länge nicht lieferbar | 2.2 | Erzwungene Länge, die der Belag nicht liefert (M5-02, B-035) – es gilt die Automatik | „Die gewählte Länge von 700 cm gibt es für diesen Belag nicht. Die Dielenlänge wird automatisch ermittelt.“ |
| ℹ Zusätzliche Stöße | 2.3 | Vorgabe „Stoßlinie durch Eckpunkt“: Stücke zwischen den festen Linien länger als die Lieferlänge (R-B20, Meldung 11) | „Zwischen den festen Stoßlinien wären die Dielen länger als die Lieferlänge. Die Planung setzt 2 zusätzliche, gleichmäßig verteilte Stöße (mit doppelter UK).“ |
| ℹ Stoßlinie nicht im Muster | 2.3 | Vorgabe bei MASSIV, im Verband oder bei Holzfliesen (R-B20, Meldung 12) | „Die Stoßlinie durch einen Eckpunkt gilt nur für Dielen auf Fuge geschnitten – bei MASSIV (Längenmix), im Verband und bei Holzfliesen legt der Planer die Stöße selbst.“ |
| ℹ Stoßlinie ohne Wirkung | 2.3 | Keine gewählte Ecke ergibt eine Linie (am Rand, an keiner gewählten Teilfläche, Reihen passen in eine Diele; R-B20, Meldung 13) | „Durch die gewählte Ecke läuft keine Stoßlinie: …“ |
| ℹ Befestigungsart nicht möglich | 2.6 | Verschraubung gewählt, Belag genutet: Clips (B-094). Die Vorgabe Clips bei glattkanten Dielen meldet nichts, weil sie keine bewusste Wahl ist. | „Genutete Dielen werden verdeckt mit Clips befestigt. Die gewählte Verschraubung gilt nur für glattkante Dielen.“ |
| ⚠ Befestigung ohne Artikel | 2.6 | In den Befestigungsverweisen des Belags (B-122) fehlen passende Clips (bei PREMIUM SELECT ab 100 mm DUO-CLIP-FIXX, B-150) oder Schrauben | „Für diesen Belag sind keine passenden Clips oder Schrauben hinterlegt – die Befestigung fehlt in der Materialliste. Bitte sprechen Sie uns an.“ |
| ⚠ Schraube zu kurz | 2.6 | Verschraubt und keine hinterlegte Schraube hat die doppelte Dielenstärke (2.6); gerechnet wird mit der längsten | „Keine hinterlegte Schraube ist mindestens doppelt so lang, wie die Diele stark ist. Gerechnet wird mit der längsten – bitte prüfen Sie die Schraubenlänge.“ |
| ⚠ Zuschnitte unter 5 cm | 2.5 | aus M5-07 (`kurzeZuschnitte`), unverändert | siehe 2.5 |

- **Englisch** über dieselben Schlüssel (`belagmeldung…` in `planer_en.arb`).
- **Fläche länger oder breiter als sinnvoll:** Die Grenzen der Terrassenmaße (kleinste Seite 50 cm, Freiform und Ausschnitte 10 cm, größte 3000 cm; Frage 18) prüft schon die Eingabe des Grundrisses (M4-02) mit Meldung. Für den Belag gibt es darüber hinaus keine Längengrenze: Reihen über der längsten Lieferlänge werden gestoßen (2.2).
- **Grenzen der Eingaben** aus M5-05/M5-07 bleiben: Verlegewinkel 0–179° (Meldung am Feld), Verschiebung höchstens eine Belaglänge bzw. -breite (begrenzt, ohne Meldung, weil Regler und Feld die Grenze zeigen).
- Mehrere Flächen (M4-14): Die Meldungen gelten für die bearbeitete Fläche.
