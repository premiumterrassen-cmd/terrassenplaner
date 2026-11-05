# 08 Ergebnisse

## Speichern und Laden

- **SPEICHERN** (Kopfzeile) speichert ohne Rückfrage auf dem Server und vergibt eine **Konfigurationsnummer** im Format `JJJJ-MM-TT-NNNN` (Beispiel `2026-10-08-1511`) mit **Version** (1, 2, …).
- **LADEN** öffnet „Konfiguration laden“: Konfigurationsnummer, Version (−/+), Knöpfe „Konfiguration Speichern“ und „Konfiguration laden“.
- **ZURÜCKSETZEN** fragt nach: „Sind sie sicher, dass Sie die Planung zurücksetzen möchten? Dadurch geht ihr Fortschritt verloren. Stellen Sie sicher, dass Sie die Konfiguration gespeichert und die Konfigurationsnummer notiert haben.“ – „Zurück zur Konfiguration“ / „Konfiguration Zurücksetzen“.
- Der Browser merkt sich die letzte Planung (Startdialog „Wir haben eine Konfiguration gefunden …“).

Neuer Planer: Prüfcode für gespeicherte Konfigurationen (Alexander, 04.11.2026, M9-05b – „mit einem kurzen Prüfcode absichern“):

- Die fortlaufenden Nummern sind erratbar. Beim ersten SPEICHERN vergibt der Server deshalb zusätzlich einen **Prüfcode** aus 5 zufälligen Zeichen (Großbuchstaben und Ziffern ohne die verwechselbaren 0, O, 1, I, L). Er gilt für alle Versionen derselben Nummer.
- Angezeigt und eingegeben wird beides als ein Text `JJJJ-MM-TT-NNNN-XXXXX` (Beispiel `2026-10-08-1511-K7QXM`). Kleinbuchstaben, Leerzeichen und fehlende oder zusätzliche Trenner sind beim Eingeben erlaubt.
- Nach SPEICHERN zeigt der Hinweis die vollständige Kennung und bittet, die Nummer samt Prüfcode zu notieren. „Konfiguration laden“ nimmt sie in einem Feld, dazu Version −/+.
- Laden mit falschem oder fehlendem Prüfcode gibt dieselbe Meldung wie eine unbekannte Nummer: „Diese Konfiguration gibt es nicht. Bitte prüfen Sie Konfigurationsnummer, Prüfcode und Version.“ So erfährt niemand, ob eine Nummer vergeben ist.
- Der Browser merkt sich für „Weiterplanen“ die Kennung mit Prüfcode.
- Mitarbeiter sollen später (M9-10, Mitarbeiter-Anmeldung) auch ohne Prüfcode laden dürfen.

## Materialliste

