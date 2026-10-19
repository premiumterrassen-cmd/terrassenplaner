# 09 Nicht Teil der Kopie

## Im alten Planer abgeschaltete Funktionen

In der Oberfläche vom 08.10.2026 nicht vorhanden und daher nicht Teil der funktionalen Kopie:

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
| F35 | gewerbliche Nutzung ändert nur KOPPLEX-3, nicht UK-Abstand oder Befestigung | Verdacht – Frage 13 |
| F38 | Rinne verkleinert die Fläche, die UK bleibt aber über die volle Tiefe | Verdacht – Frage 14 |
| F14 | automatische Dielenlänge 7000 mm, UK 6500 mm (über 600 cm) | Verdacht – Frage 15 |
| F13 | „Kurze Stücke verbinden: Ja“ ohne Wirkung | Verdacht – Frage 16 |
| – | Querstreben lassen sich nicht setzen („Änderungen übernehmen“ ohne Wirkung) | Verdacht – Frage 17 |

Der neue Planer korrigiert diese Punkte, bildet aber das fachlich richtige Ergebnis (Mengen, Artikel, Regeln) gleich ab.
