# 10 Offene Fragen

Zur Klärung mit Alexander (in M1-03/M1-04 abhaken).

1. ~~**Rote Seite** im Grundriss~~ → beantwortet, siehe unten.
2. ~~**Fuge**~~ „0.5 mm“: gemeint sind 5 mm?
3. ~~**Verschnitt-Kennzahl**~~: Was misst sie genau? Werte und Volumen passen nicht zusammen (z. B. 135 Grad: 0,32 % bei höherem Volumen).
4. ~~**Dielenlängen**~~: Automatik wählt 5000 mm, obwohl 6000 mm im Sortiment sind. Werden Dielen auf Wunschlänge gekappt geliefert (300–600 cm in 50er-Schritten)?
5. ~~**Querstreben**~~ (3.7): Wie setzt man sie, und was bewirken sie?
6. ~~**Untergrund**~~ (3.5): Wo wirkt er sich aus (Auflager, Pads, Anker)?
7. ~~**Vorhandene UK**~~: Sollen dabei UK-Holz und Bodenanker wegfallen?
8. ~~**Treppenhöhe**~~: Stufenzahl und -höhe unabhängig von der Terrassenhöhe – gewollt?
9. ~~**Bodentiefes Element**~~ bei Rinnen: Wo wird seine Lage und Breite eingegeben?
10. ~~**Zubehör-Mengen**~~: Eintrag „Tatsächlich“ änderte die Summe sofort nicht – wann fließt er ein (Angebot/PDF)?
11. ~~**Konstruktionsart Fundament**~~ (Treppe): Wirkung auf die Materialliste?
12. ~~**Login**~~: Wer meldet sich an (Mitarbeiter/Händler), und was sehen sie zusätzlich?

Aus M1-03 (Verdacht auf Fehler des alten Planers, siehe [09](09-nicht-teil-der-kopie.md)):

13. ~~**Gewerbliche Nutzung** (F35)~~ → beantwortet, siehe unten.
14. ~~**Rinne** (F38)~~ → beantwortet.
15. ~~**Dielenlängen über 600 cm** (F14)~~ → Fehler laut B-035 (7 m nur bei ECO SELECT; UK 6,5 m gibt es nicht).
16. ~~**Kurze Stücke verbinden** (F13)~~ → beantwortet.
17. ~~**Querstreben**~~ → beantwortet.
18. ~~**Grenzen der Terrassenmaße** (M4-02)~~ → beantwortet.

