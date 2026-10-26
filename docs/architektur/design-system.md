# Design-System und App-Rahmen (M3-01)

Eigenes Design-System der Planer-Oberfläche – funktional wie der alte Planer (Fachkonzept 00), gestalterisch eigenständig.

## Bausteine (`packages/app/lib/src/design/planer_design.dart`)

| Baustein | Werte |
|---|---|
| Farben `PlanerFarben` | Braun `#B0864B` (Primärfarbe), Grün `#95C11C` (aktiver Schritt, Fortschritt, Menügriff), Sand `#F5F0E8` (Leisten), Text `#3A3A3A`, Linie `#DCDCDC` – wie der Ladebildschirm |
| Abstände `PlanerAbstand` | 8 / 16 / 24 px |
| Breakpoints `PlanerLayout` | Tablet ab 600 px, Desktop ab 1024 px; Menübreite 320 px |
| Schrift | Roboto Regular/Medium/Bold, **mitgeliefert** (`assets/schriften/`, Apache-2.0) – der Browser lädt keine Schriften von Google-Servern |
| Thema `planerThema()` | Material 3 aus der Primärfarbe, Karten weiß; Dunkelmodus folgt mit M3-09 |

## Rahmen (`packages/app/lib/src/rahmen/`)

- **Kopfzeile:** RobinienWelt-Logo (`assets/bilder/robinienwelt_logo.png`, aus dem SVG des Ladebildschirms gerendert) und „TERRASSENKONFIGURATOR“. Speichern, Laden, Zurücksetzen, Anmelden, Video-Beratung kommen mit ihren Issues (M3-03, M3-06, M9).
- **Schrittleiste:** sieben Stationen (`PlanerSchritt`), frei anklickbar; aktiv grün, besucht braun, offen grau; Fortschrittsbalken = Anteil besuchter Stationen. Auf schmalen Stationen (< 160 px) werden lange Titel getrennt („UNTER-/KONSTRUKTION“).
- **Bearbeitungsmenü:** „1. GRUNDRISS“ … „7. VERSCHNITTOPTIMIERUNG“, der aktive Schritt zeigt seine nummerierten Unterpunkte (1.1 …); Inhalte folgen in M4–M8. Grüner Griff klappt das Menü ein und aus – auf dem Desktop neben, auf dem Tablet über der Zeichenfläche (dort anfangs eingeklappt).
- **Zeichenfläche:** Raster; Zeichnen, Zoom und Verschieben folgen mit M3-03/M4. Rechts oben **Kennzahlen** Fläche und Volumen (Werte ab M4/M5 vom Server).
- **Statuszeile:** Verbindung zum Server.
- `RahmenZustand` hält nur Bedienzustand (aktiver Schritt, besuchte Stationen, Menü) – keine Fachdaten.

Texte stehen noch als Konstanten im Code; M3-07 verschiebt sie in Übersetzungsdateien.

## Eingangsdialog (M3-02, `lib/src/start/eingangsdialog.dart`)

Beim Start liegt der Dialog über dem Rahmen (nicht durch Tippen daneben schließbar): Logo, „Willkommen beim RobinienWelt Terrassenkonfigurator!“, kurzer Einführungstext und drei Wege:

1. **WUNSCHTERRASSE KONFIGURIEREN** – schließt den Dialog.
2. **KONFIGURATION LADEN** – Konfigurationsnummer (`JJJJ-MM-TT-NNNN`, Datum wird geprüft – `Konfigurationsnummer` im domain-Paket) und Version (−/+, ab 1); Laden über den Server folgt mit M9-05, bis dahin meldet der Dialog „Die Konfiguration konnte nicht geladen werden.“
3. **WEITERPLANEN** – nur wenn eine zwischengespeicherte Konfiguration gefunden wurde („Wir haben eine Konfiguration gefunden …“); den Browser-Zwischenspeicher liefert M3-09.

Laden und Suche nach einer zwischengespeicherten Konfiguration sind Funktionen, die `PlanerApp` übergeben bekommt – die App selbst speichert nichts.

## Zeichenfläche und Verlauf (M3-03)

