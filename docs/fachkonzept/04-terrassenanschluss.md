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
- **Material nur bei Belagstärke 19–23 mm** (`verblendungMoeglich`), sonst Hinweis und kein Material. Der Artikel kommt aus der Verweisspalte „moeglicheVerblendung“ des Belags (B-122); fehlt er, Hinweis.
- **Verblendungsdielen:** je Seite so viele Reihen, wie die Blendenhöhe (Höhe der Seite – die höhere ihrer beiden Ecken – minus Dielenstärke) in Brettbreiten braucht, jede Reihe so lang wie die Seite (Eckpunkt zu Eckpunkt), Kreis: Umfang. Lieferlängen wie bei der UK (`lieferstuecke`, lange Reihen eigene Bretter, kurze zusammen). F37: 309 / 480 / 309 cm → 2 × 4000 + 1 × 5000 mm, Volumen +0,022 m³ (13 m × 80 × 21 mm; alter Planer +0,023 mit 22 mm). Die Dielen stehen nur in der Materialliste, mit Zusatz „Verblendung“ (`Materialzusatz.verblendung`), nicht in der Stückliste (Fachkonzept 08).
- **Blendenhalter (R-C05):** je verblendeter Seite im UK-Achsabstand (wirksame Feldbreite) plus eins, so lang wie die Terrassenhöhe dort (F37: 9 + 13 + 9 = 31 à 8,6 cm), beim Kreis ohne das eine. Sie stehen als UK-Stücke in der Stückliste und werden zuerst aus den Resten der UK-Hölzer geschnitten (`zusaetzlicheLieferstuecke`) – F37 wie im alten Planer ohne weiteres UK-Holz (13 × 4000 mm). Ohne UK-Verlegung keine Halter.
- **Hinweise vom Server** (`Anschlussmeldung`): Unterlüftung, wenn alle freien Seiten verblendet sind (F37, Kreis immer); kein Höhenunterschied, wenn die Höhe einer Seite die Dielenstärke nicht übersteigt (dort kein Material); Belagstärke außerhalb 19–23 mm; kein Verblendungsartikel.
- Annahmen (offen für Alexander): Blendenhöhe = Höhe minus Dielenstärke (bei 8,6 cm eine Reihe 80 mm wie F37); die Blendenhalter so lang wie die ganze Höhe wie in F37; „kein Höhenunterschied“ als Höhe ≤ Dielenstärke.

## 4.3 An welchen Seiten sollen Entwässerungsrinnen geplant werden?

- Schalter je Seite, danach Auswahl der Lage:
  - Gesamte Seite (innen) – Vorgabe
  - im bodentiefen Element
  - außerhalb des bodentiefen Elements
  - nur vor dem bodentiefen Element
- Produktkarte „RELO V Ventilationsprofil, Einzelstück(e)“.
- Lage und bodentiefes Element sind **fest im Artikel verankert**: Rinnen werden nur an den Seiten verbaut, als Ventilationsprofil oder Entwässerungsrinne; die Lageauswahl wählt die Artikelvariante.
- Beispiel C — D (480 cm), gesamte Seite: Fläche 14,832 → 14,256 m² (Rinne 12 cm breit), + Ventilationsprofil, + Auflagerprofil, weniger Dielen → 2.421,13 €.
