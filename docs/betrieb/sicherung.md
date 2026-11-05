# Sicherung und Wiederherstellung

Stand M10-03 (05.11.2026). Rolle `deploy/roles/sicherung`, in beiden Betriebsarten aktiv. Gesamtüberblick über den Betrieb: [betriebshandbuch.md](betriebshandbuch.md).

## Was gesichert wird

| Daten | Quelle | Verfahren | Ablage |
|---|---|---|---|
| Konfigurationen (Router, M9-05) | ObjectBox `planer-router/datenbank` bzw. Volume `terrassenplaner_router-daten` | Online-Kopie durch den Dienst (SIGUSR1), Probe-Wiederherstellung, gzip | `objectbox-router-JJJJMMTT-HHMMSS.mdb.gz` |
| Mitarbeiter-Zugänge (Auth-Server) | ObjectBox `planer-auth/datenbank` bzw. Volume `terrassenplaner_auth-daten` | wie oben | `objectbox-auth-….mdb.gz` |
| Grafana (Benutzer, Einstellungen, Alarmzustand) | Root-Server: `/var/lib/grafana/grafana.db`; Container: Volume `terrassenplaner_grafana-daten` | `sqlite3 .backup` (konsistent im laufenden Betrieb) | `grafana-….db` |

Nicht gesichert, weil aus dem Repository bzw. der Build-Chain wiederherstellbar: Programme, Web-App, Dashboards, Datenquellen, Alarmregeln, Ansible-Konfiguration. Prometheus-Messdaten (30 Tage) werden bewusst nicht gesichert. Die Artikeldatei (`artikel.json`) und die Artikelbilder kommen aus dem Importer (M2-06/M2-07) und lassen sich dort neu erzeugen. Das Zertifikat (`acme.json`) holt Traefik bei Verlust neu.

## Warum die Dienste ihre Datenbank selbst kopieren

ObjectBox erlaubt **einen Prozess je Datenbank** – das Sicherungsskript kann die Datei nicht selbst öffnen, und eine Dateikopie von außen wäre bei gleichzeitigen Schreibzugriffen nicht stimmig. Ablauf (`Sicherungsdienst`, `packages/server/lib/src/datenhaltung/sicherung.dart`):

1. Das Skript löscht `<ablage>/stand` und schickt dem Dienst `SIGUSR1` (`systemctl kill -s SIGUSR1` bzw. `docker kill -s SIGUSR1`).
2. Der Dienst kopiert `data.mdb` in einer Schreibtransaktion (andere Schreiber warten so lange, wenige Millisekunden je MB) nach `<ablage>/.entstehend/`.
3. **Probe-Wiederherstellung:** Der Dienst öffnet die Kopie als eigene Datenbank und vergleicht die letzte Sequenznummer des Änderungsprotokolls mit dem Original beim Kopieren. Weicht sie ab oder lässt sich die Kopie nicht öffnen, bricht die Sicherung ab.
4. Erst dann liegt die Kopie unter `<ablage>/data.mdb`, zuletzt schreibt der Dienst `<ablage>/stand` (`<unix-sekunden> <sequenz>`).
5. Das Skript komprimiert die Kopie in die Ablage, löscht die Arbeitskopie und meldet den Erfolg an Prometheus.

`<ablage>` ist `PLANER_SICHERUNG_ZIEL`: auf dem Root-Server `/var/lib/terrassenplaner/<dienst>/sicherung`, im Container `/daten/sicherung` im Volume des Dienstes. Fehler beenden den Dienst nicht; sie stehen im Journal des Dienstes (`Sicherung fehlgeschlagen: …`), das Skript wartet bis 120 s und meldet dann den Fehler.

## Zeitplan, Ablage, Aufbewahrung

- Timer `planer-sicherung.timer`: täglich 03:15 Uhr (±10 min), holt verpasste Läufe nach (`Persistent=true`). Beim Ausrollen läuft einmal sofort eine Sicherung, falls noch keine Erfolgsmeldung vorliegt.
- Ablage `/var/backups/terrassenplaner/`, nur root (0700/0600).
- Aufbewahrung: tägliche Sicherungen **14 Tage**; sonntags zusätzlich eine Wochensicherung in `woche/` (harter Link, kein zusätzlicher Platz), **12 Wochen**. Variablen `sicherung_aufbewahrung_tage`, `sicherung_aufbewahrung_wochen`.
- Sofort sichern: `systemctl start planer-sicherung.service`, Ergebnis: `journalctl -u planer-sicherung`.