- **Zoom und Verschieben** (`AnsichtSteuerung`, ein `TransformationController`): Mausrad und Zwei-Finger-Geste über `InteractiveViewer`, Knöpfe −/+ (Faktor 1,25) und Regler (logarithmisch 25 %–400 %) zoomen um die Mitte der Fläche; Ziehen verschiebt; **Zentrieren** setzt auf 100 % und den Ursprung. Das Raster (`RasterMaler`) folgt Zoom und Verschiebung. Die Ansicht gehört nicht zur Planung und steht daher nicht im Verlauf.
- **Rückgängig/Wiederherstellen** (`PlanungsSteuerung` über `Verlauf<Planungsstand>` im domain-Paket): Der Verlauf speichert unveränderliche Stände (bis 200 Schritte); Rückgängig liefert exakt das vorherige Objekt zurück, ein neuer Stand nach Rückgängig verwirft die wiederherstellbaren. `Planungsstand` ist noch leer – ab M4 kommen Grundriss, Belag usw. hinzu. Die Knöpfe sind ausgegraut, solange es nichts zurückzunehmen gibt.
- **Zurücksetzen** (Kopfzeile) fragt immer nach (Text aus Fachkonzept 08, Rechtschreibung korrigiert: „Sind Sie sicher … Ihr Fortschritt …“); nur „Konfiguration zurücksetzen“ leert Planung und Verlauf und zentriert die Ansicht, „Zurück zur Konfiguration“ oder Tippen daneben ändert nichts.
- Benchmark `domain.Verlauf.aendernRueckgaengig`: 500 Änderungen, alles rückgängig und wieder hergestellt ≈ 0,9 ms.

## Ansichtsoptionen und Draufsicht (M3-04)

- **Ebenen** Belag | UK | Maße als Mehrfach-Schalter in der Werkzeugleiste, **Beschriftungen** Seitenlängen, Winkel, Punkte, Abläufe als Menü mit Häkchen (`AnsichtsOptionen`, anfangs alles an). Jede Änderung zeichnet sofort neu (`ZeichnungsMaler` hört auf Optionen und Ansicht).
- **Zeichnung** (`Zeichnung`): Umriss (Eckpunkte in mm), Bauteile (Quader aus dem Geometriemodell, M3-10) und Abläufe – fertig vom Server berechnet; die App zeichnet nur (1 m = 100 px bei 100 %). Bis M4 ist die Zeichnung leer.
- Unterkonstruktion liegt unter dem Belag; ohne Belag sieht man die UK. Maße = Gesamtbreite und -tiefe neben dem Umriss.
- Beschriftungen: Eckpunkte A, B, C … außen an der Ecke, Innenwinkel innen (auch einspringende Ecken, 270°, unabhängig von der Umlaufrichtung), Seitenlängen in cm außen neben der Kantenmitte; jeder Text liegt nach seiner eigenen Größe vollständig neben der Linie.
- Auf schmalen Flächen (< 1000 px) entfallen Zoom-Regler und Bedienhinweis in der Werkzeugleiste.

## Hinweis bei Standardwerten (M3-05)

- `RahmenZustand` merkt sich, in welchen Schritten der Kunde eine Eingabe **geändert** hat (`markiereGeaendert`, ab M4 von den Eingabefeldern aufgerufen); Ansehen allein zählt nicht (Vorgabe Alexander 26.10.2026). Zurücksetzen vergisst alle Änderungen.
- `pruefeStandardwerte` wird **vor Ergebnis und Angebot** aufgerufen (Materialliste, PDF, „Konfiguration anfordern“ – M3-06, M9): Gibt es Schritte ohne Änderung, listet `StandardwertHinweis` sie in Schrittreihenfolge („• 3. UNTERKONSTRUKTION“); „Fortfahren“ geht weiter, „Zurück“ (oder Tippen daneben) öffnet den ersten unveränderten Schritt. Ohne solche Schritte erscheint kein Hinweis.

## Prüfung

Widget-Tests für Desktop (1440 × 900) und Tablet (768 × 1024) ohne Überlauf; Smoke-Test `integration_test/rahmen_test.dart` erreicht in Chrome alle sieben Stationen.
