/// Planungsregeln von ALTO HOLZ, die nicht von der Holzart abhängen (M1-04,
/// Regelkatalog `docs/fachkonzept/14-planungsregeln.md`). Holzabhängige
/// Regeln stehen in der Holzart (M2-08).
library;

import '../artikel/einheiten.dart';

/// Raster der Querhölzer (Aussteifung als Leiter, R-C03): 75 cm, von Feld
/// zu Feld versetzt (Planungsregeln Alexander (Planungskern v6,
/// 11.11.2026), Regel 3.7; Entscheidung Alexander 11.11.2026 – vorher
/// 60 cm).
const querstrebenAbstand = Millimeter(750);

/// Höchster Abstand der Querstreben-Reihen bei der Nutzungsart Versteifung
/// (Leiterverband, M6-05). Annahme aus den Referenzkonfigurationen F31/F33:
/// der alte Planer setzt bei 309 cm UK-Länge zwei Reihen – das ergibt
/// höchstens 120 cm.
const versteifungsAbstand = Millimeter(1200);

/// Abstand der Auflager längs der UK, wenn die Artikeldaten der UK keinen
/// nennen (M6-08): 60 cm wie `Abstand_Stelzfuesse` der Robinien-UK ab
/// 40 × 60 mm; mit ihm stehen in F28 je UK-Linie à 309 cm sieben Auflager
/// (13 × 7 = 91 Bodenanker wie im alten Planer).
const auflagerAbstandVorgabe = Millimeter(600);

/// Kürzestes Reststück, wenn eine UK-Linie länger als die längste
/// Lieferlänge gestückelt wird (Planungsregeln Alexander (Planungskern v6,
/// 11.11.2026), Regel 3.5; `ukStueckelung`).
const ukMindestReststueck = Millimeter(500);

/// Das erste und das letzte Auflager einer UK liegen so weit vom Ende der UK
/// (Planungsregeln Alexander (Planungskern v6, 11.11.2026), Regel 3.6; Kern:
/// „Die UK muss immer am Anfang und Ende aufliegen.“).
const auflagerRandabstand = Millimeter(50);

/// Eine UK bis zu dieser Länge bekommt nur ein Auflager in der Mitte
/// (Planungsregeln Alexander (Planungskern v6, 11.11.2026), Regel 3.6).
const auflagerEinzelnBis = Millimeter(120);

/// Dielen kommen mit dieser Überlänge (Planungsregeln Alexander
/// (Planungskern v6, 11.11.2026); Shoptext „teilweise geringe Überlänge“):
/// Eine Lieferlänge nimmt Stücke bis zu ihrer Länge plus Überlänge auf –
/// 6,00 m Fläche liegt ohne Stoß auf einer 6-m-Diele, 2 × 3,00 m passen in
/// eine 6-m-Diele. Ein Dielenstoß ist erst über der längsten Lieferlänge
/// plus Überlänge nötig. Holzfliesen haben keine.
const dielenUeberlaenge = Millimeter(30);

/// Fuge zwischen zwei Dielen (R-B06): 6 mm, eine Reihe ist Dielenbreite
/// plus Fuge – Planungsregeln Alexander (Planungskern v6, 11.11.2026),
/// Regel 1.2; Entscheidung Alexander 11.11.2026 ersetzt die 5 mm vom
/// 19.10.2026.
const fuge = Millimeter(6);

/// Clips zu den Kreuzungen Diele–UK: Kreuzungen + 5 %, aufgerundet auf ganze
/// Clips – Planungsregeln Alexander (Planungskern v6, 11.11.2026) Regel 4.1.
/// Verpackt wird danach in VPE 250/100/50 (`verpackt`).
int clipsMitZuschlag(int kreuzungen) => (kreuzungen * 105 + 99) ~/ 100;

/// Ab dieser Packungsgröße liegt CLIP-FIXX ein TX20-Bit bei (Planungskern v6
/// Regel 4.2). Die Artikeldaten führen das nicht – die Grenze steht deshalb
/// hier.
const clipBitAbVpe = 100;

/// Ab dieser Packungsgröße liegt DUO-CLIP-FIXX ein TX20-Bit bei
/// (Planungskern v6 Regel 4.2).
const duoClipBitAbVpe = 250;

/// Ab dieser Packungsgröße ist ein Schraubenset mit TX25-Bit (600er-Set,
/// Planungskern v6 Regel 4.3).
const schraubenBitAbVpe = 600;

/// Terrassenöl je m² Holzfläche (R-D05, Mengenfaktor aus realen Projekten;
/// automatische Menge im Zubehör, M8-02).
const oelJeQuadratmeter = 0.2;

/// Ab dieser Anzahl Hauptdielen gibt es Freidielen (R-B09, B-079).
const freidielenAbDielen = 25;

/// Freidielen zur Anzahl der Hauptdielen des Deckbelags (R-B09, B-079,
/// Alexander 19.10.2026): ab 25 eine, ab 50 zwei, ab 100 je weitere 50 eine.
int freidielen(int hauptdielen) => hauptdielen < freidielenAbDielen
    ? 0
    : hauptdielen < 50
    ? 1
    : 2 + (hauptdielen - 50) ~/ 50;

/// Stärke aus Altdaten: „22 mm“ gibt es nicht, gemeint ist 21 mm (R-A04,
/// B-032).
Millimeter normierteStaerke(Millimeter staerke) =>
    staerke == const Millimeter(22) ? const Millimeter(21) : staerke;
