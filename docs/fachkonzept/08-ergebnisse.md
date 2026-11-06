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
- **Unterkonstruktion:** neu die Zuordnung Stück → Lieferholz (`lieferhoelzer`) für alle UK-Quellen: Hölzer der UK-Verlegung (3.11), zusätzliches Holz (Rahmen, zweite Lage, Querstreben, 3.6) und Stützen der Hochterrasse (3.12). Lange Stücke bekommen eigene Hölzer (über der längsten Lieferlänge: ganze Hölzer plus Rest), kurze werden aus gemeinsamen Hölzern geschnitten – dieselbe Regel wie bisher für die Mengen, die Materialliste zählt jetzt die Hölzer des Zuschnitts. Blendenhalter (Verblendung, M7-02) kommen mit M7 dazu.
- **Anzeige:** im Dialog „Materialliste“ dritte Ansicht „Zuschnitt“ mit „Zuschnitt Belag“ und „Zuschnitt Unterkonstruktion“: Artikel | Ausgangslänge (cm) | Menge | Schnittmaße (cm, getrennt durch „|“). Das PDF (M9-06) und die Zuschnittliste für das ERP übernehmen dieselben Zeilen.
- **Artikelbezeichnung:** der Titel wie im Shop (B-152); die internen Produktionsbezeichnungen des alten Planers („… - FJ 2 CLIP BOMBIERT“) gehören in den ERP-Export, nicht in die Oberfläche (Annahme).
- **Abgleich Belag** (Tests): Bei allen 14 vergleichbaren Referenzkonfigurationen (F01, F02, F06–F13, F20, F21, F23, F24) und den 8 Referenzfällen mit gleichen Lieferlängen stimmt der Zuschnitt Deckbelag Zeile für Zeile mit dem alten Planer, wenn man dessen einseitig genutete Anfangsdielen (FJ 1, B-033) zu den übrigen zählt – auch die gemischten Schnitte von F21 (19 × 500: 360 + 140, 19 × 500: 360 + 100). Abweichend F22 (3000 mm gibt es nicht mehr, R-A06).
- **Abgleich UK** (Tests): F01 13 × 400: 309, F06 14, F07 15, F09 22, F11 24 wie im alten Planer; F02 9 × 500: 480 (alt 5 × 479 + 4 × 481 – Rundung seiner Lage); F10 24 statt 25 Hölzer (Lage der UK-Linien, M6-10, nicht Zuschnitt); F20 10 × 400: 400 wie alt, dessen zwei zusätzliche Stücke à 353 cm gehören zu keinem Holz der Verlegung; F13 nutzt alt 650 cm (Fehler B-035).

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
