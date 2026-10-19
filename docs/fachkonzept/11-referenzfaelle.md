# 11 Referenzfälle (M1-02)

47 Planungsunterlagen des alten Planers (Mai–Sept. 2026), ausgewertet am 19.10.2026 – Testdaten in `packages/domain/test/referenzfaelle/` (eine JSON-Datei je PDF, Modell `Referenzfall` im domain-Paket). **Anonymisiert:** keine Namen, Adressen, Orte, Telefonnummern, E-Mails oder Projektbezeichnungen; Herstellernummern (EAN) aus den Exporten entfernt (B-023). Ein Test prüft das für jede Datei.

## Inhalt je Fall

- **Eingaben:** Grundriss (Form, Eckpunkte, Kantenmaße, Ausschnitte), Fläche, Volumen, Belag, Verlegerichtung, Ausgangspunkt, Unterkonstruktion, Verblendung, Aufbauhöhen/Winkel, UK-Abstände.
- **Erwartet:** UK-Stückliste, UK-Zuschnittplan, Dielen nach Nummer, Deckbelag-Zuschnittplan und – bei 10 Fällen mit Export – die Materialliste (Artikelnummer, Länge, Anzahl, Einheit, Typ; ohne Preise).
- Fehlende PDF-Seiten bleiben leer; Unsicheres steht in `hinweise`.

## Geprüfte Regeln (Tests, alle 47 Fälle)

- Jeder Schnitt eines Zuschnittplans passt in die Ausgangslänge (960 Zeilen).
- Stückzahl „Dielen nach Nummer“ = zugeschnittene Deckbelag-Stücke.
- Materialliste nur aus einem Export; Dateiname = Konfigurationsnummer und Version.

## Befunde zum alten Planer (für M1-03/M1-04)

- **Unvollständige PDFs:** fast alle Unterlagen sind Auszüge (meist fehlen Seiten 2–4); 8 Fälle haben nur Seite 1, Grundriss und UK-Plan.
- **Verlegerichtung:** in 3 Fällen steht auf Seite 1 „Waagrecht“, die Zeichnung zeigt eine andere Richtung.
- **Winkeltabelle** teilweise um einen Eckpunkt verschoben gegenüber der Zeichnung.
- **UK-Zuschnitt enthält kurze Stücke (8,6 / 8,7 / 11 cm), die in der UK-Stückliste fehlen:** das sind die im 90°-Winkel an den Sichtseiten angesetzten UK-Stücke, an denen die Blenden (Verblendung) befestigt werden (Alexander, 19.10.2026). Sie entstehen aus dem Zuschnitt, stehen aber nicht als eigene Position in der Stückliste – der neue Planer weist sie bei Verblendung aus.
- Exporte gelten je Konfigurationsnummer, nicht je Version – bei zwei Fällen passte die Liste nicht zur Version und wurde dort nicht übernommen.
- Fläche ohne Abzug leerer Ausschnitte (bestätigt `docs/fachkonzept/01-grundriss.md`).

## Übersicht

