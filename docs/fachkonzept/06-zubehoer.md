# 06 Zubehör

Akkordeon mit acht Kategorien; es ist immer nur eine geöffnet. Jede Kategorie zeigt eine Tabelle „Bezeichnung | Tatsächlich“ mit Bild, Artikelname und Mengenfeld. „Tatsächlich“ startet mit dem vom Planer berechneten Wert und lässt sich ändern; der geänderte Wert erscheint im finalen Angebot **unter** dem berechneten Wert des Planers.

| Kategorie | Inhalt (Altsystem, Referenz) |
|---|---|
| 1. Allgemein | Schutz-Vlies, Bits für Clipschrauben, Arbeitshandschuhe, Montagehilfen, Bohrsenker, Abstandshalter 4/7 mm, Auflagerprofil, Stabilisierungsplatte |
| 2. Anlieferung | „Anlieferung mit kleinerem Maschinenfahrzeug (handentladung)“ |
| 3. Clips & Schrauben | Clip- und Terrassenschrauben, Bohrschrauben, CLIP-FIXX (VPE 50/100/250), DUO-CLIP-FIXX, Edelstahl-Clip |
| 4. Höhenausgleich | Justierkeile (14–22, 18–32, 26–40 mm), Terrassenfüße ROBI-LIFT (35–135 mm), Stelzlager (11–570 mm), Unterleger 2/5/8 mm, Gefälleausgleichsscheibe |
| 5. Pads & EPDM Bänder | KOPPLEX-1/-3, Weich-, Gummi- und Schaumpads |
| 6. Rhombusleisten | (leer) |
| 7. Terrassenfliesen | Terrassenfliese Robinie (natur/vorgeölt), Verbinder |
| 8. Terrassenöl RIBOL | Schutzöl, COLOR in 20 Farbtönen (2,5 l und 0,75 l), Farbton Robinie |

Das Sortiment kommt im neuen Planer aus der Master-Artikelliste („im Planer = ja“, B-122). Hersteller der Eigenmarken nie nennen (B-023).

## Neuer Planer (M8-01)

- **Gruppen aus den Artikeldaten:** Die Spalte `Zubehoergruppe` der Upload-Datei ordnet jeden Artikel einer der acht Gruppen zu (`Zubehoergruppe` im domain-Paket, Reihenfolge wie oben). Reines Zubehör (Artikeltyp `Zubehoer`) ohne Eintrag gehört wie im alten Planer zu „Allgemein“ (Bits, Handschuhe, Schutz-Vlies, Montagehilfen, Bohrsenker, Abstandshalter, Stabilisierungsplatte). Ein unbekannter Gruppenname ist beim Import ein Hinweis; der Artikel erscheint dann nicht im Schritt Zubehör.
- **Reihenfolge der Artikel** wie in der Upload-Datei (B-122). Gruppen ohne Artikel bleiben stehen und zeigen „In dieser Gruppe gibt es keine Artikel.“ (Rhombusleisten).
- Der Artikeldienst liefert die Auswahl über `kunde.zubehoer.auswahl`; die App zeigt sie nur an.
- **Akkordeon:** Beim Öffnen des Schritts ist „Allgemein“ offen; eine andere Gruppe schließt die offene, ein zweiter Klick auf die offene schließt alle.
- **Tatsächlich:** Das Feld zeigt die aktuelle Menge als Platzhalter (wie die Maßfelder). Enter übernimmt eine ganze Zahl von 0 bis 99 999 Verkaufseinheiten, ein leeres Feld nimmt die Eingabe zurück. Gespeichert wird nur die Eingabe, je Fläche (`Planungsstand.zubehoer`, mit Rückgängig); ohne Eingabe gilt der berechnete Wert (ab M8-02, vorher 0). Die Mitarbeiter-Ansicht mit änderbaren Mengen der Materialliste gehört zu M9.

## Neuer Planer (M8-02): automatische Mengen

Der Planungsdienst rechnet je Fläche die Menge jedes Zubehörs (`berechnetesZubehoer`, `Berechnung.zubehoer`, Platz 50); „Tatsächlich“ startet damit, eine Eingabe geht vor, und die Zeile zeigt darunter „berechnet: X“, solange beides abweicht. Die Artikel kommen aus den Verweisen der Artikeldaten (`moeglichesZubehoer`, `moeglicheBefestigungDeck`, B-122) – keine Artikelnummern im Code.

