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

Aus dem Abgleich mit dem Planungskern v7 (Treppe, Plausibilität, Positionen im Angebot, 12.11.2026; Nummern ab 50, weil parallele Branches 26 ff. und 40 ff. belegen):

50. **Grenzen der Seitenlängen vs. Regel 9.6:** Regel 9.6 will 0 cm und über 50 m rot (gesperrt), über 30 m gelb („wirklich?“). Der Planer sperrt nach Frage 18 alles außerhalb 50–3000 cm – 3000 cm sind genau 30 m, die gelbe Stufe kommt also nie vor. Umgesetzt: Grenzen bleiben, über 50 m kommt statt der Grenzmeldung „bitte in cm angeben“, Kanten unter 10 cm / über 30 m (z. B. aus der Freiform) als Hinweis. Soll die größte Seite auf 50 m steigen (mit Gelb ab 30 m), und soll die kleinste Seite von 50 cm auf 10 cm sinken?
51. **Treppe: Stufen aus der Höhe?** Regel 9.5.1/9.5.2 rechnet die Stufen aus der Höhe (Steigungen = Höhe ÷ 19 cm aufgerundet, Auftritte = Steigungen − 1, die oberste Stufe ist die Terrasse; Auftritt = 63 − 2 × Steigung, 26–34 cm, aus ganzen Dielen, mindestens 2). Der Planer hat wie der alte Planer eingegebene Stufen (Anzahl, Tiefe, Höhe; Vorgabe 2 × 27 × 15,6 cm) und eine Treppenhöhe unabhängig von der Terrasse (Frage 8, R-D03); bei 31,2 cm Höhe hat er 2 Auftritte, der Kern 1. Umgesetzt ist nur die Prüfliste. Soll der Planer (a) einen Knopf „Stufen aus der Höhe“ bekommen, der Anzahl und Maße nach Regel 9.5 vorbelegt (Höhe = Terrassenhöhe, änderbar), (b) die Vorgabe ändern (heute Schrittmaß 58,2 cm → Hinweis bei jeder neuen Treppe; nach Regel 9.5 z. B. 15,6 cm Steigung mit 31,8 cm Auftritt), und (c) einen Hinweis zeigen, wenn ein Auftritt aus weniger als 2 Dielen besteht?
52. **Treppe: Auflager.** Regel 9.5.3: je UK-Stück 2 Auflager (Stellfuß bzw. Unterleger nach der Stufenhöhe). Der Planer setzt bei „Konstruktion“ je UK-Holz eine Stütze aus UK-Holz an der Vorderkante, bei „Fundament“ keine (R-D02). Umstellen auf 2 Stellfüße/Pads je UK-Stück wie die Terrasse (R-C15)? Gilt das auch beim Fundament (Pads auf der Betontreppe)?
53. **Treppe: Verschraubung.** Regel 9.5.4: Auftritte und Setzstufen sichtbar verschraubt, 2 Schrauben je UK. Der Planer rechnet für die Treppe keine Befestigung (offen seit M7-05). Welche Schraube (die der sichtbaren Verschraubung der Serie, wie bei den Randdielen genuteter Dielen, Regel 4.1), und sollen sie in die Schraubenposition des Belags einfließen?
54. **Treppe: Setzstufe als ein Brett und unter der ersten Stufe.** Regel 9.5.4: Setzstufe aus einem glattkanten Brett, „Breite nach Steigung“, und ohne Seitenblende an der Kante auch zwischen Terrasse und erster Stufe. Der Planer legt so viele Reihen glattkanter Dielen, wie die Steigung braucht (15,6 cm aus 14-cm-Dielen → 2 Reihen), je sichtbarer Vorderkante. Ein Brett in passender Breite (welche, wenn keine Breite der Serie die Steigung trifft?) und die zusätzliche Setzstufe an der Terrassenkante übernehmen?
55. **„Nicht im Angebot“ für Kunden:** Das Häkchen gibt es wie die geänderten Mengen nur für Mitarbeiter; die Position steht dann auch in der Kundenansicht und im PDF als „Nicht im Angebot: …“ (mit Preis, ohne Summe). Soll sie in Kundenansicht und PDF stehen bleiben oder dort ganz entfallen?

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
