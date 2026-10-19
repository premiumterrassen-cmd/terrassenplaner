# 12 Referenzkonfigurationen (M1-03)

43 gezielt eingestellte Konfigurationen im alten Planer (19.10.2026, Mitarbeiter-Ansicht, 1440 × 900). Testdaten liegen in `packages/domain/test/referenzkonfigurationen/F01.json` … `F43.json` (Modell `Referenzkonfiguration` im domain-Paket), daneben die 47 echten Fälle aus M1-02 ([11](11-referenzfaelle.md)).

## Vorgehen

- **F01 = Startkonfiguration** des alten Planers: Rechteck 480 × 309 cm, Terrassendiele Robinie 60 x 22 mm genutet/bombiert, Dielenlänge automatisch, Fugenschnitt, waagrecht, Ausgangspunkt A, UK Holz 40 x 60 mm, normale Terrasse 8,6 cm, Schotter, schwimmende Verlegung, privat.
- Jeder weitere Fall verstellt **eine Option** (Ausnahmen: F09–F14 auf 800 cm Länge, F37/F38 bauen auf F36 auf, F40–F42 auf F39). `eingaben` enthält immer die vollständige Konfiguration, `beschreibung` die Abweichung und Befunde.
- Je Fall gespeichert: angezeigte Kennzahlen (Fläche, Verschnitt, Volumen, ggf. Treppenmaße), die **Materialliste** aus „CSV-Download“ und die **Zuschnittliste**. Beide Dateien sind die ERP-Importdateien (siehe [08](08-ergebnisse.md#mitarbeiter-ansicht-und-erp-exporte)).
- **Nicht übernommen:** Preise (Netto/Brutto, Summe), Bild-Links, Beschreibungstexte und Herstellernummern (EAN → `artikelnummer: null`, B-023). Ein Test prüft das für jede Datei.

## Fälle

| Fall | Abweichung von F01 | Fläche m² | Verschnitt % | Volumen m³ |
|---|---|---|---|---|
| F01 | Startkonfiguration | 14,832 | 4 | 0,435 |
| F02 | Verlegerichtung senkrecht | 14,832 | 22,75 | 0,499 |
| F03 | diagonal 45° | 14,832 | 2,2 | 0,457 |
| F04 | diagonal 135° | 14,832 | 0,32 | 0,462 |
| F05 | individueller Winkel 30° | 14,832 | 3,76 | 0,473 |
| F06 | Halbverband | 14,832 | 4 | 0,445 |
| F07 | Drittelverband | 14,832 | 4 | 0,454 |
| F08 | Wechselverband (= F01) | 14,832 | 4 | 0,435 |
| F09 | 800 × 309, Fugenschnitt | 24,72 | – | 0,713 |
| F10 | 800 × 309, Halbverband | 24,72 | – | 0,742 |
| F11 | 800 × 309, Drittelverband | 24,72 | – | 0,732 |
| F12 | 800 × 309, Wechselverband | 24,72 | – | 0,722 |
| F13 | 800 × 309, Dielenlänge fest 400 cm | 24,72 | – | 0,673 |
| F14 | 800 × 309, erste Diele 3 cm versetzt | 24,72 | 0,14 | 0,677 |
| F15 | L-Form (Vorgabemaße) | 10,26 | 7,31 | 0,305 |
| F16 | T-Form | 6,84 | 0,96 | 0,196 |
| F17 | U-Form | 6,84 | 1,74 | 0,194 |
| F18 | O-Form 360 × 380, Ausschnitt 113 × 190 | 13,68 | 0,54 | 0,329 |
| F19 | Kreis Ø 360 | 10,15 | 7,44 | 0,340 |
| F20 | Rechteck 360 × 400 | 14,4 | 10 | 0,443 |
| F21 | F20 + Ausschnitt 120 × 133 (leere Fläche) | 14,4 | 4,36 | 0,385 |
| F22 | F21, Ausschnitt mit anderem Belag | 14,4 | 4,36 | 0,434 |
| F23 | Belag 80 x 26 mm genutet/bombiert | 14,832 | 4 | 0,499 |
| F24 | Belag 100 x 22 mm glattkant (sichtbar befestigt) | 14,832 | 4 | 0,455 |
| F25 | Holzfliese ROBI-FIXX | 14,832 | 0,99 | – |
| F26 | UK Holz 45 x 60 mm | 14,832 | 4 | 0,451 |
| F27 | UK ALUecofix M 45x23 mm blank | 14,832 | 4 | 0,364 |
| F28 | Hochterrasse (54,2 cm) | 14,832 | 4 | 0,579 |
| F29 | Vorhandene UK (Spannweite 80 cm) | 14,832 | 4 | 0,459 |
| F30 | Gefälle A = B = 15, C = D = 8,6 cm | 14,832 | 4 | 0,435 |
| F31 | Versteifung ohne Rahmen | 14,832 | 4 | 0,454 |
| F32 | Rahmen | 14,832 | 4 | 0,459 |
| F33 | Versteifung mit Rahmen | 14,832 | 4 | 0,478 |
| F34 | doppelte Unterkonstruktion | 14,832 | 4 | 0,543 |
| F35 | gewerbliche Nutzung | 14,832 | 4 | 0,435 |
| F36 | Bauelement an A–B | 14,832 | 4 | 0,435 |
| F37 | F36 + Verblendung B–C, C–D, D–A | 14,832 | 4 | 0,458 |
| F38 | F37 + Rinne A–B (gesamte Seite innen) | 14,256 | 4 | 0,445 |
| F39 | Treppe an C–D, regulär, Konstruktion | 14,832 | 3,74 | 0,471 |
| F40 | F39 mit Fundament | 14,832 | 3,74 | 0,471 |
| F41 | 2-teilige Fächertreppe | 14,832 | 3,43 | 0,516 |
| F42 | 3-teilige Fächertreppe | 14,832 | 3,31 | 0,552 |
| F43 | Verschnittvariante 2 | 14,832 | 12,73 | 0,466 |

„–“: nicht erfasst (F09–F13) bzw. nicht angezeigt (Holzfliese ohne Volumen).

## Befunde (als Tests festgehalten)

Der alte Planer hat Fehler, die **nicht übernommen** werden (Alexander, 19.10.2026). Fälle mit bekanntem oder vermutetem Fehler tragen in `fehlerverdacht` eine Begründung (`istSollwert == false`): F14, F25, F40. Liste in [09](09-nicht-teil-der-kopie.md#fehler-und-verdachtsfälle-aus-den-referenzkonfigurationen-m1-03), Antworten 13–17 in [10](10-offene-fragen.md). Die Tests halten das Verhalten des alten Planers fest – nicht das Soll.

**Artikel sind Altsortiment:** Die Materiallisten zeigen das veraltete Sortiment des Online-Planers (z. B. einseitig genutete Anfangsdielen, KOPPLEX, „22 mm“). Sie gelten als Beispiel für Struktur und Mengenlogik, nicht als Soll-Sortiment – im neuen Planer gelten die Artikel der Master-Artikelliste (siehe [09](09-nicht-teil-der-kopie.md#veraltetes-sortiment-im-alten-planer)).


- **Fläche** = Kantenprodukt; leere Ausschnitte werden nicht abgezogen (F18, F21). Nur eine **Entwässerungsrinne** verkleinert die Fläche (F38: −0,576 m² = 480 × 12 cm).
- **Ohne Wirkung auf die Exporte:** Wechselverband bei 480 cm (F08 = F01), Bauelement allein (F36 = F01), Treppen-Konstruktionsart Fundament gegenüber Konstruktion (F40 = F39 – **Fehler**, siehe oben).
- **Gewerbliche Nutzung** ändert nur die Menge KOPPLEX-3 (2 → 3 Rollen), nicht den UK-Abstand – gewollt (Marketing, Antwort 13).
- **Verblendung:** 31 Blendenhalter à 8,6 cm aus dem UK-Zuschnitt (F37), Verblendungsdielen 80 x 22 mm glattkant nur in der Materialliste, nicht in der Zuschnittliste. Bei Verblendung aller freien Seiten erscheint „Achtung: Bitte beachten Sie, dass eine Unterlüftung der Terrasse gewährleistet sein muss!“.
- **Rinne:** Auswahl „Gesamte Seite (innen)“, „Im bodentiefen Element“, „außerhalb des bodentiefen Elements“, „nur vor dem bodentiefen Element“; Artikel RELO V Ventilationsprofil + RELO VA Auflagerprofil. Die UK bleibt 309 cm lang – richtig: sie geht bis 1–2 cm vor die Hauswand, darunter liegen die Auflageprofile, darauf die Ventilationsprofile (Antwort 14).
- **Terrassenanschluss:** Eine Seite kann nur eine Rolle haben – als Bauelement oder Verblendung gewählte Seiten verschwinden aus der jeweils anderen Auswahl; die Rinne bleibt an Bauelement-Seiten wählbar.
- **Hochterrasse:** Standardhöhe 54,2 cm, UK-Stützen à 39,9 cm, Bodenanker; Abschnitt „Art der Terrassennutzung“ entfällt. **Vorhandene UK:** zusätzliches Feld Spannweite (80 cm), Höhe 14,2 cm, ebenfalls ohne Nutzungsart.
- **Gefälle (F30):** Justierkeile, GUMO-Unterleger und ROBI-LIFT-Füße kommen dazu.
- **Automatische Dielenlänge** geht über 600 cm hinaus (F14: Dielen 7000 mm, UK 6500 mm).
- **UK ALUecofix** setzt die UK-Länge auf 400 cm und bringt Stelzlager mit.
- **Treppe:** Standard 2 Stufen à 27 × 15,6 cm, Breite 100 cm; Maße regulär 100 × 54 × 31,2, 2-teilig 104 × 108 × 46,8, 3-teilig 158 × 108 × 46,8 cm. Die Treppenhöhe hängt nicht an der Terrassenhöhe (siehe [10](10-offene-fragen.md)).
- **Verschnittoptimierung** bietet drei Varianten (4 % / 46 × 500 cm, 12,73 % / 46 × 550 cm, 20 % / 46 × 600 cm).
- Bedienung: Nach „Zurücksetzen“ sind die Abschnitte 4–7 gesperrt, bis die vorigen einmal geöffnet wurden.

## Lücken

- **Rundungen** und **Freiform** nicht nachgestellt – Freiformen sind in 13 echten Fällen aus M1-02 enthalten, Rundungen in keinem.
- **Querstreben** ließen sich im Bearbeitungsmodus nicht setzen (Klick zeigt nur eine Vorschau, „Änderungen übernehmen“ ändert nichts). Regel laut Alexander: Abstand 60 cm.
- Nicht einzeln erfasst: individuelle Stufenmaße, weitere Ausgangspunkte, Untergrund-Varianten (laut Alexander nur Information), manuelle Zubehör-Mengen („Tatsächlich“).
