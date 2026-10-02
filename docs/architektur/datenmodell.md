# Datenmodell und Schlüssel für eine spätere Verteilung (Stand 02.10.2026)

Vorgaben Alexander (02.10.2026):
- **Sternstruktur:** Das Frontend spricht ausschließlich über den/die WAMP-Router mit den Backend-Diensten auf unserem Server; nur diese greifen auf die Datenbank zu.
- **Frontend bleibt „doof“:** keine Fachlogik-Hoheit, keine Datenhaltung – lokal nur Bedienungseinstellungen (Darkmode, Sprache, zuletzt geöffnete Konfiguration).
- **Datenbank: ObjectBox** (eingebettet im Backend-Dienst). Die Daten werden von Anfang an mit Schlüsseln versehen, die eine spätere Verteilung/Synchronisation über WAMP ermöglichen; die verteilte Datenhaltung selbst kommt erst in einem späten Meilenstein (M11), wenn es Performance-Bedarf gibt.

## Grundregeln für alle gespeicherten Daten

| Regel | Begründung |
|---|---|
| **Globale ID je Datensatz:** `uid` = UUIDv7 (zeitlich sortierbar), als String mit eindeutigem Index (`@Unique`). | ObjectBox-`@Id` (int64) wird pro Datenbank lokal vergeben und ist auf einem zweiten Knoten ein anderer Wert. Er bleibt intern und wird **nie** nach außen gegeben oder für Verweise genutzt. |
| **Fachliche Schlüssel, wo das Geschäft sie vorgibt:** Artikelnummer (wie im Shop, B-152), Konfigurationsnummer `JJJJ-MM-TT-NNNN` + Version. | Funktional 1:1 zum alten Planer; Verweise zwischen Diensten laufen über diese Schlüssel. |
| **Partitionsschlüssel in jedem Datensatz** (Feld `partition`). Alles, was zusammen gelesen/geschrieben wird, hat denselben Partitionsschlüssel. | Bestimmt später, auf welchem Knoten Daten liegen – Abfragen bleiben dann auf einem Knoten. |
| **Versionen unveränderlich (append-only):** eine Konfigurationsversion wird nie überschrieben, Änderungen erzeugen Version n+1. | Unveränderliche Datensätze lassen sich konfliktfrei replizieren und cachen. |
| **Herkunft und Zeit:** `erstelltAm`/`geaendertAm` als Hybrid Logical Clock (HLC) + `knoten` (ID des schreibenden Knotens). | Eindeutige Reihenfolge über Knoten hinweg, Grundlage für Konfliktlösung (M11). |
| **Löschen = Grabstein:** Feld `geloeschtAm` statt physischem Löschen; Aufräumen nach Frist. | Löschungen müssen sich wie Änderungen verteilen; Datenschutz-Fristen gezielt umsetzen. |
| **Änderungsprotokoll ab Tag 1:** jede schreibende Transaktion legt einen Eintrag `(knoten, seq, entität, uid, partition, hlc, art)` in derselben Transaktion an. | Lückenlose Grundlage für Replikation (M11), Audit und Monitoring (Rückstand). |
| **Schema-Version** in Datensätzen mit eingebetteten Dokumenten (`schema`). | Knoten mit unterschiedlichem Softwarestand können Daten erkennen und migrieren. |

## Entitäten nach Meilenstein

### Referenzdaten – überall vollständig repliziert (lesen viel, schreiben selten)

| Entität | Meilenstein | Schlüssel | Partition | Inhalt |
|---|---|---|---|---|
| `Artikel` | M2-01/02 | `artikelnummer` (fachlich, eindeutig) + `uid` | `global` | Verkaufsdaten aus „Import Terrassenplaner“ (nie EK, B-020), Maße in mm, Einheit, VPE, Preis (Anzeige, B-055), Artikeltyp, Bilder |
| `Artikelregel` | M2-04 | `uid`; fachlich `(artikelnummer, regelart, zielartikelnummer)` | `global` | Abhängigkeiten: Befestigung, Stellfüße privat/gewerblich, Pads, Verbinder, Verblendung, Drainage, Pflichtzubehör mit Anzahl, Abstände, Min-/Max-Höhe |
| `Datenstand` | M2-06 | `version` (fortlaufend je Import) + `uid` | `global` | Zeitpunkt, Quelle (Master-Version), Prüfbericht – App lädt Artikel passend zum Datenstand |
| `Benutzer` (Mitarbeiter) | M0-08, M9-10 | `authid` | `global` | Rolle, Anmeldeverfahren-Daten (nur abgeleitete Schlüssel, nie Klartext-Passwörter) |

