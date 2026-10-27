# Geometrie-Kern (M4-01)

Grundlage für Grundriss (M4), Belag (M5) und Unterkonstruktion (M6): Flächen mit geraden und gebogenen Kanten, ihre Maße und Mengenoperationen. Liegt im domain-Paket (`packages/domain/lib/src/geometrie/`), rechnet ohne Fremdpakete und wird vom Server benutzt – die App zeigt nur an („Frontend bleibt doof“, `docs/architektur/3d-und-ar.md`).

## Bausteine

| Typ | Inhalt |
|---|---|
| `Punkt` | Punkt/Vektor in **Millimetern** (`double`): `x` nach rechts, `y` nach oben, Punkt A der Terrasse bei (0\|0), negative Werte erlaubt (Fachkonzept 1.4). Im 3D-Modell ist `x` = x, `y` = z. |
| `Kante` | Strecke oder Kreisbogen; Bogen über die **Wölbung** `tan(θ/4)` (θ = Mittelpunktswinkel, > 0 gegen den Uhrzeigersinn, ±1 = Halbkreis). Radius, Mittelpunkt, Länge, Tangenten, Abstand werden daraus exakt berechnet. |
| `Kontur` | geschlossener Linienzug aus Kanten: Fläche (exakt, auch mit Bögen), Umfang, Innenwinkel je Ecke (Grad, zwischen den Tangenten), Punkt-im-Inneren, Abstand zum Rand, Selbstüberschneidung (`istEinfach`), Verschieben, Drehen, Umkehren. `Kontur.rechteck`, `Kontur.kreis`. |
| `Flaeche` | äußere Kontur ohne Löcher: Fläche, Umfang, Mengenoperationen (`vereinigt`, `geschnitten`, `ohne`), Prüfungen `ueberschneidet`, `umschliesst`, `abstand`. |
| `verknuepfe` | Mengenoperation auf Gruppen von Flächen (`Verknuepfung.vereinigung/schnitt/differenz`), Ergebnis als Liste zusammenhängender Flächen. |

Ein Kreis ist eine Kontur aus zwei Halbkreisen – seine Fläche ist exakt π·r². Der alte Planer rechnet den Kreis als Vieleck (10,150 statt 10,179 m² bei Ø 360 cm, Fachkonzept 1.1); welcher Wert gilt, entscheidet M4-07.

## Abgrenzung zum 3D-Modell

Die Bauteile des 3D-Modells (`Bauteil`, `Quader`, M3-10) bleiben unverändert: Der Geometrie-Kern beschreibt Flächen in der Draufsicht, daraus erzeugen Belag (M5) und Unterkonstruktion (M6) die Bauteile. Die Prototyp-Funktion `rechteckTerrasse` bleibt bis dahin für den 3D-Prototyp bestehen und wird mit M5 durch die Verlegung auf einer `Flaeche` ersetzt.

## Mengenoperationen

Gewähltes Verfahren (eigener Entwurf, keine Fremdbibliothek):

1. Alle Ränder beider Seiten als Sehnenzug (Bögen mit höchstens `bogenToleranz` = 0,1 mm Abweichung).
2. Jede Strecke wird an allen **echten** Schnitt- und Berührpunkten mit den anderen geteilt; Punkte näher als 10⁻⁵ mm verschmelzen; ungerichtet gleiche Teilstücke zählen einmal und merken, auf welchen Rändern (A, B oder beiden) sie liegen.
3. Für jedes Teilstück wird ein Prüfpunkt 10⁻³ mm links davon mit der Gerade-Ungerade-Regel gegen beide Seiten geprüft; rechts davon kehrt sich die Zugehörigkeit zu jeder Seite um, auf deren Rand das Stück liegt. Gilt die Verknüpfung auf genau einer Seite, gehört das Stück zum Ergebnisrand – so ausgerichtet, dass das Ergebnis links liegt.
4. Die Stücke werden zu Ringen verkettet; an Punkten mit mehreren Fortsetzungen wird die am stärksten links abbiegende gewählt, damit sich in einer Ecke berührende Teile getrennte Flächen bleiben. Gerade durchlaufene Zwischenpunkte entfallen.
5. Ringe gegen den Uhrzeigersinn sind Außenränder, im Uhrzeigersinn Löcher; jedes Loch gehört zum kleinsten Außenrand, der es enthält.