Aus dem Paritätsnachweis (M10-01, [Bericht](../abnahme/paritaetsbericht.md#offene-fragen-an-alexander)):

19. ~~**UK an schrägen Rändern, Ausschnitt-, Innen- und Bogenkanten**~~ → beantwortet, siehe unten.
20. **Vorhandene UK (F29):** alt zusätzlich 2 × 473 cm wie ein Rahmen – gewollt?
21. **Alu-UK:** alt mehr Schienen (RELO 22 statt 18, ALUecofix XL 182 statt 169) – eigener, engerer Achsabstand?

Aus den Plänen nach dem Planungskern v6 (Abschnitt 6, `feature/planungskern-plaene`):

22. **Eckbuchstaben über mehrere Flächen:** Der Kern benennt die Ecken „um alle Flächen zusammen“ (gleiche Ecke zweier Flächen = gleicher Buchstabe, Nahtpunkte danach). Die Flächen des Planers (Reiter 1, 2 …) haben aber keine gemeinsame Lage zueinander – umgesetzt ist darum je Fläche ihr Umriss (A oben links, im Uhrzeigersinn, R-E03), jede Fläche beginnt bei A; Ecken von Ausschnitten bleiben ohne Buchstaben. Reicht das, oder sollen Flächen zueinander platziert werden (dann gemeinsamer Umriss wie im Kern)?
23. **Weitere Darstellungsregeln aus Abschnitt 6** noch nicht übernommen: „Haus oben“ (Plan so drehen, dass die Hauswand oben liegt), Winkel nur im UK-Plan statt in der Eckpunkt-Tabelle der Terrasse, Länge je UK im UK-Plan. Gewünscht für den Go-Live oder später?

Aus dem Abgleich mit dem Planungskern v6 (Auflager aus der Höhe, 12.11.2026):

24. **Hochterrasse 54,2 cm vs. Höchsthöhe 52,4 cm:** Der Planungskern (Regel 3a.4/3a.5) nennt als Höchsthöhe mit Stellfüßen 52,4 cm und will darüber eine Fehlermeldung. Der Planer hat wie der alte Planer die Terrassenart Hochterrasse mit Vorgabehöhe 54,2 cm (Stützen aus UK-Holz und Bodenanker, keine Stellfüße). Umgesetzt ist die Höchsthöhe nur für die normale Terrasse; die Hochterrasse bleibt unverändert. Soll es die Hochterrasse weiter geben (dann gilt 52,4 cm nur auf Stellfüßen), soll der Planer über 52,4 cm statt „Höhe ungültig“ auf die Hochterrasse hinweisen – oder fällt sie weg?
25. **Auflager-Details aus Regel 3a.2:** (a) Für 3–4 mm Ausgleich nimmt der Planer 2 + 2 mm (genau passend) statt eines 5-mm-Pads, für 17 mm 8 + 8 mm – so gewollt? (b) Über 200 mm nennt die Regel „Adapter 120 mm“; die Artikeldaten haben keinen Adapter, die Höchsthöhe rechnet mit 440 mm (zwei Adapter), die Materialliste zeigt die Adapter noch nicht. (c) Welche Stellfüße gelten, kommt aus den Artikeldaten der UK (Spalten Stellfuß privat/gewerblich) – stehen dort nur die ROBI-LIFT der Serie F (keine Justierkeile mehr)?

Aus dem Planungskern v6 (Musterverfahren R-B17 und RIBOL-Menge R-D10, 12.11.2026):

26. **Höchstens 3 Stücke je Diele – streng?** Umgesetzt wie im Regeltext 1.3 „bis 3 Stücke je Diele“ (der Auftrag nannte „je Reihe“). Folgen: F04 (diagonal 135°, 152 Stücke) braucht mindestens 51 Dielen – die 1-%-Regel kann die 46 Dielen ohne Grenze nicht erreichen, es bleiben 2 Freidielen (Planer: 51 Dielen, 237 m statt 52 Dielen, 231 m); die Teilfläche A1 von F22 (20 × 1,20 m) braucht 7 × 4 m statt 4 × 6 m (+4 m); Referenzfall 2026-04-29-164 +28 m. Soll die Grenze auch gelten, wenn 4–5 kurze Stücke aus einer Diele passen?
27. **Musterverfahren über alle Flächen gemeinsam als Standard?** Regel 1.3 sagt „über ALLE Flächen gemeinsam“. Umgesetzt ist das Musterverfahren in jedem Zuschnitt; gemeinsam über alle Teilflächen und Flächen schneidet der Planer aber weiter erst nach „OPTIMIERUNG ERSTELLEN“ (Bedienung wie im alten Planer, Fachkonzept 7.1). Soll die gemeinsame Optimierung immer gelten (dann entfallen Hinweis und Knopf)?
28. **Mindestrest 30 cm:** Umgesetzt: Ein Rest unter 30 cm ist Verschnitt und nimmt kein Stück mehr auf, auch wenn ein kürzeres Stück hineinpasste (3,80 m aus 4 m lässt 22,5 cm – ein 20-cm-Stück kommt aus einer neuen Diele). Richtig so?
29. **Musterverfahren auch für die UK?** Heute nur für Dielen; die UK stückelt mit Reststück ab 50 cm (R-C13) und schneidet kurze Stücke ohne Sägeschnitt und ohne Grenze der Stücke aus den Resten (`lieferhoelzer`).
30. **RIBOL-Ölfläche:** Umgesetzt mit den verlegten Stücken (nicht den Lieferlängen), Treppendielen als Dielen, Blenden mit ihren Zuschnitten (samt Gehrungszugabe) und allen UK-Zuschnitten (auch Rand-UK, Querhölzer, Stützen, Blendenträger, Treppen-UK). Bestätigen? Offen bleibt der Abgleich mit der Formel in GrandTotal (Regel 5.2.4). Regel 5.2.3 „die Annahme nennt m² und Liter“: Soll der Planer Ölfläche und Liter anzeigen (Zubehör, Planungsunterlagen)? Noch nicht umgesetzt.
31. **RIBOL-Gebinde und Sorte:** Regel 5.2.2 nennt 2,5 l und 0,75 l; der Planer nimmt alle Gebinde der Sorte aus den Zubehör-Verweisen des Belags (auch ein 10-l-Gebinde, falls verknüpft) und die günstigste Kombination nach den Preisen der Artikeldaten (nur Anzeige, B-055). Die Sorte ist die erste verknüpfte – Regel 5.1 nennt RIBOL 562 NATUR als Standard. Reicht die Reihenfolge der Verweise in den Artikeldaten, oder soll NATUR fest Standard sein?

Aus dem Planungskern v7 (Verlegemuster R-B18, 12.11.2026; Nummern ab 60, weil parallele Branches 32–59 belegen):

60. **Verband nur über einer Dielenlänge – auch bei Referenzfällen?** Regel 9.3 „nur wenn die Fläche länger als eine Diele ist“ ist umgesetzt. Folge: Wer auf 4,04 m Drittelverband wählt (Referenzfall 2026-05-03-4381, alt 134,7 + 269,3 cm), bekommt jetzt ganze Reihen à 404 cm – 36 Dielen à 5 m statt 27 à 6 m (+27,5 m). Ebenso 480 cm Halb-/Drittelverband (F06/F07): kein Stoß, keine Doppel-UK, eine UK-Linie und 50 Clips weniger. Soll der Planer in diesem Fall einen Hinweis „Verband erst ab … m Länge“ zeigen oder die Auswahl sperren?
61. **Wechselverband: mehr UK und Clips.** Unregelmäßig mit vier Viertel-Versätzen heißt vier Stoßlinien je Dielenlänge, jede mit Doppel-UK. F12 (8 × 3,09 m): 28 statt 23 UK-Hölzer, 1350 statt 1100 Clips (Halbverband F10: 24 Hölzer). Ist das so gewollt, oder soll der Wechselverband nur zwischen zwei bis drei Linien wechseln?
62. **Stoßweite:** Umgesetzt ist die Stoßweite = längste (bzw. erzwungene) Lieferlänge, der Versatz ½ = 3 m bei 6-m-Dielen; der Planungskern rechnet intern mit Lieferlänge − 4 cm. Mit 3 cm Überlänge und 5 mm Sägeschnitt passt ein Zwischenstück genau in die Diele. Bestätigen?
63. **Ausweichen am Rand:** Passt der bevorzugte Versatz nicht (Stück unter 40 cm), nimmt der Planer einen anderen Versatz oder spiegelt das Raster von der Gegenseite; die Stöße sollen mindestens 30 cm bzw. den halben Versatz neben denen der Vorreihe liegen. Reicht das als Regel, oder soll die Reihe lieber ein kürzeres Endstück behalten?

## Beantwortet

- **Kurze UK-Stücke 8,6 / 8,7 / 11 cm im UK-Zuschnitt** (aus M1-02): im 90°-Winkel an den Sichtseiten angesetzte UK-Stücke, an denen die Blenden befestigt werden (Alexander, 19.10.2026).
- **Rote Kante im Grundriss** (Frage 1): markiert die letzte Dielenreihe, die längs auf Restbreite aufgeschnitten werden muss (Alexander, 19.10.2026). Passt zu den Referenzfällen (z. B. „290 x 3 cm“, „540 x 5,5 cm“ neben 6 cm Normalbreite). Erscheint erst nach Formwahl; der neue Planer zeigt die aufzuschneidende Reihe ebenfalls an.
- **Fuge** (Frage 2): 5 mm – „0.5 mm“ im alten Planer ist ein Anzeigefehler.
- **Verschnitt** (Frage 3): der Teil von Diele und UK, der über die geplante Länge hinaus geliefert wird. Beispiel: Diele für 480 cm wird in 500 cm geliefert → 20 cm Verschnitt; bei der UK genauso.
- **Dielenlängen** (Frage 4): der Planer sucht die passende Lieferlänge automatisch aus; alternativ zwingt man ihn auf eine bestimmte Länge (z. B. weil nur diese am Lager ist).
- **Querstreben** (Frage 5): werden zwischen die UK-Hölzer als Leiterverband gesetzt und versteifen die Unterkonstruktion.
- **Untergrund** (Frage 6): nur eine Information für uns als Planer, damit wir dem Kunden die richtigen Unterbauhinweise geben können – keine Wirkung auf die Berechnung.
- **Vorhandene UK** (Frage 7): UK-Holz und Bodenanker entfallen **nicht** – die neue UK wird auf die vorhandene gebaut.
- **Treppenhöhe** (Frage 8): unabhängig von der Terrassenhöhe ist gewollt – teilweise sind andere Bauteile vorhanden, die wir nicht mitplanen.
- **Bodentiefes Element / Rinne** (Frage 9): fest im Artikel verankert; Rinnen werden nur an den Seiten verbaut, als Ventilationsprofil oder Entwässerungsrinne. Die Lageauswahl wählt die Artikelvariante.
- **Zubehör „Tatsächlich“** (Frage 10): „Tatsächlich“ ist zunächst der vom Planer berechnete Wert; danach kann man ihn ändern. Der geänderte Wert erscheint im finalen Angebot unter dem berechneten Wert des Planers.
- **Treppe: Fundament / Konstruktion** (Frage 11): Fundament = Treppe ist schon aus Beton vorhanden und wird nur belegt; Konstruktion = der Planer muss die Treppe konstruktiv erstellen und berechnen.
- **Login** (Frage 12): nur für Mitarbeiter.

- **Gewerbliche Nutzung** (Frage 13): war gedacht, um auf teurere Zubehörteile und dickere Dielen umzustellen – fachlich nicht nötig, nur Marketing; **bleibt wie im alten Planer** (nur mehr Gummiband). Später vielleicht: UK zwingend versteift und nur PREMIUM SELECT – noch nicht entschieden, zurückgestellt.
- **Rinne und UK** (Frage 14): Die UK geht bis zur Hauswand (endet 1–2 cm davor). Unter der Rinne liegen die Auflageprofile (RELO VA), darauf werden die Ventilationsprofile (RELO V) geschraubt. Die volle UK-Länge in F38 ist also richtig.
- **Dielenlängen über 600 cm** (Frage 15): laut B-035 gibt es 7 m nur bei ECO SELECT, die anderen Serien haben 4/5/6 m; UK 6,5 m gibt es nicht → Fehler des alten Planers (F14).
- **Kurze Stücke verbinden** (Frage 16): Ein Stoß muss dann nicht durchgehend sein – bei nicht rechtwinkligen Terrassen darf ein kurzes Stück durch eine ganze Diele ersetzt werden. Beim Rechteck (F13) daher ohne Wirkung, das ist richtig.
- **Querstreben** (Frage 17): Abstand 60 cm (so im alten Planer hinterlegt, gewollt).

- **Grenzen der Terrassenmaße** (Frage 18): größte Seitenlänge 3000 cm (Alexander, 27.10.2026); kleinste bleibt vorläufig 50 cm.
- **UK an schrägen Rändern, Ausschnitt-, Innen- und Bogenkanten** (Frage 19): An jeder Kante, an der Dielen enden, liegt eine UK; schräge Kanten bekommen eine Rand-UK entlang der Kante, bündig, ohne Überstand. Eine Selbstkontrolle prüft alle Kanten mit Dielenenden und ergänzt eine fehlende Rand-UK mit Meldung (Planungsregeln Alexander (Planungskern v6, 11.11.2026), Regel 3.3/3.4). Umsetzung: Fachkonzept 3.11, R-C11/R-C12 in [14](14-planungsregeln.md). Bei diagonaler Verlegung bleibt der Achsabstand quer zur UK gemessen; die zusätzliche UK sind die Rand-UK an den schrägen Rändern (F03: 6 × 5000 + 8 × 4000 mm, Clips wie im alten Planer).

(Alle Antworten Alexander, 19.10.2026, sofern nicht anders angegeben.)
