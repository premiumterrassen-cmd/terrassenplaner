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

Inhalt wie `vault.example.yml` – zwei verschiedene Zufallswerte, z. B. aus `openssl rand -base64 48`. Das Vault-Passwort kennt nur Alexander.

## Ausrollen

```bash
tool/artefakte_holen.sh                       # Linux-Artefakte des letzten grünen main-Laufs
cd deploy
ansible-playbook playbooks/site.yml --ask-vault-pass
```

Für Tests ohne Rate-Limit: `-e planer_letsencrypt_ca=staging`. Container-Betrieb: `-e planer_betriebsart=container`.

## Ports (nur lokal, außer 80/443)

Router 8080 (WebSocket `/ws`, über Traefik), Router-Health 8081, Auth-Server 8082 (nur Router), Auth-Health 8083, Web-App 8090, Traefik-Ping 8092.
