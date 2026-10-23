# Artikelmodell (M2-01)

Fachmodell der Planer-Artikel im Paket `domain` (`lib/src/artikel/`) – unabhängig vom Importformat der Master-Artikelliste (Blatt „Import Terrassenplaner“, M2-02).

## Einheiten (`einheiten.dart`)

Keine nackten Zahlen für Maße, Gewichte und Preise – Dart-Extension-Types ohne Laufzeitkosten:

| Typ | Basis | Umrechnung |
|---|---|---|
| `Millimeter` | ganze mm | `ausCm`, `ausM`, `cm`, `m`; Rechnen und Vergleichen |
| `Gramm` | ganze g | `ausKg`, `kg` |
| `Cent` | ganze Cent | `ausEuro`, `euro`, `anzeige` („2.066,57 €“) – Preise nur Anzeige (B-055) |

`Mengeneinheit` (Stück, lfm, m², VPE, Karton, Set, Kiste, l) liest die Schreibweisen der Quellen („St.“, „VE“, „SET“ …). `Verkaufseinheit` = Einheit + Inhalt (z. B. „Karton zu 100 Stück“) und rechnet einen Bedarf auf ganze Verkaufseinheiten auf.

Hinweis für den Import: Die Maßspalten des Planer-Blatts heißen `_cm`, enthalten aber Millimeter – der Importer erzeugt daraus direkt `Millimeter`.

## Artikel (`artikel.dart`)

- `Artikelnummer` – fachlicher Schlüssel wie im Shop (B-152); zwei Artikel sind gleich, wenn die Nummer gleich ist.
- `Artikelart` mit `Bereich` (Belag, Unterkonstruktion, Befestigung, Auflager, Anschluss, Zubehör): Diele, Systemdiele, Holzfliese, Holz-/Alu-UK, Clip, Schraube, Stellfuß, Pad, Pad unter Stellfuß, Bodenanker, Längs-/Quer-/Eck-/variabler Verbinder, Blendenhalter, Verblendung, Rinne, Rinnenzubehör, Gummiband, Pflege, Werkzeug, Dienstleistung, Sonstiges. Die Typ-Texte des alten Planers (`Stellfuss,Zubehoer`, `_Unterrinne` …) bildet erst der Importer darauf ab.
- `Abmessungen` – Breite, Stärke, lieferbare Längen (aufsteigend, ohne Doppelte; `laengste` für Freidielen R-B09).
- Holzartikel (Diele, Systemdiele, Holz-UK) tragen `Holzart` und `Serie` (die Serie muss zur Holzart gehören) und ggf. `Profil`/`Oberseite`; andere Artikel keins von beiden.
- Bis zu drei Abbildungen (Profilansicht, Stirnseite, Profilzeichnung).
- Nur Verkaufsdaten – Einstandspreise, Werks-EK, Lieferanten und Werks-Nomenklatur kommen nie ins Modell (B-020, B-021).

## Holzart (`lib/src/holzart/`, M2-08)

Alle holzabhängigen Planungseigenschaften sind **Daten**: `Holzart` mit Rechengewicht (kg/m³), UK-Achsabstand (max./empfohlen), „zwei Schrauben ab“ und je `Serie` die `Serienregeln` – Dielenformate je Profil, Lieferlängen, gültige UK-Formate (zwei Seitenmengen, tauschbar), nur ungetrocknet lieferbare UK-Formate und „DUO-CLIP-FIXX ab“. Daraus folgen Befestigung, Schrauben je Punkt, Formatprüfung und Gewicht.

- `robinie` wird aus dem Datensatz `robinieDaten` gelesen (Quellen B-030 ff., Regelkatalog 14). Serien heißen nur BASIC, ECO SELECT, PREMIUM SELECT, MASSIV – keine Werke (B-020).
- Eine weitere Holzart (z. B. Kastanie) entsteht nur aus Daten über `Holzart.ausJson` – ein Test mit einer Beispiel-Holzart belegt das.
- Holzunabhängige Firmenregeln (Fuge 5 mm, Wandabstand 2 cm, Querstreben 60 cm, Freidielen-Staffel) stehen in `lib/src/regeln/planungsregeln.dart`.

## Regelwerk „was passt zu was“ (`lib/src/regeln/regelwerk.dart`, M2-04)

`Regelwerk` arbeitet nur auf der Artikeldatei – keine Auswahl ist im Code fest verdrahtet. Jede `Beziehung` entspricht einer Verweis-Spalte der Upload-Datei (Befestigung, Zubehör, Stellfüße privat/gewerblich, Unterlegpads, Längs-/Quer-/Eck-/variable Verbinder, Verblendung, Drainage, Start-/End-Clip).

- `moeglich(nummer, beziehung)` liefert die Artikel in Datenreihenfolge – so wie der alte Planer dieselben Spalten anzeigt; `stellfuesse(nummer, gewerblich:)` wählt die passende Spalte.
- `pflichtzubehoer` liefert das benötigte Zubehör mit Anzahl, `abstaende` die Abstände (Stelzfüße, UK, Randabstand), Min-/Max-Höhe und den Schalter „Reichweite“, `imBereich` z. B. alle Beläge.
- `befestigungWiderspruch` vergleicht die Befestigungsverweise mit der Firmenregel der Holzart (B-094, B-090: genutet nur Clips, glattkant nur Schrauben). Die Datenprüfung meldet einen Widerspruch als FEHLER – so kann die Upload-Datei keine falsche Befestigung in den Planer bringen.
- Die Artikeldatei schlägt Nummern über einen Index nach (Benchmark `domain.Regelwerk.auswahlJeBelag`: 50 Beläge × alle Beziehungen ≈ 0,4 ms).

Upload-Datei v6: alle 47 Beläge haben Befestigung, Zubehör, Verblendung und Drainage; kein Befestigungswiderspruch.