Im alten Planer: rechter Reiter „Materialliste“ mit Bild | Artikel | € Gesamt, „Summe gesamt“ und „enthaltene 19% MwSt.“ ([00](00-rahmen.md#materialliste)); Mengen zeigt nur die Mitarbeiter-Ansicht (Fehler, [09](09-nicht-teil-der-kopie.md)).

Neuer Planer (M9-03):

- **Knopf „Materialliste“** unter den Kennzahlen rechts oben, immer sichtbar (wie in der neuen Planer-Version). Vorher kommt wie bei PDF und Angebot der Hinweis auf unveränderte Standardwerte (M3-05).
- **Spalten:** Pos. | Bild | Artikel (Titel wie im Shop, B-152; darunter „Länge: 5000 mm“ und ggf. „Freidiele“) | Menge mit Einheit (Dielen und UK in Stück, sonst die Verkaufseinheit: VPE, Karton …) | Einzelpreis | Preis je lfm | Gesamt-lfm | Positionspreis. Darunter „Summe gesamt“, „enthaltene 19 % MwSt.“ und der Hinweis „Alle Preise inkl. MwSt. und nur zur Information – verbindlich ist unser Angebot.“ (B-055). Mengen sieht jeder – das Fehlen im alten Planer wird nicht übernommen.
- **Rechnet der Server** (`Materialliste.aus`, Berechnung Platz 60) über die ganze Planung, jede Fläche mal ihrer Häufigkeit. Jede Quelle liefert eine Liste `Materialbedarf` (Verkaufseinheiten eines Artikels, Stück, optional Lieferlänge, Zusatz, „einmal je Planung“): heute Belag (Dielenliste M5-08) und Befestigung (M5-09), später Unterkonstruktion (M6) und Zubehör samt Freidielen (M8) – ohne Sonderfälle in der Liste.
- **Zusammenfassen und Verpacken:** Gleiche Bedarfe (Einheiten, Länge, Zusatz) werden über Flächen addiert; erst die Summe wird verpackt (wenig Überhang, dann wenig Packungen wie 2.6) – drei Flächen F01 ergeben 1911 Clips → 7 × VPE 250 + 2 × VPE 100 statt dreimal 2 × 250 + 100 + 50. Ein Bedarf „einmal je Planung“ (Montagehilfe) zählt einmal. Stücke mit Länge werden gezählt, nicht verpackt.
- **Reihenfolge:** Bereich (Belag, Unterkonstruktion, Befestigung, Auflager, Anschluss, Zubehör), dann Artikelnummer, Länge, Zusatz; Positionen ab 1.
- **Preise** nur Verkaufspreise aus den Artikeldaten (B-123, B-152), brutto, in ganzen Cent, je Wert einmal gerundet. Ware je lfm (Dielen): Preis je lfm = Preis der Verkaufseinheit ÷ Inhalt, Einzelpreis = je lfm × Länge, Positionspreis = je lfm × Gesamt-lfm – die Summe hängt so nicht von der Längenmischung ab (7.1). Sonst Einzelpreis = Preis der Verkaufseinheit, Positionspreis = Einzelpreis × Anzahl, mit Länge auch Preis je lfm. Holzfliesen je Stück (Fehler F25 nicht übernommen). Freidielen kosten 0 €. Summe = Summe der Positionspreise; enthaltene MwSt. = Summe − gerundetes Netto (Summe × 100 ÷ 119), damit Netto + Steuer genau die Summe ergeben (2.066,57 € → 329,96 €). Fehlt einem Artikel der Preis, steht „–“ und unter der Summe ein Hinweis.
- **Mitarbeiter-Ansicht (vorbereitet):** Menge je Position als Eingabe mit Häkchen „Menge übernehmen“ (auch Enter); nach einer Änderung „berechnet: 48“ mit Knopf zurück zur berechneten Menge (R-D04); 0 wählt die Position ab. Die Planung merkt sich die Mengen (`Planung.mengen`, Platz 70, mit Speichern/Laden und Rückgängig), Schlüssel Artikelnummer + Länge + Zusatz. Freigeschaltet nur mit der Rolle Mitarbeiter: In der App schaltet `PlanerRahmen.mitarbeiter` die Eingaben frei, der Server übernimmt die Mengen nur, wenn `PlanungsDienst.darfMengenAendern` den Aufrufer als Mitarbeiter erkennt. Bis zur Anmeldung (M9-10) ist beides aus – Kunden sehen und senden keine geänderten Mengen, die der Server übernimmt.
- **Noch nicht enthalten:** Unterkonstruktion, Auflager, Gummiband (M6), Zubehör und Freidielen (M8), Systemdielen je m² (noch nicht verlegt, 2.7). Im Vergleich mit F01 stimmen Dielen (48 × 5000 mm ohne die einseitig genuteten Anfangsdielen, B-033) und Clips (2 × VPE 250 + 100 + 50); die Terrassenschrauben der Randdielen entfallen (2.6).

## Stückliste

In den Planungsunterlagen des alten Planers steht die Stückliste beim UK-Plan: Artikel, Länge, Stück und eine Farbe, in der das Stück im Plan gezeichnet ist (Referenzfälle M1-02, z. B. RELO C 200 cm rot, 87 cm blau, 36/35/33 cm grün).

Neuer Planer (M9-04):

- **Farben** (eine Quelle für Zeichnung, Liste und später PDF, `Stueckfarbe.argb`): **rot** ein Längsstück in ganzer Länge (ungeschnitten), **blau** ein zugeschnittenes Längsstück, **grün** ein Querstück. Ganze Länge = längste Lieferlänge des Artikels bzw. die erzwungene Dielenlänge (wie die UK-Länge im alten Planer). Geprüft gegen alle UK-Stücklisten der Referenzfälle: jede rote und blaue Zeile passt, wenn UK-Holz 6000 mm lang ist (die 6500 mm des alten Planers sind der Fehler aus B-035, F14); grüne Zeilen sind Querstücke.
- **Schnittstelle:** Jede Quelle liefert ihre Stücke als `Planstueck` (Artikel, Länge, ganze Länge, Lage längs/quer); `Stueckliste.aus` zählt gleiche Artikel, Länge und Farbe zu einer Zeile – Artikel in der Reihenfolge ihres ersten Stücks, darin rot, blau, grün und die längsten zuerst. Heute liefert der Belag seine Dielenstücke (Teilflächen eingeschlossen), mit M6 kommt die Unterkonstruktion mit Längs- und Querstücken dazu.
- **Zuordnung zum Plan:** Der Server liefert je Dielenstück dieselbe Farbe (`stueckfarben`, Berechnung Platz 62, Stückliste Platz 61); die Zeichnung umrandet jedes Stück in dieser Farbe. Die Stückliste gilt für die bearbeitete Fläche ohne Häufigkeit, weil sie die Zeichnung erklärt; Mengen für die Bestellung stehen in der Materialliste.
- **Anzeige:** im Dialog „Materialliste“ umschaltbar auf „Stückliste“: Artikel | Länge (cm) | Stück | Farbe im Plan (Farbfeld und Name).
- Beispiele: F01 48 × 480 cm blau (aus 5000 mm geschnitten); 800 × 309 cm 48 × 600 cm rot und 48 × 200 cm blau; mit Dielenlänge fest 400 cm 96 × 400 cm rot.

## Planungsunterlagen (PDF)

Im alten Planer: „Planungsunterlagen“ mit Name/Adresse/Ort/Telefon/E-Mail, Projektbezeichnung, Konfigurationsnummer und Version auf jeder Seite, „Ihre konfigurierte Terrasse“ (Fläche, Volumen, Belag, Verlegerichtung, Ausgangspunkt, UK, Verblendung), Materialliste mit Preisen, Lieferhinweis und Unterschriftszeile (Angebot), Zeichnung, „TERRASSENGEOMETRIE“ mit Aufbauhöhe und Winkel je Eckpunkt, „UNTERKONSTRUKTION“ mit Plan, Stückliste (Farbe im Plan) und Zuschnittsplan, „TERRASSENBELAG“ mit Verlegeplan, „Dielen/Platten nach Nummer“ und Zuschnittsplan, „Rechtliche Hinweise“ und Grußtext; „Seite x von y“ (Referenzfälle M1-02).

Neuer Planer (M9-06):

- **Erzeugt der Server**, die App fordert nur an (Frontend bleibt „doof“): Knopf **PDF** in der Kopfzeile → Standardwert-Hinweis (M3-05) → **SPEICHERN** (eine neue Version nur bei Änderungen, M9-05) → Unterlagendienst `kunde.konfiguration.pdf` mit Kennung, Version und Sprache → der Browser bietet die Datei `Planungsunterlagen_<Nummer>_V<Version>.pdf` zum Speichern/Öffnen an, Hinweis „Planungsunterlagen zu Konfigurationsnummer … erstellt“. Ohne Server: Hinweis, die Planung bleibt.
- **Aus gespeicherter Version und aktuellem Datenstand** (Datenmodell: „PDF … aus Version + Datenstand“), nie aus einer Planung der App: Im PDF steht immer eine Kennung mit Prüfcode, unter der sich genau diese Planung wieder laden lässt („1a. Konfigurationsnummer aus der PDF eingeben“). Falscher Prüfcode und unbekannte Nummer geben denselben Fehler wie LADEN (M9-05b).
- **Kapitel** (Domäne `planungsunterlagen`, Satz auf dem Server `planungsunterlagenPdf`, A4):
  1. **Deckblatt** mit Briefkopf: „Ihre Angaben“ (Kundendaten, nur wenn übergeben – kommen mit der Anfrage M9-07, werden nur gedruckt, nie gespeichert), Konfigurationsnummer, Version, Stand (Datum), „Ihre konfigurierte Terrasse“: Terrassenfläche aller Flächen mal Häufigkeit, Anzahl der Flächen, Volumen, Verschnitt, Summe Materialliste.
  2. Je Fläche **Terrasse** („Ihre Terrasse“, bei mehreren „Terrasse 1, 2 …“): Fläche, Anzahl gleicher Flächen, Belag, Verlegerichtung, Verlegeart, Ausgangspunkt (Ecke und Verschiebung), Befestigung, Art der Terrasse, UK, Untergrund, Art der Terrassennutzung, Nutzung, Auflagen, Feldbreite; **Terrassengeometrie** (Umriss, Ausschnitte grau, Eckpunkte A …, Kantenmaße in m); **Eckpunkthöhen** mit Aufbauhöhe und Innenwinkel (90°/270°, unabhängig vom Umlaufsinn – die verschobene Winkeltabelle des alten Planers wird nicht übernommen).
  3. **Unterkonstruktion**: Plan mit den UK-Hölzern in ihrer Farbe (rot/blau/grün wie Zeichnung und Stückliste, M9-04), Querstreben, Auflagern; **Stückliste** ohne den Belag.
  4. **Höhenzuordnung der Auflager** (M6-11): Abstand, je Auflager Spaltbereich und Anzahl – das sind die Stelzfußhöhen.
  5. **Terrassenbelag**: Verlegeplan mit der Nummer in jedem Stück, „Dielen/Platten nach Nummer“ (Nr., Artikel, Maße, Stück), „Benötigte Dielen“ je Lieferlänge; **Zuschnittsplan Belag** (Ausgangslänge, Menge, Schnittmaße; gleiche Lieferdielen zusammengefasst).
  6. **Materialliste** wie der Dialog (M9-03) mit €/lfm, €/Stück, € gesamt, „Summe gesamt“, „enthaltene 19 % MwSt.“ und dem Hinweis, dass nur das Angebot verbindlich ist (B-055).
  7. **Hinweise zur Planung**: die Meldungen jeder Fläche (Belag M5-10, UK gedreht, Höhe korrigiert M6-02, Höhengrenzen der Auflager M6-08) – fehlt im alten Planer.
  8. **Rechtliche Hinweise** wie im alten Planer und Grußtext „Es grüßt Sie das RobinienWelt TEAM“ mit E-Mail und Shop.
- Kopf jeder Folgeseite: Konfigurationsnummer und Version; Fuß: „Seite x von y“. Texte Deutsch und Englisch (Sprache der App).
- **Schrift:** die Standardschrift des PDF (Helvetica) ohne eingebettete Datei; sie kennt nur Latin-1, deshalb stehen Beträge als „2.066,57 EUR“ und typografische Anführungszeichen/Gedankenstriche als einfache Zeichen.
- **Nicht enthalten (Folge-Issues):** Zuschnittsplan der UK (M9-02, die UK liefert bisher keine Zuordnung Stück → Lieferlänge), Verblendung (M7), Zubehör und Freidielen (M8), Angebotsteil mit Lieferhinweis und Unterschrift (M9-07, Angebots-PDF), Projektbezeichnung (gibt es im Planungsstand noch nicht).
- **Abnahme:** Für 31 Referenzfälle (alle Rechtecke, L- und T-Formen mit vollständigen Kantenmaßen) entstehen alle Kapitel und ein PDF (`packages/server/test/referenzunterlagen_test.dart`, mit `PLANER_PDF_AUSGABE=<ordner>` zum Ansehen).

## Angebot anfordern

Knopf „Jetzt Angebot anfordern“ (Materialliste) öffnet „Angebot anfordern“:

- Felder: Konfigurationsnummer, Name*, Festnetz- oder Mobilnummer*, E-Mail*, Adresse*, PLZ*, Ort*, Notizen.
- Pflicht-Häkchen Datenschutzerklärung (mit Link) samt Hinweis auf Widerruf.
- Optionales Häkchen Selbstabholung mit Pauschale (Ort und Betrag sind Firmenwissen, siehe Beschlüsse B-020 ff.).
- Knöpfe „Zurück Zur Konfiguration“ und „E-Mail Senden“.
- (Im Test nicht abgeschickt.)

## Angebots-PDF und Bestellung

- „Jetzt Angebot als PDF Download“ erzeugt die Angebots-PDF mit Konfigurationsnummer und Shop-Link, der die Artikel in den Warenkorb legt. (Im Test nicht heruntergeladen. Inhalt und Aufbau aus den vorhandenen Planungsunterlagen in M1-02.)
- „1a/1b/2“-Texte im Abschlussbereich erklären die Wege: allein weiterplanen, direkt bestellen, Plausibilitätsprüfung mit Beratungstermin.

## Weitere

- **ANMELDEN**: Dialog „Login“ mit E-Mail-Adresse und Passwort – **nur für Mitarbeiter** (Rollen in M0-08).
- **Video Beratung buchen**: externer Terminlink (nicht geöffnet).
- **Kontakt-Knopf** (rot, rechts): E-Mail-Kontakt.

## Mitarbeiter-Ansicht und ERP-Exporte

Nach der Mitarbeiter-Anmeldung zeigt die Materialliste je Artikel die **Menge** (änderbar, mit Häkchen) und darunter zwei Knöpfe. Beide liefern Excel-Dateien (`.xlsx`), die ALTO HOLZ **in das ERP importiert** (Alexander, 19.10.2026) – der neue Planer muss sie im selben Aufbau erzeugen. Beispiele mit Inhalt: [12 Referenzkonfigurationen](12-referenzkonfigurationen.md).

- **CSV-Download** (trotz Name eine `.xlsx`-Datei) – Materialliste, eine Zeile je Artikel und Länge. Spalten: Bezeichnung, Nomenklatur (interne Kurzbezeichnung), Body HTML (Beschreibungstext), Anzahl, Breite, Stärke, Länge (mm), Artikelnummer, Nettopreis, Bruttopreis, Link zum Bild, Volumen, Gewicht, Quadratmeter, Gesamtlaufmeter, Artikeltyp (z. B. Deckbelag, Anfangsdiele, Unterkonstruktion, „Stellfuss,Zubehoer“), Einheit (lfm, Stück).
- **Zuschnittliste** – Zuschnittplan für Deckbelag und Unterkonstruktion. Spalten: Bezeichnung (interne Produktionsbezeichnung, z. B. „… - FJ 2 CLIP BOMBIERT“), Ausgangslänge (cm), Menge, danach je Spalte ein Schnittmaß (cm).
- Freidielen (B-079) stehen mit Preis 0 in der Materialliste, aber nicht in der Zuschnittliste; Verblendungsdielen ebenfalls nur in der Materialliste.
- Für Fremdartikel steht in der Spalte Artikelnummer die EAN – im neuen Planer gilt die Artikelnummer aus der Master-Artikelliste (B-122); EANs gehören nicht ins öffentliche Repository (B-023).
