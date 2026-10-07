# Monitoring (M0-13/M0-14, 07.10.2026)

## Aufbau

| Teil | systemd (Root-Server) | Container |
|---|---|---|
| Prometheus | Debian-Paket, `127.0.0.1:9090`, 30 Tage | `prom/prometheus`, internes Netz |
| Node-Exporter | Debian-Paket, `127.0.0.1:9100` | `prom/node-exporter` |
| Grafana | offizielles Paketarchiv, `127.0.0.1:3000`, über Traefik `https://metrics.terrassenplaner.eu` | `grafana/grafana`, Traefik-Labels |

Ziele: Router (`127.0.0.1:8081/metrics`, OpenMetrics von connectanum_router), Auth-Server (`:8083`), Datenbank-Kennzahlen des Auth-Servers (`:8084`, eigener Endpunkt), Server (Node-Exporter), Traefik (`:8092`), Prometheus selbst. Grafana: Anmeldung Pflicht (admin, Passwort aus Vault), keine Telemetrie, Datenquelle/Dashboard/Alarme per Provisioning aus dem Repository.

## Alarme (E-Mail an burkhardt@robinienwelt.de)

Postausgang `smtps.udag.de:465` (Absender monitoring@robinienwelt.de, Zugang `vault_smtp_benutzer`/`vault_smtp_passwort`). Ohne SMTP-Zugang im Vault bleibt der Versand aus, die Regeln laufen trotzdem.

| Regel | Bedingung |
|---|---|
| Dienst nicht erreichbar | `up < 1` für 2 min (auch bei fehlenden Daten) |
| Platte fast voll | > 85 % für 10 min |
| Zertifikat läuft bald ab | < 14 Tage für 1 h |
| Ungewöhnlich viele WAMP-Sitzungen | > 500 für 10 min |

## Neue WAMP-Dienste

Weitere WAMP-Server in `roles/monitoring/templates/prometheus.yml.j2` (Job `wamp`) bzw. im Container-Pendant eintragen – das Dashboard und die Alarme greifen über die Labels `job`/`dienst` automatisch.