| Zubehör | Regel | Abgleich alter Planer |
|---|---|---|
| Clips & Schrauben, Montagehilfe | aus der Befestigung (M5-09, B-094, B-090, B-074) übernommen, nicht doppelt gerechnet | wie M5-09 (F01: 637 Clips) |
| Bit TX25 (Allgemein) | eines bei Verschraubung, bei Clips keines; der erste Werkzeug-Artikel mit „Bit TX25“ im Titel | F24: 1 Bit, F01: keines |
| Gummiband (Pads & EPDM-Bänder, R-C04, B-039) | das erste Band mit Rollenlänge aus dem Zubehör des Belags; Bedarf = Länge der Unterkonstruktion unter den Dielen (Fugen überbrückt), je Verkaufseinheit Rollenlänge × Rollen laut Titel („10 Rollen à 10 m“) | mit 10-m-Rollen wie KOPPLEX-1: F01 5, F02 5, F09 7, F20 4 Rollen – gleich |
| Terrassenöl RIBOL (R-D05, B-221) | die erste Sorte aus dem Zubehör des Belags, 0,2 l je m² Belagfläche (Länge × Breite samt Fuge je Stück), Gebinde laut Titel („2,5 Liter“, „0,75 Liter“) mit möglichst wenig Überhang, dann möglichst wenigen Gebinden (`verpackt`) | der alte Planer rechnet kein Öl (alle F-Fälle ohne) – neue Regel |

- **Übergangs-UK:** Solange die Unterkonstruktion fehlt (M6), liegt sie wie bei der Befestigung gleichmäßig quer zur Verlegerichtung im Abstand `Abstand_UK` des Belags, höchstens 40 cm (R-C01, `uebergangsUk`). Mit M6 rechnen Gummiband, Unterlegpads, Stellfüße, Justierkeile und Bodenanker aus der echten UK.
- **Noch nicht automatisch** (Menge 0, nur Eingabe): Unterlegpads und Höhenausgleich (hängen an UK und Aufbau, M6), Anlieferung (Wahl des Kunden), Schutz-Vlies, Handschuhe, Montagehilfe-Set, Verbinder für Holzfliesen (F25 ist Fehlerverdacht).
- **Benchmark** `domain.Zubehoer.berechnetesZubehoer` (12 × 8 m, waagrecht und 45°, Halbverband): lokal 14,4 ms je Durchlauf (Vorwert in `benchmarks/baseline-lokal.json`).

## Neuer Planer (M8-03): Pflichtzubehör

- **Quelle:** Spalten `benoetigtesZubehoer` und `benoetigtesZubehoer_anzahl` der Upload-Datei (B-122) – feste Anzahl je Artikel (`pflichtzubehoer`). Gezählt wird je verwendetem Artikel: der Belag je Diele, Befestigung und Zubehör je Verkaufseinheit „Tatsächlich“. Was ein Pflichtartikel selbst benötigt, kommt dazu (höchstens fünf Stufen, ein Kreis in den Daten rechnet nicht endlos).
- **Menge:** Das Pflichtzubehör zählt zur berechneten Menge (Zubehör, das schon automatisch gerechnet wird, plus Pflicht). „Tatsächlich“ kann nicht unter die Pflichtmenge sinken: die App lehnt eine kleinere Eingabe mit „Pflichtzubehör: mindestens X“ ab, der Server rechnet ohnehin mit mindestens der Pflichtmenge. Die Zeile trägt ein Schloss und „Pflichtzubehör, mindestens X“.
- **Pflichtartikel ohne Zubehörgruppe** (z. B. Halter einer Entwässerungsrinne) stehen nicht im Schritt Zubehör, bleiben aber in der Berechnung (`Berechnung.zubehoer`) für die Materialliste.
- **Stand der Daten:** In der Upload-Datei haben bisher nur die Entwässerungsrinnen benötigtes Zubehör; die Rinnen kommen mit M7. Belag, Befestigung und Zubehör werden schon jetzt berücksichtigt, sobald die Daten es angeben.
