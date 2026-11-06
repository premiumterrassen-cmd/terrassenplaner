# Statistik und Datenschutz

Stand M10-05 (05.11.2026). **Entwurf** – die technischen Festlegungen sind umgesetzt; die Texte unten sind Formulierungshilfen und **nicht rechtlich verbindlich**. Verbindliche Texte (Datenschutzerklärung im Shop, ggf. Hinweise in der App) gibt Alexander frei, bei Bedarf nach Prüfung durch den Datenschutzbeauftragten bzw. eine Kanzlei.

## Entscheidungsvorlage Webanalyse

Der alte Planer nutzt eine Webanalyse des Agenturanbieters (mit Cookie-Hinweis). Für den neuen Planer drei Wege:

| | A: keine Webanalyse, Statistik aus dem Server (umgesetzt) | B: eigene Webanalyse ohne Cookies (z. B. Matomo selbst betrieben) | C: Analyse eines Drittanbieters |
|---|---|---|---|
| Cookies / Speicherzugriff zu Analysezwecken | keine | keine (cookielos), aber Fingerprinting-Nähe prüfen | ja |
| Einwilligungsbanner (§ 25 TDDDG) | nicht nötig | voraussichtlich nicht nötig, rechtlich zu prüfen | nötig |
| Auftragsverarbeitung / Drittland | keine | keine (eigener Server) | AV-Vertrag, ggf. Drittland |
| Aussagekraft | Sitzungen, Aufrufe, gespeicherte Planungen, Last – keine Wege durch die Seiten, keine Herkunft | Seitenwege, Herkunft, Geräte | wie B, plus Werbe-Abgleich |
| Aufwand | erledigt (Grafana) | eigener Dienst, Wartung, Speicher | Einbindung, Banner, Verträge |

**Empfehlung und Umsetzung (Standard bis zur Entscheidung):** Weg A. Der Planer setzt keine Cookies und lädt beim Start nichts von Dritten; die Statistik kommt aus den ohnehin vorhandenen, zusammengefassten Betriebszahlen. Damit braucht der Planer **keinen Cookie-Hinweis**. Wünscht Alexander Weg B oder C, ist das ein eigenes Issue (Banner, Einwilligungsverwaltung, Texte).

## Bestandsaufnahme: welche Daten der Planer verarbeitet

| Daten | Wo | Zweck | Dauer |
|---|---|---|---|
| IP-Adresse, Zeitpunkt, Browserkennung | Verbindung zu Traefik/Router (nur im Arbeitsspeicher) | Auslieferung, WebSocket-Verbindung | Dauer der Verbindung |
| Zugriffsprotokoll von Traefik | Journal auf dem Server | Fehlersuche, Missbrauchsabwehr | **ohne IP-Adresse und Benutzername** (seit M10-05), Löschung nach 14 Tagen |
| Bedienungseinstellungen (Darkmode, Sprache, Sitzungsschlüssel) | Browser (`localStorage`) | vom Nutzer gewünschte Darstellung, automatischer Zwischenstand | bis der Nutzer sie löscht; kein Cookie, nicht an Dritte |
| Zwischenstand der Planung | Server (ObjectBox, Router) | Fortsetzen nach Neuladen | bis zum Ablauf (`ablaufAm`) |
| Gespeicherte Konfigurationen (Nummer + Prüfcode) | Server (ObjectBox) | Speichern/Laden, Anfrage | unbefristet (siehe offene Punkte) |
| Kontaktdaten aus „Konfiguration anfordern“ (sofern erfasst) | siehe M9 | Angebot | siehe offene Punkte |
| Mitarbeiter-Zugänge | Server (ObjectBox, Auth-Server) | Anmeldung | bis zur Löschung des Zugangs |
| Sicherungen | `/var/backups/terrassenplaner` | Wiederherstellung | 14 Tage, Wochensicherungen 12 Wochen |
| Statistik | Prometheus (nur Summen, keine Personen) | Betrieb, Nutzungsstatistik | 30 Tage |

## Was technisch sichergestellt ist

