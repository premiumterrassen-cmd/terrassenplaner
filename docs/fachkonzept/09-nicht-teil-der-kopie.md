# 09 Nicht Teil der Kopie

## Im alten Planer abgeschaltete Funktionen

In der Oberfläche vom 08.10.2026 nicht vorhanden. **Seit 19.10.2026 überholt:** Die neue Planer-Version hat 3D, Grundriss-Upload, Podest und Gehrungsschnitte – sie sind damit Ziel-Funktionen (siehe [13](13-neue-planer-version.md)); Auswahl durch Alexander.

| Funktion | Befund |
|---|---|
| 3D-Ansicht | kein Schalter, nur Draufsicht (Ebenen Belag/UK/Maße) |
| Grundriss-Upload (Bild/Plan hinterlegen) | keine Upload-Möglichkeit in Schritt 1 |
| Podest (eigene Terrassenebene) | nicht vorhanden; nur „Podestmaße“ als Teil der Fächertreppe (Schritt 5) |
| Gehrungsschnitt (Belag an Ecken auf Gehrung) | keine Option in Schritt 2 |
| Rhombusleisten | Zubehörkategorie vorhanden, aber leer |

## Fehler des Altsystems – nicht nachbauen

Grundsatz (Alexander, 19.10.2026): Der alte Planer hat Fehler; sie werden **nicht 1:1 übernommen**.

- Aus der **Freiform** kommt man über die Formauswahl nicht zurück; die Formknöpfe reagieren nicht, nur ZURÜCKSETZEN hilft.
- Eingabefeld X eines Ausschnitts zeigt nach der Eingabe abgeschnitten „20:cm“.
- **Holzfliesen** mit „Preis per lfm“ statt Preis je Stück.
- Abgeschnittener Produkttitel („… keilgezinkt, BOM“), Zusatz „UK geliefert in 40mm breite“ in Belagsbeschreibungen.
- Uneinheitliche Zahlenformate: „Verschnitt: 7.44%“ (Punkt) neben „10,150 m²“ (Komma); „Fuge: 0.5 mm“.
- „Länge der Unterkonstruktion“ bietet nur 600 cm an, die Materialliste nimmt aber andere Längen.
- „Fuge: 0.5 mm“ statt 5 mm.
- **SPEICHERN** legt ohne Rückfrage eine Konfiguration auf dem Server an.
- Die Materialliste zeigt keine Mengen, nur Gesamtpreise.

## Fehler und Verdachtsfälle aus den Referenzkonfigurationen (M1-03)

In den Testdaten als `fehlerverdacht` markiert – dort sind die alten Ergebnisse **kein Sollwert** (siehe [12](12-referenzkonfigurationen.md)).

| Fall | Befund | Stand |
|---|---|---|
| F40 | Treppe „Fundament“ ergibt dieselbe Material- und Zuschnittliste wie „Konstruktion“, obwohl eine vorhandene Betontreppe nur belegt wird | **Fehler** (Antwort Frage 11) |
| F25 | Holzfliese je lfm statt je Stück | **Fehler** (s. o.) |
| F14 | automatische Dielenlänge 7000 mm für einen Artikel mit 4/5/6 m, UK 6500 mm | **Fehler** (B-035, Frage 15) |
| – | Querstreben lassen sich im Bearbeitungsmodus nicht setzen | Bedienfehler; Regel: Abstand 60 cm (Frage 17) |

Geklärt und **kein** Fehler: gewerbliche Nutzung nur mit mehr Gummiband (F35), volle UK-Länge unter der Rinne (F38), „kurze Stücke verbinden“ ohne Wirkung beim Rechteck (F13) – Antworten 13, 14, 16 in [10](10-offene-fragen.md).

## Veraltetes Sortiment im alten Planer

Artikel und Zubehör des Online-Planers sind veraltet (Alexander, 19.10.2026). Er dient nur als Basis für Abläufe und Rechenlogik; die Artikel kommen aus der Master-Artikelliste (B-122, B-156). Beispiele aus den Exporten, die so **nicht** übernommen werden:

- einseitig genutete Anfangsdielen – werden nicht mehr verkauft, Anfangs-/Enddiele = normale Diele (B-033);
- KOPPLEX-Gummiband – wird abverkauft und durch GUMO ersetzt (B-039);
- Stärke „22 mm“ – gibt es nicht, richtig 21 mm (B-032);
- Längen und Formate außerhalb der Sortimentsmatrix (B-030, B-034, B-035).

Fehler beheben und neue Funktionen einbauen kommt nach dem funktionalen Nachbau (Alexander, 19.10.2026).

Der neue Planer korrigiert diese Punkte, bildet aber das fachlich richtige Ergebnis (Mengen, Artikel, Regeln) gleich ab.
