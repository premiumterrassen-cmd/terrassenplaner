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
