/// Planungsregeln von ALTO HOLZ, die nicht von der Holzart abhängen (M1-04,
/// Regelkatalog `docs/fachkonzept/14-planungsregeln.md`). Holzabhängige
/// Regeln stehen in der Holzart (M2-08).
library;

import '../artikel/einheiten.dart';

/// Abstand der Querstreben (Leiterverband) (R-C03, Alexander).
const querstrebenAbstand = Millimeter(600);

/// Höchster Abstand der Querstreben-Reihen bei der Nutzungsart Versteifung
/// (Leiterverband, M6-05). Annahme aus den Referenzkonfigurationen F31/F33:
/// der alte Planer setzt bei 309 cm UK-Länge zwei Reihen – das ergibt
/// höchstens der doppelte Querstreben-Abstand.
const versteifungsAbstand = Millimeter(1200);

/// Abstand der Auflager längs der UK, wenn die Artikeldaten der UK keinen
/// nennen (M6-08): 60 cm wie `Abstand_Stelzfuesse` der Robinien-UK ab
/// 40 × 60 mm; mit ihm stehen in F28 je UK-Linie à 309 cm sieben Auflager
/// (13 × 7 = 91 Bodenanker wie im alten Planer).
const auflagerAbstandVorgabe = Millimeter(600);

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

/// Wandabstand der Terrasse (R-C10, Alexander 19.10.2026).
const wandabstand = Millimeter(20);

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
