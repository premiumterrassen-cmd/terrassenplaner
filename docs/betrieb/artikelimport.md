# Artikelimport (M2-02)

Die Artikel des Planers kommen aus der **Upload-Datei** der Master-Artikelliste – derselben Datei, die Alexander auch in den alten Konfigurator hochlädt (B-218), z. B. `Analyse Claude/Terrassenplaner/Terrassenplaner_Import_2026-10-14_v6.xlsx`, Blatt „Import Terrassenplaner“.

```bash
cd packages/server
dart run bin/artikel_importieren.dart <upload.xlsx> <artikel.json>
```

Der Importer schreibt einen Prüfbericht (FEHLER/Hinweis mit Excel-Zeile und Spalte) und – nur ohne kritische Befunde – die Artikeldatei als JSON mit Quelle und Versionskennung (Prüfsumme des Inhalts).

## Regeln

- **Nur Werte:** Die Master-Artikelliste selbst enthält im Blatt „Import Terrassenplaner“ nur Formeln ohne gespeicherte Werte – der Importer bricht dann mit einem Hinweis auf die Upload-Datei ab.
- **Whitelist:** gelesen werden nur die Planer-Spalten (Nummer, Titel, Typ, Einheit, Preis, Maße, Abbildungen, Verweise, Abstände). Einkaufsdaten werden nie gelesen (B-020), die Spalte `marke` (Fertiger der Eigenmarken) ebenfalls nicht (B-023).
- **Maße:** Die Spalten heißen `_cm`, enthalten aber Millimeter. Werte unter 1 mm werden nicht übernommen (Hinweis).
- **Holz:** Holzart und Serie werden aus dem Titel erkannt (Robinie; BASIC, ECO SELECT, PREMIUM SELECT, MASSIV); Profil aus „genutet/glattkant“ bzw. „sichtbar/unsichtbar befestigt“, Oberseite aus „bombiert“.
- Die Spalte „Gewicht“ enthält die Rohdichte (750) und wird nicht als Artikelgewicht übernommen – die Rohdichte steht in der Holzart.
- **Die Artikeldatei gehört nicht ins Repository:** Artikelnummern der Fremdartikel sind EANs (B-155). `.gitignore` schließt `artikel*.json` im Wurzelverzeichnis und im Server-Paket aus.

## Stand 20.10.2026 (Upload-Datei v6)

241 Artikel ohne Fehler importiert, ein Hinweis: Zeile 42 (Unkrautvlies) Stärke 0,1 mm nicht übernommen. Auffällig für die Datenprüfung (M2-03): Speedfix-Flügelbohrschraube 5,5 × 60 mm hat als Länge 45 eingetragen.
