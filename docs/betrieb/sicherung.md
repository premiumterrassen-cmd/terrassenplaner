# Sicherung und Wiederherstellung

Stand M0-17 (08.10.2026). Rolle `deploy/roles/sicherung`, in beiden Betriebsarten aktiv.

## Was gesichert wird

| Daten | Quelle | Verfahren |
|---|---|---|
| Grafana (Benutzer, Einstellungen, Alarmzustand) | Root-Server: `/var/lib/grafana/grafana.db`; Container: Volume `terrassenplaner_grafana-daten` | `sqlite3 .backup` (konsistent im laufenden Betrieb) |
| ObjectBox (Planer-Daten) | – | folgt mit M10-03 |

Dashboards, Datenquellen und Alarmregeln liegen versioniert im Repository und werden beim Deployment neu provisioniert; sie brauchen keine Sicherung. Prometheus-Messdaten (30 Tage) werden bewusst nicht gesichert.

## Zeitplan und Ablage

- Timer `planer-sicherung.timer`: täglich 03:15 Uhr (±10 min), holt verpasste Läufe nach (`Persistent=true`).
- Ablage `/var/backups/terrassenplaner/grafana-JJJJMMTT-HHMMSS.db`, nur root (0700/0600), Aufbewahrung 14 Tage.
- Sofort sichern: `systemctl start planer-sicherung.service`, Ergebnis: `journalctl -u planer-sicherung`.

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

Die Sicherungen liegen auf demselben Server. Eine Kopie außerhalb des Servers gehört zu M10-03.
