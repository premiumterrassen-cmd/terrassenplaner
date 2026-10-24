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
- **Titel:** aus „ArtikelbezeichnungKonfi“ (Name wie im Planer), nur wenn leer aus „Artikelbezeichnung“ – dort steht oft eine Beschreibung („… zur sichtverdeckten Verschraubung“), die Clips sonst zu Schrauben machen würde.
- **Holz:** Holzart und Serie werden aus dem Titel erkannt (Robinie; BASIC, ECO SELECT, PREMIUM SELECT, MASSIV); Profil aus „genutet/glattkant“ bzw. „sichtbar/unsichtbar befestigt“, Oberseite aus „bombiert“.
- Die Spalte „Gewicht“ enthält die Rohdichte (750) und wird nicht als Artikelgewicht übernommen – die Rohdichte steht in der Holzart.
- **Die Artikeldatei gehört nicht ins Repository:** Artikelnummern der Fremdartikel sind EANs (B-155). `.gitignore` schließt `artikel*.json` im Wurzelverzeichnis und im Server-Paket aus.

## Datenprüfung (M2-03)

Nach dem Einlesen prüft der Importer alle Artikel gemeinsam; jeder Befund nennt Excel-Zeile und Spalte, sortiert nach Zeile.

| Prüfung | Art |
|---|---|
| Pflichtfelder, Zahlen, Einheit, Artikeltyp, Holzart/Serie erkennbar | FEHLER |
| doppelte Artikelnummer (mit erster Zeile) | FEHLER |
| Verweis (mögliche …, benötigtes Zubehör) auf nicht vorhandenen Artikel | FEHLER |
| Dielenformat bzw. UK-Format nicht im Sortiment der Holzart (B-030, B-034) | FEHLER |
| Länge keine Lieferlänge der Serie (B-035) | FEHLER |
| MinHoehe > MaxHoehe, Maß über 12 m | FEHLER |
| Befestigung widerspricht der Firmenregel (genutet nur Clips, glattkant nur Schrauben; B-094, B-090; M2-04) | FEHLER |
| UK nur ungetrocknet lieferbar (B-212) | Hinweis |
| UK-Abstand über dem Höchstwert der Holzart (R-C01) | Hinweis |
| Schraubenlänge passt nicht zum Titel („5,5 x 60 mm“) | Hinweis |
| kein Preis (B-055), keine Abbildung (M2-07) | Hinweis |
| Maß unter 1 mm | Hinweis |

Bei einem FEHLER entsteht keine Artikeldatei.

## Stand 20.10.2026 (Upload-Datei v6)

241 Artikel ohne Fehler importiert, fünf Hinweise: Zeile 42 Unkrautvlies 0,1 mm nicht übernommen; Zeile 109 Speedfix-Flügelbohrschraube 5,5 × 60 mm mit Länge 45 eingetragen (in der Master-Artikelliste korrigieren); Zeilen 173, 226, 227 ECO-UK 60 × 60, 60 × 80, 90 × 90 nur ungetrocknet (B-212, wie beschlossen).

## Artikeldaten auf dem Server (M2-06)

Der Router liest die Artikeldatei aus `PLANER_ARTIKELDATEI` (Ansible: `/var/lib/terrassenplaner/planer-router/artikel.json`, Container: `/daten/artikel.json` im Volume `router-daten`; ohne Variable `artikel.json` im Arbeitsverzeichnis). Alle 30 Sekunden prüft er, ob ein neuer Stand vorliegt:

- Neue Version → der Artikeldienst arbeitet sofort mit den neuen Daten und meldet die Version über `…kunde.artikel.geaendert`; offene Apps verwerfen ihren Zwischenspeicher. Kein Neustart, kein App-Update.
- Fehlerhafte Datei → Meldung im Log, der bisherige Stand bleibt in Betrieb.
- Keine Datei → der Router startet mit leeren Artikeldaten (Version `leer`) und warnt im Log.

Neue Artikeldaten einspielen (Root-Server):

```bash
dart run bin/artikel_importieren.dart <upload.xlsx> artikel.json
scp artikel.json happysrv:/var/lib/terrassenplaner/planer-router/artikel.json.neu
ssh happysrv 'cd /var/lib/terrassenplaner/planer-router && chown planer-router: artikel.json.neu && mv artikel.json.neu artikel.json'
```

Das `mv` am Schluss tauscht die Datei in einem Schritt aus, damit der Router nie eine halb kopierte Datei liest.

WAMP-Schnittstelle (`WampNamen`, Rolle Kunde):

| Prozedur | Argumente | Antwort |
|---|---|---|
| `…kunde.artikel.version` | – | Versionskennung |
| `…kunde.artikel.liste` | Filter als Keywords (`bereich`, `art`, `holzart`, `serie`, `profil`, `oberseite`) | `{version, artikel: […]}` in Datenreihenfolge |
| `…kunde.artikel.regeln` | Artikelnummer | `Artikelregeln`: Auswahl je Beziehung, Pflichtzubehör mit Anzahl, Abstände |

Fehler: `…kunde.fehler.artikel_unbekannt`, `…kunde.fehler.filter_ungueltig`. In der App kapselt `ArtikelQuelle` die Aufrufe und hält Antworten nur im Speicher.

## Artikelbilder (M2-07)

Die Abbildungen 1–3 je Artikel kommen aus den Bildordnern der Upload-Datei (z. B. `Analyse Claude/Planer_Bilder_Upload_2026-10-14`) und – für die Bilder, die nur im alten Planer lagen – aus einem einmaligen Abzug von dort (24.10.2026, 129 Dateien; Freigabe Alexander). Das Werkzeug bereitet sie für das Web auf:

```bash
cd packages/server
dart run bin/artikelbilder_aufbereiten.dart artikel.json artikelbilder <bildordner> [<bildordner> …]
```

- Jedes Bild der Artikeldatei wird im ersten passenden Ordner gesucht und als **WebP, höchstens 800 px breit, Qualität 80, ohne Metadaten** geschrieben (`cwebp` ≥ 1.5, z. B. `brew install webp`). Der Dateiname bleibt, die Endung wird `.webp` (`artikelbildDatei`).
- Fehlende Bilder meldet das Werkzeug als Hinweis; die App zeigt dort den Platzhalter (`ArtikelbildPlatzhalter`). „Kein Bild“ in den Abbildungsspalten zählt als keine Abbildung.
- Stand Upload-Datei v6: 230 Bilder (3,4 MB statt rund 13 MB), es fehlt nur `robinie-terrassenfliese-decktile-01.jpg` (auch im alten Planer nicht vorhanden).

Ausgeliefert werden die Bilder von nginx unter `/artikelbilder/` (ein Tag Cache) – Root-Server: `/var/lib/terrassenplaner/artikelbilder/`, Container: `artikelbilder/` im Container-Verzeichnis. Wie die Artikeldatei gehören sie nicht ins Repository und wirken ohne Deployment:

```bash
rsync -a --delete artikelbilder/ happysrv:/var/lib/terrassenplaner/artikelbilder/
```

