# Umstellung vom alten Planer (M10-04)

Stand 10.11.2026 – **vorbereitet, noch nicht durchgeführt.** Geplanter Umstellungstag: **1. Dezember 2026**.

Ziel (Abnahme Issue #87): Die neue Adresse `https://alto.terrassenplaner.eu/` ist live, Shop und Webseite verlinken nur noch dorthin, die alte Adresse `https://terrassenkonfigurator.robinienwelt.de/` leitet dauerhaft um.

Verantwortlich: **Alexander** für alles außerhalb des Repositorys (Shop, Webseite, DNS, Agentur, GitHub-Einstellungen); **Build-Chain** für alles, was über das Repository läuft (Ausrollen, Prüfungen). Änderungen am Server nur über einen Merge auf `main`, nie von Hand ([betriebshandbuch.md](betriebshandbuch.md)).

## Was das Repository vorbereitet hat

Ansible-Variable `planer_alte_hosts` (Rolle `planer`, Standard `[]` = keine Umleitung aktiv), für Root-Server und Container gleich:

- je Host ein Traefik-Router mit eigenem Let's-Encrypt-Zertifikat (HTTP-Prüfung über Port 80),
- HTTPS antwortet mit einer **dauerhaften Umleitung (301/308) auf `https://alto.terrassenplaner.eu/`**; Pfad und Abfrage entfallen – Lesezeichen auf Unterseiten des alten Planers landen auf der Startseite (eine Abbildung alter Pfade gibt es nicht, der Code der alten Seite wird nicht analysiert),
- HTTP leitet zuerst (dauerhaft) auf HTTPS derselben Adresse um, dann greift die Umleitung oben – zwei Schritte, beide dauerhaft,
- Molecule prüft beides in beiden Zielarten mit zwei Testadressen (`deploy/molecule/gemeinsam/tasks/umstellung.yml`).

Die alte Adresse steht **noch nicht** im Inventory `produktion`: Solange ihr DNS nicht auf den Server zeigt, kann Let's Encrypt kein Zertifikat ausstellen.

## Checkliste

### Vorbedingungen (bis spätestens 28.11.2026)

| # | Schritt | Wer |
|---|---|---|
| V1 | Build-Chain auf `main` grün (alle Gates inkl. Ansible-Lint und beider Molecule-Szenarien), letztes Deployment erfolgreich | Build-Chain, Alexander prüft |
| V2 | Neue Adresse von außen in Ordnung: `curl -I https://alto.terrassenplaner.eu/` → `200`, gültiges Produktivzertifikat | Alexander |
| V3 | Sicherung aktuell: Alarm „Sicherung veraltet“ ruhig; am Vortag zusätzlich `systemctl start planer-sicherung.service` ([sicherung.md](sicherung.md)) | Alexander |
| V4 | Monitoring: Grafana-Übersicht ohne offene Alarme, Alarm-E-Mail kommt an (SMTP-Zugang im Vault) | Alexander |
| V5 | Offene Punkte aus M10-03 entschieden: Branch-Schutz/PR-Pflicht für `main` (mit dem Go-Live), Kopie der Sicherungen außerhalb des Servers ([betriebshandbuch.md](betriebshandbuch.md), „Offene Punkte“) | Alexander |
| V6 | Offene Punkte aus M10-05 entschieden: Bestätigung „keine Webanalyse“, Freigabe der Texte (Datenschutz/Impressum-Verweise), Speicherdauer, AV-Vertrag Server ([datenschutz.md](datenschutz.md)) | Alexander |
| V7 | Offene Fragen aus M10-01 (Paritätsbericht) und M10-02 (Lasttest) beantwortet oder bewusst auf nach dem Go-Live verschoben | Alexander |
| V8 | Vertrag mit der Agentur geprüft: Kündigungsfrist, Laufzeitende, ob die alte Adresse/DNS-Verwaltung bei der Agentur liegt und wer die Umleitung einrichten darf; Webanalyse der Agentur endet mit dem alten Planer | Alexander |
| V9 | **Weg für die alte Adresse festlegen** (siehe unten): A (DNS auf unseren Server) oder B (Umleitung bei der Agentur) | Alexander |
| V10 | Nur Weg A: am Vortag die TTL des DNS-Eintrags `terrassenkonfigurator.robinienwelt.de` auf 300 s senken | Alexander |
| V11 | Liste aller Stellen mit Links auf den alten Planer: Shop (Menü, Seiten, Produktbeschreibungen, Banner, E-Mail-Vorlagen), Webseite, Newsletter-Vorlagen, Social-Media-Profile, Angebots- und Signaturvorlagen | Alexander |

### Weg A oder B für die alte Adresse

- **Weg A (empfohlen, unabhängig von der Agentur):** Der DNS-Eintrag `terrassenkonfigurator.robinienwelt.de` zeigt als A-Record auf **62.83.40.123** (kein AAAA-Eintrag, ein vorhandener CNAME wird ersetzt; ein CAA-Eintrag der Domain muss Let's Encrypt erlauben). Unser Traefik holt das Zertifikat und leitet um. Voraussetzung: Zugriff auf die DNS-Verwaltung von `robinienwelt.de`.
- **Weg B:** Die Agentur richtet auf ihrer Seite eine dauerhafte Umleitung (301) auf `https://alto.terrassenplaner.eu/` ein. `planer_alte_hosts` bleibt leer. Nachteil: Die Umleitung hängt am Vertrag mit der Agentur – endet er, ist die Adresse tot. Deshalb nur als Übergang, danach Weg A.

### Am Umstellungstag (1. Dezember 2026)

| # | Schritt | Wer |
|---|---|---|
| U1 | V1–V4 kurz wiederholen (Build-Chain grün, neue Adresse 200, Sicherung von heute Nacht vorhanden, keine Alarme) | Alexander |
| U2 | Links im **Shop** auf `https://alto.terrassenplaner.eu/` umstellen (Liste aus V11) | Alexander |
| U3 | Links auf der **Webseite** umstellen (Liste aus V11) | Alexander |
| U4 | Weg A: A-Record `terrassenkonfigurator.robinienwelt.de` → `62.83.40.123` setzen. Weg B: Agentur schaltet die Umleitung | Alexander |
| U5 | Weg A: warten, bis der neue Eintrag sichtbar ist: `dig +short terrassenkonfigurator.robinienwelt.de` → `62.83.40.123` (auch über `dig @1.1.1.1` und `dig @8.8.8.8`) | Alexander |
| U6 | Weg A: im Inventory `deploy/inventories/produktion/group_vars/all/main.yml` eintragen und über `main` ausrollen (nach dem Go-Live per Pull Request): `planer_alte_hosts: [terrassenkonfigurator.robinienwelt.de]` | Alexander / Build-Chain |
| U7 | Deployment-Job der Build-Chain grün; Traefik hat das Zertifikat geholt (`journalctl -u traefik | grep -i acme`, keine Fehler) | Build-Chain, Alexander prüft |
| U8 | Prüfschritte unten durchgehen | Alexander |
| U9 | Agentur schriftlich informieren: alter Planer wird abgeschaltet, Kündigung bzw. Vertragsende nach V8 | Alexander |
| U10 | Issue #87 erst schließen, wenn U8 erfüllt ist; `ROADMAP.md` (Haken M10-04) im selben Merge | Alexander / Build-Chain |

Zwischen U4 und U7 liefert die alte Adresse kurz ein ungültiges Zertifikat bzw. 404 von Traefik. U5–U7 deshalb direkt nacheinander und außerhalb der Hauptgeschäftszeit.

### Prüfschritte danach

```bash
# 1. Neue Adresse
curl -I https://alto.terrassenplaner.eu/
#    → HTTP/2 200

# 2. Alte Adresse über HTTPS (gültiges Zertifikat, kein -k nötig)
curl -I https://terrassenkonfigurator.robinienwelt.de/
#    → 301 (oder 308), location: https://alto.terrassenplaner.eu/

# 3. Unterseite mit Abfrage landet auf der Startseite
curl -I 'https://terrassenkonfigurator.robinienwelt.de/irgendwas?x=1'
#    → 301/308, location: https://alto.terrassenplaner.eu/

# 4. Alte Adresse über HTTP: erst HTTPS, dann neue Adresse
curl -sIL http://terrassenkonfigurator.robinienwelt.de/ | grep -iE '^(HTTP|location)'
#    → 301/308 → https://terrassenkonfigurator.robinienwelt.de/
#    → 301/308 → https://alto.terrassenplaner.eu/
#    → 200

# 5. Zertifikat der alten Adresse stammt von Let's Encrypt (Produktiv-CA)
echo | openssl s_client -connect terrassenkonfigurator.robinienwelt.de:443 \
  -servername terrassenkonfigurator.robinienwelt.de 2>/dev/null | openssl x509 -noout -issuer -dates
```

Außerdem: Shop und Webseite stichprobenartig durchklicken (Desktop und Handy), eine Planung anlegen, speichern, PDF erzeugen; Grafana-Dashboard „Nutzung“ zeigt neue Sitzungen; Alarm „Zertifikat läuft bald ab“ bleibt ruhig. Am Folgetag Zugriffe auf die alte Adresse im Traefik-Zugriffsprotokoll prüfen und nach übersehenen Links suchen.

## Rückfallplan

| Problem | Maßnahme |
|---|---|
| Neuer Planer fehlerhaft, schnell behebbar | Fehler normal beheben (Branch, Build-Chain, Merge); Umleitung bleibt |
| Fehler durch das letzte Deployment | Merge per `git revert` rückgängig machen – die Build-Chain rollt den vorigen Stand aus ([betriebshandbuch.md](betriebshandbuch.md)); Datenbank nur bei Datenschaden aus der Sicherung zurückspielen ([sicherung.md](sicherung.md)) |
| Neuer Planer nicht nutzbar, alter muss zurück | 1. Links in Shop und Webseite zurück auf die alte Adresse. 2. Weg A: alten DNS-Eintrag wiederherstellen (vorher notieren!), danach `planer_alte_hosts: []` über `main` ausrollen (entfernt die Umleitung). Weg B: Agentur nimmt die Umleitung zurück. Voraussetzung: der alte Planer läuft bei der Agentur noch – deshalb Vertrag erst kündigen bzw. auslaufen lassen, wenn der neue Planer einige Wochen stabil läuft |
| Zertifikat für die alte Adresse kommt nicht | DNS (A-Record, kein AAAA, CAA) und Port 80 prüfen, `journalctl -u traefik | grep -i acme`; bis zur Lösung kann die Agentur (Weg B) übergangsweise umleiten |

Vor U4 den bisherigen DNS-Eintrag der alten Adresse (Typ, Ziel, TTL) notieren, damit der Rückweg ohne die Agentur möglich ist.
