# Betriebshandbuch Terrassenplaner

Stand M10-03 (05.11.2026). Für den Produktivbetrieb auf dem Root-Server `alto.terrassenplaner.eu`; der Container-Betrieb verhält sich gleich, Unterschiede stehen jeweils dabei. Grundsatz: **Änderungen am Server nur über das Repository und die Build-Chain** – nie von Hand auf dem Produktivserver. Handarbeit beschränkt sich auf Lesen, Sicherung/Wiederherstellung im Notfall und die offenen Punkte unten.

## Überblick

| Teil | Root-Server (systemd) | Container | Erreichbar |
|---|---|---|---|
| Traefik (TLS, Let's Encrypt) | `traefik.service` | `traefik` | 80/443 öffentlich, Ping/Metriken `127.0.0.1:8092` |
| WAMP-Router + Dienste | `planer-router.service`, Benutzer `planer-router` | `router` | WebSocket `/ws` über Traefik; Health `127.0.0.1:8081`, DB-Kennzahlen `127.0.0.1:8085` |
| Auth-Server | `planer-auth.service`, Benutzer `planer-auth` | `auth` (nur internes Netz) | `127.0.0.1:8082`, Health `:8083`, DB-Kennzahlen `:8084` |
| Web-App | nginx `127.0.0.1:8090` | `web` | über Traefik |
| Prometheus / Node-Exporter | `127.0.0.1:9090` / `:9100` | internes Netz | nur intern |
| Grafana | `127.0.0.1:3000` | `grafana` | `https://metrics.terrassenplaner.eu` (Anmeldung) |
| Sicherung | `planer-sicherung.timer` (03:15) | gleich (auf dem Wirt) | – |

Daten: `/var/lib/terrassenplaner/<dienst>/datenbank` (ObjectBox), Artikeldatei `/var/lib/terrassenplaner/planer-router/artikel.json`, Artikelbilder `/var/lib/terrassenplaner/artikelbilder`; im Container in den Volumes `terrassenplaner_*-daten`. Geheimnisse: `/etc/terrassenplaner/*.env` (0600, aus dem Vault).

## Ausrollen und Zurückrollen

- **Ausrollen:** Merge auf `main` → Build-Chain (Analyse, Tests, Mutation, Smoke, Benchmarks, Build, Ansible-Lint, Molecule für beide Zielarten) → Job „Deployment Produktion“ führt `ansible-playbook playbooks/site.yml` aus und prüft von außen HTTPS, WebAssembly und WebSocket.
- **Zurückrollen:** den fehlerhaften Merge auf `main` per `git revert` rückgängig machen und pushen – die Build-Chain rollt den vorherigen Stand aus. Datenbanken bleiben dabei unberührt; nur wenn eine Änderung Daten beschädigt hat, zusätzlich eine Sicherung zurückspielen ([sicherung.md](sicherung.md)).
- **Notfall ohne Build-Chain** (GitHub nicht erreichbar): `tool/artefakte_holen.sh` und `cd deploy && ansible-playbook playbooks/site.yml` von Alexanders Rechner (Vault-Passwort lokal) – nur mit demselben Stand wie `main`.

## Alarme und was zu tun ist

Alarme kommen per E-Mail an `burkhardt@robinienwelt.de` (Grafana, Kontaktweg „Alarm-E-Mail“, Wiederholung alle 4 h). Regeln: `deploy/roles/monitoring/defaults/main.yml`.

| Alarm | Bedeutung | Erste Schritte |
|---|---|---|
| Dienst nicht erreichbar | Ein Prometheus-Ziel antwortet 2 min nicht | `systemctl status <dienst>`, `journalctl -u <dienst> -n 200`; systemd startet Dienste nach Fehlern selbst neu (`Restart=on-failure`). Container: `docker compose ps`, `docker compose logs <dienst>` |
| Platte fast voll (> 85 %) | | `df -h`, `du -sh /var/backups/terrassenplaner /var/lib/* /var/log/journal`; ggf. Aufbewahrung kürzen (Variablen, Merge) |
| Platte läuft voll | Verbrauch der letzten 6 h füllt die Platte binnen 24 h | Ursache suchen (Sicherungen, Journal, Datenbankwachstum) |
| Zertifikat läuft bald ab (< 14 Tage) | Traefik verlängert normalerweise 30 Tage vorher | `journalctl -u traefik | grep -i acme`; DNS-Eintrag und Port 80 prüfen |
| Ungewöhnlich viele WAMP-Sitzungen (> 500) | Last oder Fehlverhalten | Grafana-Übersicht, Traefik-Zugriffe |
| Arbeitsspeicher knapp (< 10 % frei) | | `systemctl status` je Dienst (Speicher), Grafana/Prometheus sind begrenzt (M0-17) |
| Prozessor dauerhaft ausgelastet (> 90 %) | 15 min Dauerlast | `top`; Router-Last in Grafana |
| Datenbank nahe der Größengrenze (> 768 MB) | ObjectBox-Grenze 1 GB je Datenbank, danach schlagen Schreibzugriffe fehl | Grenze im Code anheben (`maxDBSizeInKB`) oder aufräumen (Grabsteine, alte Zwischenstände) – Entwicklungsaufgabe |
| Viele Serverfehler (> 5 % 5xx) | | `journalctl -u traefik`, Journal von Router und nginx |
| Sicherung veraltet / unvollständig | Seit über 26 h keine gelungene Sicherung bzw. ein Bestand fehlt | `journalctl -u planer-sicherung`, Journal des betroffenen Dienstes; `systemctl start planer-sicherung.service` |

## Sicherung und Wiederherstellung

Siehe [sicherung.md](sicherung.md): tägliche Online-Sicherung der ObjectBox-Datenbanken (mit Probe-Wiederherstellung durch den Dienst) und der Grafana-Datenbank, 14 Tage plus 12 Wochensicherungen; Wiederherstellung mit `planer-wiederherstellung <router|auth> <datei>`, in Molecule bei jeder Build-Chain getestet.

## Härtung

- **Netz:** nftables, von außen nur 22/80/443; alle internen Dienste auf 127.0.0.1 bzw. internen Container-Netzen. Prometheus nie öffentlich, Grafana nur mit Anmeldung.
- **SSH:** nur Schlüssel (sobald `authorized_keys` vorhanden), `PermitRootLogin prohibit-password`, keine leeren Passwörter, kein X11-Forwarding, `LoginGraceTime 30`.
- **Kernel** (`/etc/sysctl.d/90-planer.conf`): Kernel-Zeiger und `dmesg` verborgen, kein unprivilegiertes BPF, JIT-Härtung, Schutz für FIFOs/Dateien in Sticky-Verzeichnissen, SYN-Cookies, keine ICMP-Redirects und kein Source-Routing. Auf virtualisierten Containern (LXC/OpenVZ, Molecule) wird die Datei nur abgelegt.
- **Dart-Dienste (systemd):** eigener Benutzer, `NoNewPrivileges`, keine Capabilities, `ProtectSystem=strict` mit Schreibrecht nur im eigenen Datenverzeichnis, `PrivateTmp`, `PrivateDevices`, Schutz von Kernel-Einstellungen/-Modulen/-Logs, Cgroups, Uhr und Hostname, keine Namespaces, nur IPv4/IPv6/Unix/Netlink, `UMask=0077` (Datenbank und Sicherungskopie nur für den Dienst lesbar), `LimitNOFILE=65536` für viele WebSockets.
- **Dart-Dienste (Container):** `no-new-privileges`, alle Capabilities entfernt, Wurzeldateisystem nur lesbar (`/tmp` als tmpfs, Daten im Volume), Benutzer `planer`.
- **Updates:** `unattended-upgrades` spielt Sicherheitsupdates täglich ein. Neustarts nach Kernel-Updates erfolgen nicht automatisch – siehe Routine.

## Log-Rotation

- **Journal** (Dienste, Traefik-Zugriffe): höchstens 1 GB, Einträge älter als **14 Tage** werden gelöscht (`/etc/systemd/journald.conf.d/90-planer.conf`). Die Frist begrenzt zugleich, wie lange IP-Adressen aus Zugriffsprotokollen vorliegen (Datenschutz, M10-05).
- **Container:** je Container höchstens 5 × 10 MB (`json-file` mit `max-size`/`max-file`).
- **nginx:** `/var/log/nginx` über `logrotate` (Debian-Standard, täglich, 14 Rotationen).

## Routine

| Wann | Was |
|---|---|
| täglich (automatisch) | Sicherung 03:15, Sicherheitsupdates, Zertifikatsverlängerung bei Bedarf |
| wöchentlich | Grafana-Übersicht ansehen (Fehlerquote, Speicher, Platte, Sicherungsgröße) |
| monatlich | Neustart nach Kernel-Updates, falls `/run/reboot-required` existiert (`ssh happysrv test -f /run/reboot-required`) – außerhalb der Geschäftszeit; danach Health in Grafana prüfen |
| vierteljährlich | Wiederherstellung einer Sicherung auf einem Testsystem (Molecule läuft ohnehin bei jedem Push) und Kopie außerhalb des Servers prüfen, sobald eingerichtet |

## Offene Punkte (Alexander)

Diese Punkte brauchen Kontoeinstellungen oder neue Geheimnisse und werden nicht im Repository erledigt:

1. **Branch-Schutz für `main` und PR-Pflicht** (GitHub → Settings → Branches/Rulesets): Merge nur per Pull Request, Pflicht-Prüfungen = alle Jobs der Build-Chain (inkl. Ansible-Lint und beider Molecule-Szenarien), kein Force-Push, keine Löschung. Danach `CLAUDE.md` („keine Pull Requests“ → „Merge nur per PR“) anpassen. Zeitpunkt: mit dem Go-Live.
2. **Kopie der Sicherungen außerhalb des Servers:** Ziel festlegen (z. B. Speicherbox/zweiter Server, möglichst in einem anderen Rechenzentrum), SSH-Schlüssel bzw. Zugangsdaten und ein Verschlüsselungs-Passwort in den Vault (`vault_sicherung_extern_*`). Danach ergänzt die Rolle `sicherung` den Versand (z. B. `restic` über SFTP, verschlüsselt) und eine Prüfung im Monitoring.
3. **SMTP-Zugang für Alarme** (`vault_smtp_benutzer`/`vault_smtp_passwort`), falls noch nicht im Vault – ohne ihn laufen die Regeln, verschicken aber nichts.
4. **GitHub-Umgebung `produktion`:** Secrets `DEPLOY_SSH_KEY`, `ANSIBLE_VAULT_PASSWORD`, Variable `DEPLOY_KNOWN_HOSTS` prüfen; optional Pflicht-Freigabe (Reviewer) für Deployments.
5. **Datenbankgröße:** Standardgrenze von ObjectBox 1 GB je Datenbank; der Alarm warnt ab 768 MB. Sobald M10-02 (Lasttest) Zahlen liefert, Grenze bewusst festlegen.