| Fall | Grundriss | Fläche m² | Belag | Richtung | UK | Erwartete Listen |
|---|---|---|---|---|---|---|
| 2025-08-26-719-v2 | Rechteck | 18.701 | 60 x 22 mm | Waagrecht | Holz 45 x 60 mm | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt |
| 2026-03-04-524-v18 | Freiform + 4 Ausschnitt(e) | 78.675 | 100 x 22 mm | Waagrecht | Holz 40 x 40 mm | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt |
| 2026-04-09-4323-v12 | Freiform | 49.154 | 100 x 26 mm | Waagrecht | ALUecofix XL 45x85 mm schwarz | UK-Zuschnitt, Dielen, Deck-Zuschnitt, Materialliste |
| 2026-04-13-1946-v6 | L-Form | 80.36 | 80 x 22 mm | Waagrecht | Holz 40 x 60 mm | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt |
| 2026-04-26-1265-v3 | Freiform + 1 Ausschnitt(e) | 38.84 | 60 x 22 mm | Waagrecht | Holz 40 x 60 mm | UK-Zuschnitt, Dielen, Deck-Zuschnitt |
| 2026-04-28-4413-v11 | Rechteck | 12.628 | 60 x 22 mm | Waagrecht | RELO C blank Alu-Unterkonstruktions-Schiene | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt, Materialliste |
| 2026-04-28-4836-v6 | L-Form | 12.404 | 60 x 22 mm | Waagrecht | Holz 40 x 60 mm | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt, Materialliste |
| 2026-04-28-859-v5 | Rechteck | 6.028 | 60 x 22 mm | Waagrecht | RELO C blank Alu-Unterkonstruktions-Schiene | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt |
| 2026-04-29-164-v4 | L-Form | 90.21 | 100 x 22 mm | Waagrecht | Holz 40 x 60 mm | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt |
| 2026-04-29-2412-v5 | Rechteck | – | – | – | – | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt, Materialliste |
| 2026-05-03-347-v4 | Rechteck | 20.183 | 60 x 26 mm | Waagrecht | Holz 40 x 60 mm | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt |
| 2026-05-03-4381-v2 | Rechteck | 12.282 | 80 x 26 mm | Waagrecht | Holz 40 x 60 mm | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt |
| 2026-05-03-797-v1 | Rechteck | 4.467 | 80 x 22 mm | Waagrecht | Holz 40 x 40 mm | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt |
| 2026-05-05-3156-v4 | Freiform | 91.5 | 80 x 22 mm | Waagrecht | Holz 40 x 60 mm | Materialliste |
| 2026-05-11-129-v2 | Rechteck | 36.0 | 100 x 22 mm | Waagrecht | Holz 40 x 60 mm | – |
| 2026-05-11-2229-v3 | L-Form | 30.29 | 80 x 22 mm | Waagrecht | Holz 40 x 60 mm | UK-Liste, Dielen |
| 2026-05-11-2842-v2 | Rechteck | 30.0 | 80 x 26 mm | Waagrecht | Holz 40 x 60 mm | – |
| 2026-05-12-1823-v4 | Rechteck | 31.472 | 100 x 22 mm | Waagrecht | Holz 40 x 60 mm | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt |
| 2026-05-18-3484-v3 | Rechteck | 22.33 | 100 x 26 mm | Waagrecht | ALUecofix S 45x15mm blank | – |
| 2026-05-19-3958-v4 | Rechteck | 16.4 | 80 x 22 mm | Waagrecht | ALUecofix M 45x23mm blank | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt |
| 2026-05-28-2398-v13 | Freiform + 2 Ausschnitt(e) | 25.94 | 100 x 26 mm | Senkrecht | RELO W blank Alu-Unterkonstruktions-Schiene | UK-Zuschnitt, Dielen, Deck-Zuschnitt |
| 2026-05-28-4655-v2 | Rechteck | 12.532 | 80 x 22 mm | Waagrecht | RELO C blank Alu-Unterkonstruktions-Schiene | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt |
| 2026-05-29-3162-v10 | Freiform | 55.829 | 60 x 22 mm | Senkrecht | Holz 45 x 60 mm | UK-Zuschnitt, Dielen, Deck-Zuschnitt |
| 2026-06-01-4502-v2 | Freiform | 30.977 | 60 x 22 mm | Waagrecht | Holz 40 x 60 mm | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt |
| 2026-06-03-2910-v6 | L-Form + 1 Ausschnitt(e) | 38.6 | 60 x 22 mm | Senkrecht | Holz 45 x 60 mm | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt, Materialliste |
| 2026-06-07-4340-v4 | L-Form | 20.805 | 80 x 26 mm | Waagrecht | Holz 45 x 60 mm | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt |
| 2026-06-08-766-v11 | Freiform + 2 Ausschnitt(e) | 42.774 | 60 x 22 mm | Waagrecht | Holz 45 x 60 mm | UK-Zuschnitt, Dielen, Deck-Zuschnitt |
| 2026-06-08-766-v8 | Freiform + 2 Ausschnitt(e) | 42.774 | 80 x 22 mm | Waagrecht | Holz 45 x 60 mm | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt, Materialliste |
| 2026-06-11-3389-v3 | Rechteck | 10.53 | 60 x 22 mm | Waagrecht | Holz 40 x 60 mm | Dielen, Deck-Zuschnitt |
| 2026-06-15-1093-v7 | L-Form | 25.06 | 60 x 22 mm | Waagrecht | Holz 40 x 60 mm | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt, Materialliste |
| 2026-06-24-363-v10 | Freiform | 36.528 | 60 x 22 mm | Waagrecht | RELO C blank Alu-Unterkonstruktions-Schiene | UK-Zuschnitt, Dielen, Deck-Zuschnitt |
| 2026-06-24-363-v3 | Freiform | 34.461 | 60 x 22 mm | Waagrecht | Holz 45 x 60 mm | UK-Zuschnitt, Dielen, Deck-Zuschnitt, Materialliste |
| 2026-06-25-1275-v3 | Rechteck | 3.0 | 100 x 22 mm | Waagrecht | Holz 40 x 40 mm | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt |
| 2026-06-30-2295-v5 | Rechteck | 243.25 | 80 x 26 mm | Waagrecht | ALUecofix XL 45x85 mm blank | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt, Materialliste |
| 2026-07-07-2794-v2 | Rechteck | 105.0 | 60 x 22 mm | Waagrecht | Holz 40 x 40 mm | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt |
| 2026-07-25-1952-v3 | T-Form | 15.9 | 100 x 26 mm | Senkrecht | RELO C blank Alu-Unterkonstruktions-Schiene | – |
| 2026-07-31-3374-v3 | T-Form | 16.563 | 50 x 23 mm | Waagrecht | Holz 40 x 40 mm | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt |
| 2026-07-31-3374-v5 | T-Form | 16.563 | 60 x 22 mm | Senkrecht | Holz 40 x 40 mm | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt |
| 2026-08-06-2810-v3 | Rechteck | 24.0 | 60 x 22 mm | Waagrecht | Holz 45 x 60 mm | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt |
| 2026-08-13-4194-v3 | T-Form | 37.445 | 80 x 22 mm | Senkrecht | RELO C blank Alu-Unterkonstruktions-Schiene | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt |
| 2026-08-13-4194-v5 | T-Form | 37.445 | 80 x 22 mm | Senkrecht | Holz 40 x 40 mm | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt |
| 2026-08-13-4194-v9 | T-Form + 1 Ausschnitt(e) | 37.445 | 80 x 22 mm | Senkrecht | Holz 40 x 40 mm | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt |
| 2026-08-17-1838-v2 | Rechteck | 11.61 | ROBI-FIXX Terrassenfliese Robinie | Waagrecht | Holz 40 x 60 mm | Dielen, Deck-Zuschnitt |
| 2026-08-26-1067-v2 | Rechteck | 21.21 | 60 x 22 mm | Senkrecht | RELO C blank Alu-Unterkonstruktions-Schiene | UK-Liste, UK-Zuschnitt, Dielen, Deck-Zuschnitt |
| 2026-09-03-3980-v8 | Freiform | 105.837 | 60 x 22 mm | Senkrecht | RELO C blank Alu-Unterkonstruktions-Schiene | – |
| 2026-09-15-3615-v3 | Freiform | 31.83 | 100 x 23 mm | Waagrecht | RELO W blank Alu-Unterkonstruktions-Schiene | – |
| 2026-09-15-3615-v6 | Rechteck | 16.5 | 100 x 23 mm | Waagrecht | RELO W blank Alu-Unterkonstruktions-Schiene | – |
