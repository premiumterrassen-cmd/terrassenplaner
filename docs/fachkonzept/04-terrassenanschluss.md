# 04 Terrassenanschluss

Je Seite des Grundrisses ein Schalter. Eine Seite kann nur eine Rolle haben: Wird sie in einer Frage eingeschaltet, verschwindet sie aus den anderen.

## 4.1 Welche Seiten grenzen an bestehende Bauelemente?

„(wird in der Konfiguration grau dargestellt)“ – die Seite wird grau schraffiert. Sie steht dann nicht mehr für Verblendung oder Treppe zur Wahl.

**Umsetzung (M7-01):** Seite `i` läuft von Ecke `i` zur nächsten (A — B ist Seite 0) und heißt wie in der Beschriftung der Zeichnung. Der Planungsstand merkt sich die angrenzenden Seiten im Anschluss (`Anschluss.angrenzend`, Transportformat Platz 140); ändert sich die Eckenzahl (andere Form, Freiform-Punkte) oder wird eine neue Form gewählt, beginnt der Anschluss neu, bei neuen Maßen oder Drehung bleibt er. Kreis und offene Freiform haben keine Seiten. Der Server liefert die Seiten mit Rolle für die Zeichnung (`Anschlussergebnis`, Berechnung Platz 150); die App zeichnet sie als dicke graue Linie über dem Umriss, unabhängig von den Ebenen. Ohne weitere Rollen hat eine angrenzende Seite keine Wirkung auf Material und Fläche (F36 = F01). Wirkung auf Verblendung, Rinne und Treppe: siehe 4.2, 4.3 und [05](05-treppen.md).

## 4.2 Welche Seiten sollen verblendet werden?

„(wird in der Konfiguration gelb dargestellt)“ – die Seite wird gelb.
Beispiel B — C (309 cm): + „Terrassendiele Robinie 80 x 22 mm, glattkant, keilgezinkt – Länge: 4000 mm – Verblendung“, Volumen 0,435 → 0,442 m³, Summe 2.091,33 €.

**Umsetzung (M7-02):**

- Auswahl je Seite wie 4.1; Seiten an Bauelementen stehen nicht zur Wahl, wer eine Seite verblendet, nimmt ihr die Rolle „Bauelement“ und umgekehrt (`Anschluss.verblendet`). Beim Kreis gibt es nur „Fläche verblenden“ (Seite 0 steht für den ganzen Umfang). Verblendete Seiten zeichnet die App gelb.
- **Seitenblende nach den Planungsregeln Alexander (Planungskern v6, 11.11.2026), Abschnitt 4a** – ersetzt seit `feature/planungskern-seitenblende` die Kopie des alten Planers (Verweisspalte „moeglicheVerblendung“, nur Belagstärke 19–23 mm, Reihen bis zur Blendenhöhe, Halter im UK-Achsabstand über die ganze Höhe):
  1. **Blende aus der Serie (4a.1):** glattkante Diele derselben Holzart und Serie in der Stärke des Belags (`blendenZumBelag`) – Beispiel Diele PREMIUM SELECT 80 × 23 → Blende PREMIUM SELECT 80 × 23 glattkant. Der Verweis „moeglicheVerblendung“ wird nicht mehr gebraucht.
  2. **Breite (4a.2):** die breiteste vorhandene Breite der Serie unter der Aufbauhöhe der Seite, damit die Blende nicht auf dem Boden aufsteht; höchstens 100 mm (bei 12,5 cm → 100 mm; 90 mm gibt es nicht → 80 mm). Maßgeblich ist die **niedrigere** Ecke der Seite (Kreis: die niedrigste Höhe).
  3. **Über ca. 13 cm (4a.3):** Stellfüße oder größere Höhe – zwei Blenden à 60 mm mit Zwischenraum (über 130 mm).
  4. **Rückfrage (4a.4):** Gibt es die nötige Breite (oder überhaupt eine glattkante Diele in der Belagstärke, z. B. BASIC 26 mm genutet) nicht, rechnet der Planer an dieser Seite nichts und zeigt die Meldung `blendeFehlt` („… bitte sprechen Sie uns an“) – er rät nicht.
  5. **Gehrung (4a.5):** jede Reihe einer Seite ist so lang wie die Seite + 5 cm (je Kante); beim Kreis ohne Ecken keine Zugabe. Lieferlängen wie bei der UK (`lieferstuecke`). F37: 314 / 485 / 314 cm → 2 × 4000 + 1 × 5000 mm, Volumen +0,022 m³ (13 m × 80 × 21 mm). Die Blenden stehen nur in der Materialliste, mit Zusatz „Verblendung“ (`Materialzusatz.verblendung`), nicht in der Stückliste (Fachkonzept 08).
  6. **Träger (4a.6, R-C05):** senkrechte Hölzer aus dem UK-Holz der Serie (die gewählte UK), je verblendeter Seite höchstens 40 cm auseinander und an beiden Enden einer – das gilt auf beiden Seiten (an den Stirnenden der UK und an der anderen Seite), beim Kreis schließt sich der Umfang. Länge = Höhe − 2 cm − Dielenstärke (F37: 86 − 20 − 21 = 45 mm, 9 + 13 + 9 = 31 Stück). Sie stehen als UK-Stücke in der Stückliste und werden zuerst aus den Resten der UK-Hölzer geschnitten (gemeinsamer UK-Zuschnitt der Fläche, `lieferhoelzer`) – F37 ohne weiteres UK-Holz (13 × 4000 mm). Ohne UK-Verlegung keine Träger. **2 Schrauben je Träger** in der Materialliste: die erste Schraube aus dem Befestigungsverweis der Blende (glattkant = Terrassenschrauben) mit allen Verpackungseinheiten dieser Länge; ohne Schraube kein Bedarf.
  7. **„Blende an allen Kanten“ (4a.7):** alle Kanten außer Hauswand/angrenzender Seite. Der Planer wählt seitenweise; Seiten am Bauelement (4.1) stehen nicht zur Wahl, die Unterlüftungs-Warnung kommt, wenn alle freien Seiten verblendet sind.