## Überwachung

Das Skript schreibt je Datenbestand eine Textdatei für den Node-Exporter (`/var/lib/prometheus/node-exporter/planer_sicherung_<name>.prom`) mit `planer_sicherung_erfolg_zeitstempel_sekunden{daten=…}` und `planer_sicherung_groesse_bytes{daten=…}` – nur bei Erfolg. Grafana-Alarme:

- **Sicherung veraltet** – älteste der drei letzten Sicherungen über 26 Stunden alt (auch bei fehlenden Daten).
- **Sicherung unvollständig** – weniger als drei Datenbestände (Grafana, Router, Auth-Server) gemeldet.

## Wiederherstellung ObjectBox (Router oder Auth-Server)

```bash
ls -1t /var/backups/terrassenplaner/objectbox-router-*.mdb.gz | head   # Stand wählen
planer-wiederherstellung router /var/backups/terrassenplaner/objectbox-router-<stempel>.mdb.gz
planer-wiederherstellung auth   /var/backups/terrassenplaner/objectbox-auth-<stempel>.mdb.gz
```

Das Skript (beide Betriebsarten gleich zu bedienen):

1. prüft die Datei (`gzip -t`) – erst danach wird etwas angehalten,
2. hält den Dienst an (`systemctl stop` bzw. `docker stop`),
3. legt die bisherige Datenbank als `data.mdb.vor-wiederherstellung-<stempel>` daneben,
4. entpackt die Sicherung mit dem Besitzer des Datenverzeichnisses, entfernt `lock.mdb`,
5. startet den Dienst und wartet bis zu zwei Minuten auf „gesund“ (Health-Endpunkt bzw. Docker-Healthcheck).

Danach prüfen: Planer öffnen, eine bekannte Konfiguration laden; in Grafana `planer_datenbank_sequenz` und `planer_datenbank_datensaetze`. Die Datei `data.mdb.vor-wiederherstellung-*` von Hand löschen, sobald alles stimmt. Schlägt der Start fehl, nennt das Skript die alte Datei – zurück mit demselben Verfahren (Dienst stoppen, Datei zurückbenennen, starten).

Hinweis Router: Während der Wiederherstellung (wenige Sekunden) sind keine WAMP-Verbindungen möglich; die Web-App verbindet sich danach selbst neu. Konfigurationen, die nach dem Sicherungszeitpunkt gespeichert wurden, fehlen danach – ihre Nummern können neu vergeben werden.

## Getestet

- **Unit-Tests** (`packages/server/test/sicherung_test.dart`): Kopie, Probe-Wiederherstellung (auch der Fehlerfall), Wiederherstellen und Öffnen mit allen Datensätzen, Reste abgebrochener Läufe, Fehler ohne Absturz.
- **Molecule** (beide Betriebsarten, jede Build-Chain): Sicherung aller drei Bestände, `gzip -t`, Rechte 0600, Meldungen beim Node-Exporter; dann **Wiederherstellung von Auth-Server und Router** aus der jüngsten Sicherung, Dienste wieder gesund, Sequenz und Datensätze wie vorher, alter Stand liegt daneben; falsche Aufrufe werden abgelehnt.

## Wiederherstellung Grafana

Root-Server:

```bash
systemctl stop grafana-server
install -o grafana -g grafana -m 0640 /var/backups/terrassenplaner/grafana-<stempel>.db /var/lib/grafana/grafana.db
systemctl start grafana-server
```

Container:

```bash
cd /opt/terrassenplaner-container && docker compose stop grafana
ziel=$(docker volume inspect -f '{{ .Mountpoint }}' terrassenplaner_grafana-daten)
install -o 472 -g 0 -m 0640 /var/backups/terrassenplaner/grafana-<stempel>.db "$ziel/grafana.db"
docker compose start grafana
```

## Offen: Kopie außerhalb des Servers

Die Sicherungen liegen auf demselben Server – bei Verlust des Servers sind sie mit weg. Eine externe Kopie (z. B. Speicherbox oder zweiter Server per `rsync`/`restic` über SSH, verschlüsselt) braucht ein Ziel mit Zugangsdaten im Vault und wird von Alexander festgelegt (siehe Betriebshandbuch, offene Punkte). Bis dahin: vor größeren Änderungen eine Sicherung von Hand herunterladen (`scp happysrv:/var/backups/terrassenplaner/objectbox-*-<stempel>.mdb.gz .`).
