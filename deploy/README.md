# Deployment (Ansible)

Ein Playbook für beide Betriebsarten (`planer_betriebsart`):

| Betriebsart | Was entsteht |
|---|---|
| `systemd` (Root-Server) | Traefik (offizielles Release, Prüfsumme) als systemd-Dienst mit Let's Encrypt, zwei getrennte Dienste `planer-auth` und `planer-router` (eigene Benutzer, `PrivateTmp`), Web-App über nginx auf 127.0.0.1 |
| `container` | Docker Compose: Traefik (Ports 80/443), `router` und `web` hinter Traefik, `auth` nur im internen Netz |

Gemeinsam: Firewall (nftables, von außen nur 22/80/443), SSH nur mit Schlüssel (erst wenn `authorized_keys` vorhanden ist), automatische Sicherheitsupdates, Health-Prüfung nach dem Start.

## Rollen

`planer` (gemeinsame Werte: Ports, Pfade, Benutzer) · `grundsystem` · `traefik` · `planer_dienste` · `planer_web` · `container`

## Einmalig: Geheimnisse (Alexander)

```bash
cd deploy
ansible-vault create inventories/produktion/group_vars/all/vault.yml
```

Inhalt wie `vault.example.yml` – zwei verschiedene Zufallswerte, z. B. aus `openssl rand -base64 48`. Das Vault-Passwort kennt nur Alexander; es liegt lokal in `~/.ansible/vault-terrassenplaner` (nur für ihn lesbar, `ansible.cfg` verweist darauf), damit es nicht bei jedem Lauf abgefragt wird.

## Ausrollen

```bash
tool/artefakte_holen.sh                       # Linux-Artefakte des letzten grünen main-Laufs
cd deploy
ansible-playbook playbooks/site.yml
```

Für Tests ohne Rate-Limit: `-e planer_letsencrypt_ca=staging`. Container-Betrieb: `-e planer_betriebsart=container`.

## Ports (nur lokal, außer 80/443)

Router 8080 (WebSocket `/ws`, über Traefik), Router-Health 8081, Auth-Server 8082 (nur Router), Auth-Health 8083, Web-App 8090, Traefik-Ping 8092.

## Tests

- `ansible-lint` (Profil production) mit `ansible-pruefung.cfg` – ohne Produktions-Inventar und Vault.
- Molecule-Szenarien `systemd` und `container` (`deploy/molecule/`): frisches Debian 13 mit systemd im privilegierten Docker-Container, dasselbe Playbook wie in Produktion, Idempotenz-Prüfung und Verify (Dienste, Health, HTTPS über Traefik, WASM-Header, Weiterleitung, WebSocket 101, interne Ports nur lokal, Firewall, SSH, Rechte der Geheimnisse; Container: Healthchecks, Auth-Server nur im internen Netz). Läuft in der Build-Chain mit den Linux-Artefakten des Build-Jobs; lokal braucht es Docker:

```bash
cd deploy && pip install -r requirements-test.txt && ansible-galaxy collection install community.docker ansible.posix
PLANER_ARTEFAKTE=$PWD/../artefakte molecule test -s systemd
```
