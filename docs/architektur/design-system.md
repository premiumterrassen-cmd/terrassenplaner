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

## Prüfung

Widget-Tests für Desktop (1440 × 900) und Tablet (768 × 1024) ohne Überlauf; Smoke-Test `integration_test/rahmen_test.dart` erreicht in Chrome alle sieben Stationen.