- **Keine Cookies, keine Analyse-Skripte**, kein Tracking-Pixel. Lokal nur Bedienungseinstellungen (CLAUDE.md, „Frontend bleibt doof“).
- **Keine Anfragen an Dritte beim Laden:** Renderer (CanvasKit/Skwasm) und Schrift (Roboto) liefert der eigene Server (M0-16, M3-01). Seit M10-05 auch die **Ersatzschriften**: Flutter würde für Zeichen, die Roboto nicht kennt, Schriften bei `fonts.gstatic.com` nachladen – `fontFallbackBaseUrl` zeigt jetzt auf den eigenen Server (`/schriften-ersatz/`, dort bewusst leer, Antwort 404). Alle Texte des Planers liegen in Roboto (geprüft 05.11.2026); unbekannte Zeichen aus Eingaben (z. B. Emoji) erscheinen als Ersatzkästchen statt Google zu fragen.
- **3D-Ansicht** (`model-viewer`): Die Decoder für Draco/Basis-Kompression lägen bei gstatic.com; die Modelle des Planers (GLB aus `modell3d`) sind unkomprimiert, die Decoder werden daher nie geladen. Wer später komprimierte Modelle einführt, muss die Decoder selbst ausliefern.
- **Zugriffsprotokoll ohne IP-Adresse:** Traefik verwirft `ClientAddr`, `ClientHost`, `ClientPort` und `ClientUsername`, Kopfzeilen werden ohnehin nicht protokolliert. Im Container-Betrieb schreibt Traefik kein Zugriffsprotokoll.
- **Journal 14 Tage** (M10-03), danach gelöscht.
- **Externe Links** (AGB, Datenschutz, Impressum, Video-Beratung) öffnen die Seiten des Shops erst beim Anklicken.

## Statistik (ohne Personenbezug)

Grafana-Dashboard **„Terrassenplaner – Nutzung“** (`deploy/roles/monitoring/files/dashboards/nutzung.json`), nur nach Anmeldung unter `metrics.terrassenplaner.eu`:

- gleichzeitige Planer-Sitzungen (WAMP) und Höchstwert je Tag,
- neu gespeicherte Konfigurationen und Versionen je Tag, Bestand gesamt,
- Dienstaufrufe (RPC) je Minute,
- HTTP-Anfragen an die Web-App je Tag (einschließlich aller Dateien – kein Maß für „Besucher“).

Alle Werte sind Summen über alle Nutzer; es gibt keine Kennung, die einen Nutzer über Sitzungen hinweg wiedererkennt. Prometheus bewahrt sie 30 Tage auf; längere Reihen (Monats-/Jahresvergleich) wären ein eigenes Thema (z. B. tägliche Summen in eine Datei schreiben).

## Textbausteine für die Datenschutzerklärung (Entwurf)

> **Terrassenplaner.** Wenn Sie unseren Terrassenplaner unter alto.terrassenplaner.eu nutzen, verarbeiten wir die für die Verbindung technisch nötigen Daten (IP-Adresse, Zeitpunkt, Browserangaben) nur für die Dauer der Verbindung. In unseren Server-Protokollen speichern wir keine IP-Adressen; die Protokolle werden nach 14 Tagen gelöscht. Der Planer setzt keine Cookies und verwendet keine Analyse- oder Werbedienste. In Ihrem Browser speichert er nur Ihre Bedienungseinstellungen (z. B. Sprache, helle/dunkle Darstellung) und einen zufälligen Sitzungsschlüssel, damit Ihre Planung nach einem Neuladen erhalten bleibt. Wenn Sie eine Planung speichern, erhalten Sie eine Konfigurationsnummer mit Prüfcode; die Planung liegt auf unserem Server in Deutschland [Ort/Anbieter prüfen]. Rechtsgrundlage: Art. 6 Abs. 1 lit. b DSGVO (Planung auf Ihren Wunsch) bzw. lit. f (sicherer Betrieb); § 25 Abs. 2 Nr. 2 TDDDG für die Speicherung im Browser.

> **Nutzungsstatistik.** Wir werten ausschließlich zusammengefasste Zahlen aus (z. B. Anzahl gleichzeitiger Sitzungen, gespeicherter Planungen), die keinen Rückschluss auf einzelne Personen zulassen.

Platzhalter in eckigen Klammern vor Freigabe füllen; Speicherdauer der Konfigurationen und der Anfragedaten ergänzen, sobald entschieden.

## Offene Punkte (Alexander)

1. **Entscheidung Webanalyse** A/B/C (Empfehlung A, umgesetzt).
2. **Freigabe der Texte** für die Datenschutzerklärung des Shops (Planer-Abschnitt); ggf. Prüfung durch Datenschutzbeauftragten/Kanzlei.
3. **Speicherdauer** gespeicherter Konfigurationen und der Anfragedaten („Konfiguration anfordern“) festlegen – danach Löschlauf (Grabsteine + Aufräumen) als eigenes Issue.
4. **Auftragsverarbeitung** mit dem Server-Anbieter (Root-Server) prüfen bzw. abschließen.
5. Verzeichnis der Verarbeitungstätigkeiten um den Planer ergänzen.