- **Hinweise vom Server** (`Anschlussmeldung`): Unterlüftung, wenn alle freien Seiten verblendet sind (F37, Kreis immer); kein Höhenunterschied, wenn die Höhe einer Seite die Dielenstärke nicht übersteigt (dort kein Material); `blendeFehlt` (Nummer 7) statt der früheren Meldungen „Belagstärke 19–23 mm“ (3) und „kein Verblendungsartikel“ (4).
- Annahmen (offen für Alexander): „unter der Aufbauhöhe“ streng kleiner (Höhe 100 mm → 80 mm); die niedrigere Ecke zählt; Gehrungszugabe an jeder Seite (auch wo die Nachbarseite nicht verblendet ist); Schraubenartikel für die Träger aus dem Befestigungsverweis der Blende; Träger-Abstand fest 40 cm, unabhängig vom UK-Achsabstand.

## 4.3 An welchen Seiten sollen Entwässerungsrinnen geplant werden?

- Schalter je Seite, danach Auswahl der Lage:
  - Gesamte Seite (innen) – Vorgabe
  - im bodentiefen Element
  - außerhalb des bodentiefen Elements
  - nur vor dem bodentiefen Element
- Produktkarte „RELO V Ventilationsprofil, Einzelstück(e)“.
- Lage und bodentiefes Element sind **fest im Artikel verankert**: Rinnen werden nur an den Seiten verbaut, als Ventilationsprofil oder Entwässerungsrinne; die Lageauswahl wählt die Artikelvariante.
- Beispiel C — D (480 cm), gesamte Seite: Fläche 14,832 → 14,256 m² (Rinne 12 cm breit), + Ventilationsprofil, + Auflagerprofil, weniger Dielen → 2.421,13 €.

**Umsetzung (M7-03):**

- Unterpunkt 4.3: Schalter je Seite – nicht an verblendeten Seiten, an Seiten am Bauelement schon (F38); danach die Lage, Vorgabe „Gesamte Seite (innen)“ (`Anschluss.rinnen`, `Rinnenlage`). Wer eine Seite verblendet, nimmt ihr die Rinne und umgekehrt. Seiten mit Rinne zeichnet die App blau.
- **Artikel:** die Verweise „moeglicheDrainage“ des Belags in Datenreihenfolge stehen für die vier Lagen in ihrer Reihenfolge; fehlt eine Variante, gilt die erste (`rinnenartikel`, R-D01). Ohne Artikel: Hinweis, kein Material, keine Aussparung.
- **Fläche und Belag:** die Seite wird um die Breite des Rinnenartikels nach innen versetzt (`belagstand`/`rinnenstand`); Fläche und Belag rechnen mit diesem Umriss – F38: 480 × 297 cm = 14,256 m², 46 statt 48 Dielen (alter Planer 44 + 2 einseitig genutete). Die UK rechnet mit dem ganzen Grundriss (R-C08, 13 × 4000 mm wie F38).
- **Material:** je Seite Rinnenstücke in den Lieferlängen des Artikels (`lieferlaengenFuer`, F38: 480 cm aus 1200 mm → 4), ohne Längen in lfm; dazu das Pflichtzubehör der Rinne (z. B. Auflagerprofile) im „Abstand_Stelzfuesse“ der Rinne plus eins (F38: 100 cm → 6), ohne Abstand je Rinnenstück, mal der Anzahl aus den Artikeldaten.
- Annahmen (offen für Alexander): Alle Lagen liegen über die ganze Seite; die Lage wählt nur die Artikelvariante (Reihenfolge der Verweise = Reihenfolge der Lagen). „Nur vor dem bodentiefen Element“ ohne Maß des Elements – ob die Variante ein festes Stück ist, sagt der Artikel. Die Master-Artikelliste v27 hat im Blatt „Import Terrassenplaner“ keine berechneten Werte; die Verweise müssen dort gepflegt werden.