### Bewegungsdaten – partitioniert nach Konfiguration

| Entität | Meilenstein | Schlüssel | Partition | Inhalt |
|---|---|---|---|---|
| `Konfiguration` | M9-05 | `konfigurationsnummer` + `uid` | `konfigurationsnummer` | Kopf: Projektbezeichnung, Status, aktuelle Version, erstellt/geändert, Datenstand |
| `KonfigurationsVersion` | M9-05 (Inhalte aus M4–M8) | `(konfigurationsnummer, version)` + `uid` | `konfigurationsnummer` | unveränderliches Dokument (schema-versioniert): Grundriss (Form, Eckpunkte, Rundungen, Ausschnitte), Belag (Artikel, Längen, Verlegeart/-richtung, Ausgangspunkt, Befestigung), UK (Art, Höhenpunkte, Untergrund, Nutzung, Querstreben, Auflagen, Feldbreite), Anschluss/Rinnen/Treppen, Zubehör-Auswahl, Verschnittvariante |
| `Ergebnis` (Cache) | M9-01–M9-04 | `(konfigurationsnummer, version, art)` | `konfigurationsnummer` | berechnete Material-/Stückliste, Zuschnittspläne, Verschnitt – jederzeit aus der Version neu berechenbar, daher verwerfbar |
| `Zwischenstand` | M9-05 (Autosave), M3-02 „Weiterplanen“ | `sitzungsschluessel` (zufällig, im Browser gespeichert) | `sitzungsschluessel` | letzter ungespeicherter Stand; Ablauf nach Frist (TTL) |
| `Angebotsanfrage` | M9-07 | `uid` | `konfigurationsnummer` | Kontaktdaten (personenbezogen!), Notiz, Einverständnis, Versandstatus; Löschfrist und Auskunft nach DSGVO |

### Nicht in der Datenbank

- **Frontend-Einstellungen** (Darkmode, Sprache, letzte Konfigurationsnummer): nur lokal im Browser.
- **PDF, GrandTotal-Export, Warenkorb-Link** (M9-06/08/09): werden bei Bedarf aus Version + Datenstand erzeugt.
- **Messwerte/Benchmarks:** Prometheus bzw. Dateien, nicht ObjectBox.

## Konfigurationsnummer ohne zentrale Abstimmung

Format bleibt `JJJJ-MM-TT-NNNN` (funktional 1:1). Solange es einen Knoten gibt, vergibt der Konfigurationsdienst `NNNN` fortlaufend je Tag. Für die Verteilung (M11) erhält jeder Knoten **Nummernblöcke** je Tag (z. B. Knoten 1: 0001–2999, Knoten 2: 3000–5999), damit Nummern ohne Rückfrage eindeutig bleiben. Die Partition ist die Konfigurationsnummer – alle Versionen, Ergebnisse und Anfragen einer Konfiguration liegen beisammen.

## Verteilung später (M11)

1. **Referenzdaten:** ein Schreiber (Import-Dienst), Verteilung an alle Knoten per Pub/Sub + Nachholen per RPC ab Sequenznummer.
2. **Bewegungsdaten:** Zuordnung Partition → Knoten (konsistentes Hashing über die Konfigurationsnummer); Schreiben nur auf dem Eigentümer-Knoten, Lesekopien optional.
3. **Konflikte** entstehen nur, falls später mehrere Schreiber je Partition zugelassen werden; dann HLC-basiert „jüngste Änderung gewinnt“ je Feld – dank unveränderlicher Versionen selten relevant.
4. **Transport:** WAMP-Topics/RPCs über die Router-Sternstruktur; mit FlatBuffers-Serialisierung in connectanum möglichst ohne Umkodieren im Router.
