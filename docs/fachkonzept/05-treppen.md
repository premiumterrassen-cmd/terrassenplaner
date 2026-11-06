# 05 Treppen

## 5.1 An welchen Seiten sollen Treppen geplant werden?

„Treppe Hinzufügen“ legt einen Block „Treppe 1“ an (ein-/ausklappbar, weitere Treppen möglich).

| Feld | Inhalt |
|---|---|
| Start | Auswahl einer Seite – nur freie Seiten (nicht an Bauelement, nicht mit Rinne; verblendete Seiten sind erlaubt) |
| Seite | Abstand vom Startpunkt der Seite in cm (Vorgabe 0) |
| Breite | cm (Vorgabe 100) |
| Konstruktionsart | Fundament \| Konstruktion (Vorgabe Konstruktion) – Fundament: Betontreppe vorhanden, wird nur belegt; Konstruktion: der Planer erstellt und berechnet die Treppe konstruktiv |
| Treppenart | Reguläre Treppe \| 2-teilige Fächertreppe \| 3-teilige Fächertreppe |
| Individuelle Stufenmaße? | Ja \| Nein (Vorgabe Nein) |
| Anzahl der Stufen | −/+ (Vorgabe 2) |
| Stufenmaße | Tiefe 27 cm, Höhe 15,6 cm |
| Podestmaße | nur Fächertreppe: Tiefe 50 cm, Breite, Höhe 15,6 cm |
| Anzeige | „Treppenmaße in cm (L x B x H)“ |

- Reguläre Treppe 100 cm an D — A: Treppenmaße 100 × 54 × 31,2; zusätzliche UK und Dielen (4000 mm), Volumen 0,429 → 0,466 m³, Summe +135,48 €.
- 2-teilige Fächertreppe: Treppenmaße 104 × 108 × 46,8.
- Die Treppe erscheint in der Zeichnung an der gewählten Seite, mit Stufenlinien.
- Treppenhöhe unabhängig von der Terrassenhöhe ist gewollt: teilweise sind andere Bauteile vorhanden, die nicht mitgeplant werden.

## Umsetzung (M7-05)

- Unterpunkt 5.1 mit „Treppe hinzufügen“ (Block „Treppe 1“, weitere möglich, entfernen per Knopf). Felder wie oben; die Breite gilt nur für die reguläre Treppe, die Podestmaße nur für die Fächertreppe; „Individuelle Stufenmaße? Ja“ zeigt Tiefe und Höhe je Stufe (von oben), die gemeinsamen Maße bleiben erhalten. Grenzen: Abstand 0–300 m, Breite und Podest 10–1000 cm, Tiefe 5–100 cm, Höhe 1–50 cm, 1–20 Stufen. Planungsstand `treppen` (Platz 142), eine neue Eckenzahl setzt sie wie den Anschluss zurück.
- **Start:** zur Wahl stehen nur freie Seiten (nicht am Bauelement, ohne Rinne; verblendete erlaubt). Wird eine Seite später belegt, bleibt die Treppe stehen, wird aber nicht gerechnet (Hinweis `treppeNichtFrei`).
- **Treppenmaße (Server, `Treppe.masse`):** regulär Breite × Σ Tiefen × Σ Höhen (100 × 54 × 31,2 wie F39); 2-teilige Fächertreppe Podesttiefe + Σ Tiefen × Podestbreite + Σ Tiefen × Podesthöhe + Σ Höhen (104 × 108 × 46,8 wie F41); 3-teilige Podesttiefe + 2 Σ Tiefen × … (158 × 108 × 46,8 wie F42). Vorgabe Podest 50 × 54 × 15,6 cm (F41).
- **Zeichnung (`treppenumrisse`):** außen vor der Seite ab dem Abstand; reguläre Stufen als Streifen, bei der Fächertreppe das Podest an der Seite und die Stufen als L (2-teilig) bzw. U (3-teilig) darum – jede Stufe ein eigener Umriss, so entstehen die Stufenlinien.
- **Material (`treppenstuecke`, `treppenbedarf`):** Dielen des Belags je Auftrittsstreifen in Streifenlänge, so viele Reihen wie Diele + Fuge die Tiefe brauchen (27 cm → 5), dazu Setzstufen je sichtbarer Vorderkante (15,6 cm → 3 Reihen) – F39: 16 × 100 cm wie im alten Planer. Die Dielen stehen in Stück- und Materialliste (Lieferlängen wie `lieferstuecke`, erzwungene Dielenlänge gilt). UK quer zu den Dielen unter jedem Auftritt im UK-Achsabstand (beide Enden), so lang wie die Tiefe; bei **Konstruktion** zusätzlich je UK-Holz eine Stütze an der Vorderkante bis zum Boden (Oberkante − Dielenstärke − UK hochkant), bei **Fundament** keine Stützen – die UK liegt auf der Betontreppe (R-D02; F40 = F39 im alten Planer ist ein Fehler). Die UK-Zuschnitte werden mit den Blendenhaltern zuerst aus den Resten der UK-Hölzer geschnitten (`anschlussbedarf`). Befestigung der Treppendielen rechnet der Planer nicht (F39: Clips/Schrauben unverändert).
- **Abweichung von F39–F42 (begründet):** Der alte Planer rechnet für F39 12 × 100 + 44 cm UK zusätzlich (UK 13 × 4000 → 12 × 4500 + 1 × 4000) und Dielen 4 × 4000 mm; seine Konstruktionsregel ist aus den Exporten nicht ableitbar. Der neue Planer rechnet die oben beschriebene, nachvollziehbare Konstruktion (F39: 8 × 27 + 4 × 23,1 + 4 × 7,5 cm UK, aus den Resten der 13 UK-Hölzer, also ohne weiteres UK-Holz; Dielen 16 × 100 cm in den Lieferlängen des Belags). Offene Frage an Alexander: Konstruktionsregel der Treppe (Wangen/Stützen, Stärke der Setzstufen) und ob Treppendielen befestigt werden.