Vorteil: deckungsgleiche Kanten, T-Stöße und Berührungen sind keine Sonderfälle – beim Einrasten an Rändern und Raster (M4-08, M4-12) sind sie der Normalfall. Verworfen: Greiner-Hormann (versagt bei deckungsgleichen Kanten ohne Zusatzregeln), Martinez-Rueda/Vatti (robust, aber deutlich aufwendiger, bei < 1000 Kanten ohne messbaren Vorteil).

Grenzen:

- Das Ergebnis hat nur gerade Kanten (Bögen als Sehnenzug). Fläche und Material des **Grundrisses** rechnen weiter exakt mit der Kontur; Mengenoperationen dienen Ausschnitten, Teilflächen und Prüfungen. Abweichung je Bogen höchstens Bogenlänge · 0,1 mm in der Fläche.
- Aufwand O(n²) in der Zahl der Teilstrecken – für Terrassen (Dutzende Kanten, Kreise ≈ 200 Sehnen) im Bereich von Millisekunden (Benchmark unten).
- Splitter dünner als 10⁻³ mm werden nicht sicher erkannt; fachlich irrelevant.

## Prüfungen für Ausschnitte und Teilflächen (M4-12)

| Fachliche Regel | Aufruf |
|---|---|
| „Der Ausschnitt darf nicht außerhalb der Terrasse sein!“ | `grundriss.umschliesst(ausschnitt)` – Rand anliegend erlaubt, Toleranz 1 mm² |
| keine Kollision zweier Ausschnitte | `!a.ueberschneidet(b)` – Berührung an Kante oder Ecke erlaubt |
| keine Teilung des Grundrisses | `grundriss.ohne(ausschnitt).length == 1` |
| Abstände (z. B. Mindestabstand) | `a.abstand(b)` |

## Tests

- Beispiel-Tests mit den Formen des alten Planers (Rechteck 540 × 360 cm, L-Form 14,58 m², Ausschnitt 180 × 120 cm, Rundung, Kreis).
- **Eigenschaftsbasiert** (`test/geometrie_eigenschaften_test.dart`, je 150 reproduzierbare Zufallsfälle): Fläche/Umfang/Winkel unabhängig von Drehung, Verschiebung und Umlaufsinn; Winkelsumme (n − 2) · 180°; Einschluss-Ausschluss |A ∪ B| + |A ∩ B| = |A| + |B| und |A ∖ B| + |A ∩ B| = |A|; Zufallspunkte liegen genau dann im Ergebnis, wenn die Verknüpfung gilt; Rasterrechtecke mit deckungsgleichen Kanten, auch gedreht, für drei Flächen; Kreis-Sehnenzug innerhalb der Toleranz.
- Die Eigenschaftstests haben beim Entwickeln einen Fehler gefunden, den kein Beispieltest zeigte: Teilungspunkte wurden auch eingetragen, wenn sich nur die Geraden zweier Strecken schnitten – deckungsgleiche Kanten wurden dann verschieden geteilt und doppelt gezählt.

## Benchmark

`domain.Geometrie.uFormMitAusschnitten` (`packages/domain/benchmark/geometrie_benchmark.dart`): U-Form 13,5 × 8,1 m mit zwei gerundeten Ecken (je ≈ 56 Sehnen), sechs Ausschnitte nacheinander abziehen (Rechtecke, Kreise Ø 1,2 und 1,8 m mit 174 bzw. 212 Sehnen, Dreieck, einer über den Rand), dazu je Ausschnitt Überschneidungs- und Einschlussprüfung und ein Abstand.

| Stand (lokal, Apple Silicon) | Wert je Messung (10 Durchläufe) | je Durchlauf |
|---|---|---|
| erster Entwurf | 138 ms | 13,8 ms |
| nur eine Seite je Teilstück prüfen, Huellrechteck je Ring vorprüfen, exakte Punkte ohne Suche | 67 ms | 6,7 ms (davon 4 ms für die sechs Differenzen) |

Eine Planungsänderung mit Ausschnitten bleibt damit im einstelligen Millisekundenbereich.

## Mutation-Tests

Gleichwertige Mutanten (Ergebnis bleibt gleich, nur andere Laufzeit oder Rechenweg) wurden durch Umformulieren vermieden, wo es ohne Verlust an Lesbarkeit ging – z. B. `reduce(math.min)` statt `math.min(a, b)` mit vertauschbaren Argumenten, Seitenvergleich `(d1 > 0) != (d2 > 0)` statt Vorzeichenprodukt, Punktregister ohne Raster. Übrig bleiben einzelne Mutanten an Toleranzgrenzen (z. B. `1 + rand` → `1 - rand`), die sich nur mit Rundungsfehlern an exakt bestimmten Stellen unterscheiden.
