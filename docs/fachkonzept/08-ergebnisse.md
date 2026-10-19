# 08 Ergebnisse

## Speichern und Laden

- **SPEICHERN** (Kopfzeile) speichert ohne Rückfrage auf dem Server und vergibt eine **Konfigurationsnummer** im Format `JJJJ-MM-TT-NNNN` (Beispiel `2026-10-08-1511`) mit **Version** (1, 2, …).
- **LADEN** öffnet „Konfiguration laden“: Konfigurationsnummer, Version (−/+), Knöpfe „Konfiguration Speichern“ und „Konfiguration laden“.
- **ZURÜCKSETZEN** fragt nach: „Sind sie sicher, dass Sie die Planung zurücksetzen möchten? Dadurch geht ihr Fortschritt verloren. Stellen Sie sicher, dass Sie die Konfiguration gespeichert und die Konfigurationsnummer notiert haben.“ – „Zurück zur Konfiguration“ / „Konfiguration Zurücksetzen“.
- Der Browser merkt sich die letzte Planung (Startdialog „Wir haben eine Konfiguration gefunden …“).

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
