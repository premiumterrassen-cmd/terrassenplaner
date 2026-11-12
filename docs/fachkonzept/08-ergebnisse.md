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
- Angemeldete Mitarbeiter (M9-10) laden auch mit der Nummer allein; ein fehlender oder falscher Prüfcode stört dann nicht. Der Planer übernimmt die vollständige Kennung vom Server, SPEICHERN führt dieselbe Nummer weiter. Der Ladedialog weist darauf hin.

## Materialliste

Im alten Planer: rechter Reiter „Materialliste“ mit Bild | Artikel | € Gesamt, „Summe gesamt“ und „enthaltene 19% MwSt.“ ([00](00-rahmen.md#materialliste)); Mengen zeigt nur die Mitarbeiter-Ansicht (Fehler, [09](09-nicht-teil-der-kopie.md)).

Neuer Planer (M9-03):

- **Knopf „Materialliste“** unter den Kennzahlen rechts oben, immer sichtbar (wie in der neuen Planer-Version). Vorher kommt wie bei PDF und Angebot der Hinweis auf unveränderte Standardwerte (M3-05).
- **Spalten:** Pos. | Bild | Artikel (Titel wie im Shop, B-152; darunter „Länge: 5000 mm“ und ggf. „Freidiele“) | Menge mit Einheit (Dielen und UK in Stück, sonst die Verkaufseinheit: VPE, Karton …) | Einzelpreis | Preis je lfm | Gesamt-lfm | Positionspreis. Darunter „Summe gesamt“, „enthaltene 19 % MwSt.“ und der Hinweis „Alle Preise inkl. MwSt. und nur zur Information – verbindlich ist unser Angebot.“ (B-055). Mengen sieht jeder – das Fehlen im alten Planer wird nicht übernommen.
- **Rechnet der Server** (`Materialliste.aus`, Berechnung Platz 60) über die ganze Planung, jede Fläche mal ihrer Häufigkeit. Jede Quelle liefert eine Liste `Materialbedarf` (Verkaufseinheiten eines Artikels, Stück, optional Lieferlänge, Zusatz, „einmal je Planung“): heute Belag (Dielenliste M5-08) und Befestigung (M5-09), später Unterkonstruktion (M6) und Zubehör samt Freidielen (M8) – ohne Sonderfälle in der Liste.
- **Zusammenfassen und Verpacken:** Gleiche Bedarfe (Einheiten, Länge, Zusatz) werden über Flächen addiert; erst die Summe wird verpackt (wenig Überhang, dann wenig Packungen wie 2.6) – drei Flächen F01 ergeben 1911 Clips → 7 × VPE 250 + 2 × VPE 100 statt dreimal 2 × 250 + 100 + 50. Ein Bedarf „einmal je Planung“ (Montagehilfe) zählt einmal. Stücke mit Länge werden gezählt, nicht verpackt.
- **Reihenfolge:** Bereich (Belag, Unterkonstruktion, Befestigung, Auflager, Anschluss, Zubehör), dann Artikelnummer, Länge, Zusatz; Positionen ab 1.
- **Preise** nur Verkaufspreise aus den Artikeldaten (B-123, B-152), brutto, in ganzen Cent, je Wert einmal gerundet. Ware je lfm (Dielen): Preis je lfm = Preis der Verkaufseinheit ÷ Inhalt, Einzelpreis = je lfm × Länge, Positionspreis = je lfm × Gesamt-lfm – die Summe hängt so nicht von der Längenmischung ab (7.1). Sonst Einzelpreis = Preis der Verkaufseinheit, Positionspreis = Einzelpreis × Anzahl, mit Länge auch Preis je lfm. Holzfliesen je Stück (Fehler F25 nicht übernommen). Freidielen kosten 0 €. Summe = Summe der Positionspreise; enthaltene MwSt. = Summe − gerundetes Netto (Summe × 100 ÷ 119), damit Netto + Steuer genau die Summe ergeben (2.066,57 € → 329,96 €). Fehlt einem Artikel der Preis, steht „–“ und unter der Summe ein Hinweis.
- **Mitarbeiter-Ansicht:** Menge je Position als Eingabe mit Häkchen „Menge übernehmen“ (auch Enter); nach einer Änderung „berechnet: 48“ mit Knopf zurück zur berechneten Menge (R-D04); 0 wählt die Position ab. Die Planung merkt sich die Mengen (`Planung.mengen`, Platz 70, mit Speichern/Laden und Rückgängig), Schlüssel Artikelnummer + Länge + Zusatz. Freigeschaltet nur mit der Rolle Mitarbeiter (M9-10): In der App schaltet die Anmeldung die Eingaben frei, der Server übernimmt die Mengen nur, wenn `PlanungsDienst.darfMengenAendern` den Aufrufer an der vom Router gesetzten Rolle als Mitarbeiter erkennt. Kunden sehen keine Eingaben, und geänderte Mengen von Kunden übernimmt der Server nicht.
- **Seit M8:** das Zubehör jeder Fläche mit seiner Menge „Tatsächlich“ samt Pflichtzubehör (M8-02, M8-03) und die Freidielen der ganzen Planung als eigene Position mit 0 € (M8-04, B-228) – siehe [06](06-zubehoer.md).
- **Optionale Positionen** (Planungsregeln Alexander (Planungskern v6, 11.11.2026) Regel 4.5, R-B15): der **Bohrsenker** (50-80-008, erster Werkzeug-Artikel mit „Bohrsenker“ im Titel) steht als eigene Position „optional – nicht in der Summe“ mit Preis in der Materialliste, sobald die Planung Clips oder Schrauben braucht und er nicht schon fest gewählt ist (`bohrsenkerAngebot`, `Materialzusatz.optional`). Er zählt nicht zur Summe und nicht zur MwSt.; in den Planungsunterlagen steht er ebenso gekennzeichnet, im GrandTotal-Export als „Optional: … - nicht in der Summe“, im Warenkorb-Link (M9-09) nicht.
- **Positionen „im Angebot“** (Planungsregeln Alexander (Planungskern v7, 11.11.2026) Regel 9.7, R-D24): In der Mitarbeiter-Ansicht hat jede Position ganz links das Häkchen „Im Angebot“. Ohne Häkchen bleibt die Position mit Menge und Preis stehen, heißt aber „Nicht im Angebot: …“ (App und Planungsunterlagen), zählt nicht zur Summe und zur MwSt. und geht nicht in den Export für GrandTotal. Die Planung merkt sich die Positionen (`Planung.ausserhalbAngebot`, Platz 71, Schlüssel wie bei den Mengen, mit Speichern/Laden und Rückgängig); der Server übernimmt sie wie geänderte Mengen nur von Mitarbeitern (`Materialzeile.imAngebot`, Positionstabelle Platz 14).
- **Noch nicht enthalten:** Unterkonstruktion, Auflager (M6), Systemdielen je m² (noch nicht verlegt, 2.7). Im Vergleich mit F01 stimmen Dielen (48 × 5000 mm ohne die einseitig genuteten Anfangsdielen, B-033) und Clips (2 × VPE 250 + 100 + 50); die Terrassenschrauben der Randdielen entfallen (2.6).

## Stückliste

In den Planungsunterlagen des alten Planers steht die Stückliste beim UK-Plan: Artikel, Länge, Stück und eine Farbe, in der das Stück im Plan gezeichnet ist (Referenzfälle M1-02, z. B. RELO C 200 cm rot, 87 cm blau, 36/35/33 cm grün).

Neuer Planer (M9-04):

- **Farben** (eine Quelle für Zeichnung, Liste und später PDF, `Stueckfarbe.argb`): **rot** ein Längsstück in ganzer Länge (ungeschnitten), **blau** ein zugeschnittenes Längsstück, **grün** ein Querstück. Ganze Länge = längste Lieferlänge des Artikels bzw. die erzwungene Dielenlänge (wie die UK-Länge im alten Planer). Geprüft gegen alle UK-Stücklisten der Referenzfälle: jede rote und blaue Zeile passt, wenn UK-Holz 6000 mm lang ist (die 6500 mm des alten Planers sind der Fehler aus B-035, F14); grüne Zeilen sind Querstücke.
- **Schnittstelle:** Jede Quelle liefert ihre Stücke als `Planstueck` (Artikel, Länge, ganze Länge, Lage längs/quer); `Stueckliste.aus` zählt gleiche Artikel, Länge und Farbe zu einer Zeile – Artikel in der Reihenfolge ihres ersten Stücks, darin rot, blau, grün und die längsten zuerst. Heute liefert der Belag seine Dielenstücke (Teilflächen eingeschlossen), mit M6 kommt die Unterkonstruktion mit Längs- und Querstücken dazu.
- **Zuordnung zum Plan:** Der Server liefert je Dielenstück dieselbe Farbe (`stueckfarben`, Berechnung Platz 62, Stückliste Platz 61); die Zeichnung umrandet jedes Stück in dieser Farbe. Die Stückliste gilt für die bearbeitete Fläche ohne Häufigkeit, weil sie die Zeichnung erklärt; Mengen für die Bestellung stehen in der Materialliste.
- **Anzeige:** im Dialog „Materialliste“ umschaltbar auf „Stückliste“: Artikel | Länge (cm) | Stück | Farbe im Plan (Farbfeld und Name).
- Beispiele: F01 48 × 480 cm blau (aus 5000 mm geschnitten); 800 × 309 cm 48 × 600 cm rot und 48 × 200 cm blau; mit Dielenlänge fest 400 cm 96 × 400 cm rot.

## Zuschnittpläne

In den Planungsunterlagen des alten Planers stehen „Zuschnitt Unterkonstruktion“ und „Zuschnitt Deckbelag“, dieselben Zeilen exportiert die Zuschnittliste der Mitarbeiter-Ansicht: Artikel, Ausgangslänge (cm), Menge, je Schnitt ein Maß (cm) – z. B. F09 „600 cm, 46 ×, 600“ und „400 cm, 23 ×, 200 | 200“.

Neuer Planer (M9-02):

- **Rechnet der Server** (`Zuschnittplan.aus`, Berechnung Plätze 167 Belag und 168 UK) für die ganze Planung: jede Fläche mal ihrer Häufigkeit (Menge), gleiche Lieferstücke (Artikel, Ausgangslänge, Schnitte) in einer Zeile. Reihenfolge: Artikel in der Reihenfolge ihres ersten Stücks, dann die längste Ausgangslänge, dann die größte Menge; Schnitte längste zuerst. Gesägt wird ohne Zugabe (2.7).
- **Belag:** die Lieferdielen der Verlegung – ohne Optimierung je Teilfläche (2.7), mit Verschnittoptimierung die der gewählten Variante über alle Flächen (07). Freidielen und Verblendungsdielen stehen nicht im Zuschnitt (wie im alten Planer); sie kommen mit M8/M7 nur in die Materialliste.
- **Unterkonstruktion:** neu die Zuordnung Stück → Lieferholz (`lieferhoelzer`) für alle UK-Quellen: Hölzer der UK-Verlegung (3.11), zusätzliches Holz (Rahmen, zweite Lage, Querstreben, 3.6) und Stützen der Hochterrasse (3.12). Lange Stücke bekommen eigene Hölzer (über der längsten Lieferlänge: ganze Hölzer plus Rest), kurze werden zuerst in die Reste der langen, dann aus gemeinsamen Hölzern geschnitten – die Materialliste zählt die Hölzer des Zuschnitts. Seit M10-01 ein gemeinsamer Zuschnitt je Fläche für alle UK-Quellen samt Blendenhaltern und Treppen-UK (`PlanungsDienst._ukHoelzer`), damit kein Rest doppelt verplant wird und der Zuschnittplan jedes Lieferholz enthält.
- **Anzeige:** im Dialog „Materialliste“ dritte Ansicht „Zuschnitt“ mit „Zuschnitt Belag“ und „Zuschnitt Unterkonstruktion“: Artikel | Ausgangslänge (cm) | Menge | Schnittmaße (cm, getrennt durch „|“). Das PDF (M9-06) und die Zuschnittliste für das ERP übernehmen dieselben Zeilen.
- **Artikelbezeichnung:** der Titel wie im Shop (B-152); die internen Produktionsbezeichnungen des alten Planers („… - FJ 2 CLIP BOMBIERT“) gehören in den ERP-Export, nicht in die Oberfläche (Annahme).
- **Abgleich Belag** (Tests): Bei allen 14 vergleichbaren Referenzkonfigurationen (F01, F02, F06–F13, F20, F21, F23, F24) und den 8 Referenzfällen mit gleichen Lieferlängen stimmt der Zuschnitt Deckbelag Zeile für Zeile mit dem alten Planer, wenn man dessen einseitig genutete Anfangsdielen (FJ 1, B-033) zu den übrigen zählt – auch die gemischten Schnitte von F21 (19 × 500: 360 + 140, 19 × 500: 360 + 100). Abweichend F22 (3000 mm gibt es nicht mehr, R-A06).
- **Abgleich UK** (Tests): F01 13 × 400: 309, F06 14, F07 15, F09 22, F11 24 wie im alten Planer; F02 9 × 500: 480 (alt 5 × 479 + 4 × 481 – Rundung seiner Lage); F10 24 statt 25 Hölzer (Lage der UK-Linien, M6-10, nicht Zuschnitt); F20 10 × 400: 400 wie alt, dessen zwei zusätzliche Stücke à 353 cm gehören zu keinem Holz der Verlegung; F13 nutzt alt 650 cm (Fehler B-035).

## Planungsunterlagen (PDF)

Im alten Planer: „Planungsunterlagen“ mit Name/Adresse/Ort/Telefon/E-Mail, Projektbezeichnung, Konfigurationsnummer und Version auf jeder Seite, „Ihre konfigurierte Terrasse“ (Fläche, Volumen, Belag, Verlegerichtung, Ausgangspunkt, UK, Verblendung), Materialliste mit Preisen, Lieferhinweis und Unterschriftszeile (Angebot), Zeichnung, „TERRASSENGEOMETRIE“ mit Aufbauhöhe und Winkel je Eckpunkt, „UNTERKONSTRUKTION“ mit Plan, Stückliste (Farbe im Plan) und Zuschnittsplan, „TERRASSENBELAG“ mit Verlegeplan, „Dielen/Platten nach Nummer“ und Zuschnittsplan, „Rechtliche Hinweise“ und Grußtext; „Seite x von y“ (Referenzfälle M1-02).

Neuer Planer (M9-06):

- **Erzeugt der Server**, die App fordert nur an (Frontend bleibt „doof“): Knopf **PDF** in der Kopfzeile → Standardwert-Hinweis (M3-05) → **SPEICHERN** (eine neue Version nur bei Änderungen, M9-05) → Unterlagendienst `kunde.konfiguration.pdf` mit Kennung, Version und Sprache → der Browser bietet die Datei `Planungsunterlagen_<Nummer>_V<Version>.pdf` zum Speichern/Öffnen an, Hinweis „Planungsunterlagen zu Konfigurationsnummer … erstellt“. Ohne Server: Hinweis, die Planung bleibt.
- **Aus gespeicherter Version und aktuellem Datenstand** (Datenmodell: „PDF … aus Version + Datenstand“), nie aus einer Planung der App: Im PDF steht immer eine Kennung mit Prüfcode, unter der sich genau diese Planung wieder laden lässt („1a. Konfigurationsnummer aus der PDF eingeben“). Falscher Prüfcode und unbekannte Nummer geben denselben Fehler wie LADEN (M9-05b).
- **Kapitel** (Domäne `planungsunterlagen`, Satz auf dem Server `planungsunterlagenPdf`, A4):
  1. **Deckblatt** mit Briefkopf: „Ihre Angaben“ (Kundendaten, nur wenn übergeben – kommen mit der Anfrage M9-07, werden nur gedruckt, nie gespeichert), Konfigurationsnummer, Version, Stand (Datum), „Ihre konfigurierte Terrasse“: Terrassenfläche aller Flächen mal Häufigkeit, Anzahl der Flächen, Volumen, Verschnitt, Summe Materialliste.
  2. Je Fläche **Terrasse** („Ihre Terrasse“, bei mehreren „Terrasse 1, 2 …“): Fläche, Anzahl gleicher Flächen, Belag, Verlegerichtung, Verlegeart, Ausgangspunkt (Ecke und Verschiebung), Befestigung, Art der Terrasse, UK, Untergrund, Art der Terrassennutzung, Nutzung, Auflagen, Feldbreite; **Terrassengeometrie**: eine eigene Zeichnung (Umriss, Ausschnitte grau, Eckpunkte A …, Kantenmaße in m) nur, wenn es weder Verlegeplan noch UK-Plan gibt – sonst stehen Umriss, Eckbuchstaben und Kantenmaße in diesen Plänen (Planungskern v6 Regel 7.2 „keine eigene Draufsicht-Seite“, R-E04); **Eckpunkthöhen** mit Aufbauhöhe und Innenwinkel (90°/270°, unabhängig vom Umlaufsinn – die verschobene Winkeltabelle des alten Planers wird nicht übernommen).
  3. **Unterkonstruktion**: Plan mit den UK-Hölzern in ihrer Farbe (rot/blau/grün wie Zeichnung und Stückliste, M9-04), Querstreben, Auflagern, Eckbuchstaben und Kantenmaßen außen und der **Achsmaßkette** (blau, R-E02) mit Legende; am Bogen die Riegel grün umrandet mit dem Hinweis „Rand-UK am Bogen von Latte zu Latte …“ (Planungskern v12, R-C40/R-E40); **Stückliste** ohne den Belag. In allen Plänen steht an einer Seite mit Bogen statt des Kantenmaßes „Bogen ‹Länge› m · R ‹Radius› m“ außen am Scheitel (R-E40); die Hinweise zur Planung nennen die Hinweise zur Blende am Bogen (R-D40).
  4. **Höhenzuordnung der Auflager** (M6-11): Abstand, je Auflager Spaltbereich und Anzahl – das sind die Stelzfußhöhen.
     **Bemaßung und Höhen** (Planungskern v7, Regel 9.2, R-E05): eigene Seite je Fläche mit Auflagern – Umriss mit Eckbuchstaben und Kantenmaßen, UK hell, Achsmaßkette, „H = … cm“ je Ecke, an jedem Auflager die Höhe des Stellfußes bzw. der Unterleger in cm neben dem Holz, Farbe je Fußtyp, darunter die Legende (Auflager, Anzahl, Farbe). Tabellenfarben sind ARGB-Werte (Stückfarben und Fußtypen).
  5. **Terrassenbelag**: Verlegeplan mit der Nummer in jedem Stück, Eckbuchstaben und Kantenmaßen außen und den **Stoßlinien rot gestrichelt** (R-E01) mit Legende, „Dielen/Platten nach Nummer“ (Nr., Artikel, Maße, Stück), „Benötigte Dielen“ je Lieferlänge; **Zuschnittsplan Belag** (Ausgangslänge, Menge, Schnittmaße; gleiche Lieferdielen zusammengefasst).
  6. **Materialliste** wie der Dialog (M9-03) – mit Zubehör (M8-02/03) und der Freidiele als eigener Position mit 0 € (M8-04, B-079) – mit €/lfm, €/Stück, € gesamt, „Summe gesamt“, „enthaltene 19 % MwSt.“ und dem Hinweis, dass nur das Angebot verbindlich ist (B-055).
  7. **Hinweise zur Planung**: die Meldungen jeder Fläche (Belag M5-10, UK gedreht, Höhe korrigiert M6-02, Höhengrenzen der Auflager M6-08) – fehlt im alten Planer.
  8. **Rechtliche Hinweise** wie im alten Planer und Grußtext „Es grüßt Sie das RobinienWelt TEAM“ mit E-Mail und Shop.
- Das Holzvolumen auf dem Deckblatt enthält die Freidiele wie die Kennzahl (M8-04). Geänderte Mengen der Mitarbeiter-Ansicht gelten im PDF wie in der Berechnung nur für angemeldete Mitarbeiter (Rolle vom Router, M9-10).
- Kopf jeder Folgeseite: Konfigurationsnummer und Version; Fuß: „Seite x von y“. Texte Deutsch und Englisch (Sprache der App).
- **Schrift:** die Standardschrift des PDF (Helvetica) ohne eingebettete Datei; sie kennt nur Latin-1, deshalb stehen Beträge als „2.066,57 EUR“ und typografische Anführungszeichen/Gedankenstriche als einfache Zeichen.
- **Nicht enthalten (Folge-Issues):** Zuschnittsplan der UK (seit M9-02 liefert die Berechnung ihn als `zuschnittUk`, Platz 168 – im PDF noch einzubinden), Verblendung (M7), Angebotsteil mit Lieferhinweis und Unterschrift (M9-07, Angebots-PDF), Projektbezeichnung (gibt es im Planungsstand noch nicht).
- **Bogenfläche (Planungskern v12):** `packages/server/test/planungskern_v12_unterlagen_test.dart` erzeugt die Unterlagen einer Fläche 5,00 × 3,50 m mit Bogen R 3,00 m an B — C, verblendet (mit `PLANER_PDF_AUSGABE=<ordner>` als `bogenflaeche.pdf`).
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
  Neuer Planer (M9-10):
  - ANMELDEN steht in der Kopfzeile nach ZURÜCKSETZEN (schmal nur als Symbol). Dialog „Login“ mit Hinweis „Nur für Mitarbeiter von ALTO HOLZ.“, Feldern E-Mail-Adresse und Passwort (verdeckt), „Abbrechen“ und „Anmelden“; Enter im Passwortfeld meldet an.
  - Falsche Angaben: „Anmeldung nicht möglich. Bitte prüfen Sie E-Mail-Adresse und Passwort – nach mehreren Fehlversuchen ist das Konto für 15 Minuten gesperrt.“ Das Passwortfeld wird geleert, die E-Mail-Adresse bleibt. Ohne Server eine eigene Meldung.
  - Angemeldet: ABMELDEN statt ANMELDEN, „Angemeldet als …“ in der Statuszeile (schmal zusätzlich im Tooltip). ABMELDEN meldet ohne Rückfrage ab („Sie sind abgemeldet.“). Neu laden der Seite oder Verbindungsabbruch melden ebenfalls ab – der Browser speichert keine Anmeldung und kein Passwort.
  - Mitarbeiter dürfen Konfigurationen ohne Prüfcode laden (siehe oben) und sehen die Mitarbeiter-Ansicht der Materialliste mit änderbaren Mengen. Die ERP-Exporte (unten) folgen mit M9-08.
  - Kunden bleiben anonym; es gibt keine Selbstregistrierung. Konten legt die Verwaltung auf dem Server an (`docs/betrieb/mitarbeiter.md`); E-Mail-Adressen gelten ohne Groß-/Kleinschreibung.
- **Video Beratung buchen**: externer Terminlink (nicht geöffnet).
- **Kontakt-Knopf** (rot, rechts): E-Mail-Kontakt.

## Mitarbeiter-Ansicht und ERP-Exporte

Nach der Mitarbeiter-Anmeldung zeigt die Materialliste je Artikel die **Menge** (änderbar, mit Häkchen) und darunter zwei Knöpfe. Beide liefern Excel-Dateien (`.xlsx`), die ALTO HOLZ **in das ERP importiert** (Alexander, 19.10.2026) – der neue Planer muss sie im selben Aufbau erzeugen. Beispiele mit Inhalt: [12 Referenzkonfigurationen](12-referenzkonfigurationen.md).

- **CSV-Download** (trotz Name eine `.xlsx`-Datei) – Materialliste, eine Zeile je Artikel und Länge. Spalten: Bezeichnung, Nomenklatur (interne Kurzbezeichnung), Body HTML (Beschreibungstext), Anzahl, Breite, Stärke, Länge (mm), Artikelnummer, Nettopreis, Bruttopreis, Link zum Bild, Volumen, Gewicht, Quadratmeter, Gesamtlaufmeter, Artikeltyp (z. B. Deckbelag, Anfangsdiele, Unterkonstruktion, „Stellfuss,Zubehoer“), Einheit (lfm, Stück).
- **Zuschnittliste** – Zuschnittplan für Deckbelag und Unterkonstruktion. Spalten: Bezeichnung (interne Produktionsbezeichnung, z. B. „… - FJ 2 CLIP BOMBIERT“), Ausgangslänge (cm), Menge, danach je Spalte ein Schnittmaß (cm).
- Freidielen (B-228, früher B-079) stehen mit Preis 0 in der Materialliste, aber nicht in der Zuschnittliste; Verblendungsdielen ebenfalls nur in der Materialliste.
- Für Fremdartikel steht in der Spalte Artikelnummer die EAN – im neuen Planer gilt die Artikelnummer aus der Master-Artikelliste (B-122); EANs gehören nicht ins öffentliche Repository (B-023).

## Export für GrandTotal

Neuer Planer (M9-08) – der „CSV-Download“ als Importdatei für GrandTotal:

- **Knopf „Export für GrandTotal“** in der Mitarbeiter-Ansicht der Materialliste (rechts über der Tabelle). Die App fordert die Datei beim Server an (`mitarbeiter.export.grandtotal`, Exportdienst) und bietet sie zum Speichern an; sie rechnet nichts selbst. Die Prozedur steht nur angemeldeten Mitarbeitern offen (M9-10) – Aufrufe aus einer Kundensitzung lehnt der Router ab. Dateiname `GrandTotal_Import_<Nummer>_v<Version>.csv` der gespeicherten Konfiguration (ohne Prüfcode), sonst `GrandTotal_Import.csv`. Erfolg und Fehler als Hinweis.
- **Inhalt = Materialliste** (M9-03) der ganzen Planung in ihrer Reihenfolge, eine Zeile je Artikel, Länge und Zusatz – mit Unterkonstruktion und Auflagern (M6), Zubehör samt Pflichtzubehör und Freidielen (M8); abgewählte Positionen (Menge 0) und Positionen ohne Häkchen „Im Angebot“ (Planungskern v7 Regel 9.7) entfallen. Es gelten die vom Mitarbeiter geänderten Mengen (`Planung.mengen`); die Rolle prüft der Dienst aus den Aufrufdetails des Routers (`disclose_caller`, `ExportDienst.darfMengenAendern`).
- **Format** wie die bisherigen Importdateien: Text in UTF-8, Trenner `;`, Zeilenende CRLF, Felder mit `;`, `"` oder Zeilenumbruch in Anführungszeichen; Zahlen mit Punkt. Spalten in dieser Reihenfolge:

| Spalte | Inhalt |
|---|---|
| Bezeichnung | Titel wie im Shop (B-152); bei Ware mit Länge „ - Länge: 5000 mm“, bei Freidielen zusätzlich „ - Freidiele“; optionale Positionen (Bohrsenker, Planungskern v6 Regel 4.5) als „Optional: Titel - nicht in der Summe“ – das GrandTotal-Plugin muss sie daran als optionale Position anlegen |
| Nomenklatur | Titel wie im Shop – keine Werks- oder Produktionsbezeichnung (B-021) |
| Body HTML | leer, solange die Artikeldaten keinen Beschreibungstext führen |
| Anzahl | Stück (Dielen, UK) bzw. Verkaufseinheiten |
| Breite, Stärke, Länge | in mm aus den Artikeldaten; Länge = Lieferlänge |
| Artikelnummer | wie im Shop (B-152) |
| Nettopreis, Bruttopreis | je Einheit der Zeile, bei Ware mit Länge je lfm; netto = brutto ÷ 1,19 auf 4, brutto auf 2 Nachkommastellen; Freidielen 0 (B-079); ohne Preis leer |
| Link zum Bild | erstes Artikelbild neben der Web-App (`…/artikelbilder/<Name>.webp`) |
| Volumen, Quadratmeter | je Stück (Breite × Stärke × Länge bzw. Breite × Länge) |
| Gewicht | ganze Zeile in kg: Holz aus Querschnitt, Länge und Rohdichte (R-A12), sonst Gewicht je Verkaufseinheit × Anzahl |
| Gesamtlaufmeter | Anzahl × Länge |
| Artikeltyp | Warengruppe: Deckbelag, Deckbelag,Zubehoer (Holzfliesen), Unterkonstruktion, Verbinder,Zubehoer, BefestigungDeck,Zubehoer, Stellfuss,Zubehoer, Unterlegpads,Zubehoer, Bodenanker, Verblendung,Zubehoer, Drainage, DrainageZubehoer, EPDM-Band,Zubehoer, Dienstleistung, sonst Zubehoer |
| Einheit | „lfm“ bei Ware mit Länge, sonst die Verkaufseinheit (Stück, VPE, Karton …) |

- **Einlesen in GrandTotal:** Das Plugin „ImportZuLaufmeter“ erkennt Holz an Warengruppe (Deckbelag, Unterkonstruktion), Breite und Stärke, rechnet Stück × Länge in lfm um und übernimmt die Katalogpreise der Artikelnummer – GrandTotal bleibt führend (B-055); fehlt der Artikel im Katalog, bleibt der Planer-Preis je lfm.
- **Nicht übernommen:** die Werks-Nomenklatur und EANs des alten Exports (B-020, B-021, B-023) und die Endung `.xlsx` (der neue Export ist echte CSV-Datei). Die Zuschnittliste folgt mit M9-02.
