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
| Sicherung veraltet (M10-03) | älteste letzte Sicherung > 26 h, auch bei fehlenden Daten |
| Sicherung unvollständig (M10-03) | < 3 Datenbestände gemeldet (Grafana, Router, Auth-Server) |
| Arbeitsspeicher knapp (M10-03) | < 10 % verfügbar für 10 min |
| Prozessor dauerhaft ausgelastet (M10-03) | > 90 % für 15 min |
| Platte läuft voll (M10-03) | `predict_linear` über 6 h: in 24 h voll, für 30 min |
| Datenbank nahe der Größengrenze (M10-03) | > 768 MB (ObjectBox-Grenze 1 GB) für 30 min |
| Viele Serverfehler (M10-03) | > 5 % HTTP-5xx über Traefik für 10 min |

Seit M10-03 meldet auch der Router seine Datenbank-Kennzahlen (`127.0.0.1:8085`, Konfigurationen), und der Node-Exporter liest Textdateien aus `/var/lib/prometheus/node-exporter` (Sicherungszeitpunkte). Was bei welchem Alarm zu tun ist: `docs/betrieb/betriebshandbuch.md`.

Dashboard „Terrassenplaner – Nutzung“ (M10-05, `files/dashboards/nutzung.json`): Statistik ohne Personenbezug aus denselben Metriken – Sitzungen, gespeicherte Konfigurationen/Versionen je Tag (`delta` der Datensatzzahl), RPC-Aufrufe, Web-Anfragen. Grenze: Prometheus hält 30 Tage.

## Neue WAMP-Dienste

Weitere WAMP-Server in `roles/monitoring/templates/prometheus.yml.j2` (Job `wamp`) bzw. im Container-Pendant eintragen – das Dashboard und die Alarme greifen über die Labels `job`/`dienst` automatisch.
