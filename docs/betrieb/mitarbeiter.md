# Mitarbeiter-Konten verwalten

Stand M9-10 (04.11.2026). Mitarbeiter melden sich im Planer mit E-Mail-Adresse und Passwort an (ANMELDEN in der Kopfzeile) und dürfen dann u. a. Konfigurationen ohne Prüfcode laden. Kunden bleiben anonym. **Keine Selbstregistrierung:** Konten entstehen nur mit dem Werkzeug `mitarbeiter` auf dem Server.

## Befehle

| Befehl | Wirkung |
|---|---|
| `anlegen <email>` | neues Konto; Passwort über stdin |
| `passwort <email>` | neues Passwort (z. B. vergessen); eine Sperre bleibt bestehen |
| `sperren <email>` | Anmeldung nicht mehr möglich (Konto bleibt erhalten) |
| `entsperren <email>` | Sperre aufheben |
| `liste` | alle Konten, gesperrte mit „(gesperrt)“ |

- Die E-Mail-Adresse ist der Anmeldename; sie wird klein geschrieben gespeichert (`Anna@…` = `anna@…`).
- Das Passwort wird **nie als Argument** übergeben (es stünde sonst in der Prozessliste und im Shell-Verlauf): am Terminal verdeckt und zur Kontrolle zweimal, sonst eine Zeile über stdin. Mindestens 12 Zeichen.
- Das Werkzeug leitet aus dem Passwort die SCRAM-Schlüssel ab (Argon2id, 19 MiB, 2 Durchläufe, zufälliges Salt) und schickt nur sie an den Auth-Server. Gespeichert werden weder Passwort noch etwas, aus dem es sich ohne Durchprobieren zurückrechnen ließe.
- Exit-Code: 0 gut, 1 vom Auth-Server abgelehnt (z. B. Konto gibt es schon / nicht), 64 falscher Aufruf.

## Erstes Konto anlegen

**Root-Server (systemd)** – als root, das Ansible-Deployment legt das Werkzeug unter `/usr/local/sbin/planer-mitarbeiter` an (liest Adresse und Ticket aus `/etc/terrassenplaner/planer-auth.env`):

```bash
ssh happysrv
planer-mitarbeiter anlegen burkhardt@robinienwelt.de     # Passwort zweimal eingeben
planer-mitarbeiter liste
```

**Container-Betrieb** – im Auth-Container:

```bash
docker exec -it terrassenplaner-auth-1 /app/bin/mitarbeiter anlegen burkhardt@robinienwelt.de
```

Danach im Planer ANMELDEN → „Login“ mit E-Mail-Adresse und Passwort. Die Kopfzeile zeigt ABMELDEN, die Statuszeile „Angemeldet als …“.

## Fehlversuche und Sperren

- Nach **5 Fehlversuchen** ist ein Konto **15 Minuten** gesperrt (connectanum zählt je Anmeldename im Router, `RouterEinstellungen.anmeldeGrenzen`); eine erfolgreiche Anmeldung setzt den Zähler zurück. Die Zählung liegt im Arbeitsspeicher – ein Neustart des Routers hebt die Sperre auf.
- Ein mit `sperren` gesperrtes Konto bleibt gesperrt, bis `entsperren` es freigibt. Für den Planer sieht beides aus wie ein falsches Passwort.
- Mitarbeiter verlässt das Unternehmen: `sperren`. Bestehende Sitzungen enden spätestens beim Schließen des Browsers bzw. nach Verbindungsabbruch (es gibt keine dauerhaften Anmeldungen).

## Technik

- Konten liegen in der ObjectBox-Datenbank des Auth-Servers (`PLANER_DATENVERZEICHNIS`, Entität `Benutzer`). ObjectBox erlaubt nur einen Prozess je Datenbank, deshalb schreibt das Werkzeug nicht selbst, sondern ruft Verwaltungsprozeduren des Auth-Servers auf (`verwaltung.mitarbeiter.*`, RawSocket nur auf `127.0.0.1` bzw. im internen Container-Netz, Anmeldung mit dem Dienst-Ticket `PLANER_AUTH_DIENST_TICKET`, eigene Rolle `verwaltung` nur für diese Prozeduren).
- Umgebung des Werkzeugs: `PLANER_AUTH_ADRESSE` (sonst `PLANER_AUTH_LISTEN`, Standard `127.0.0.1:8082`) und `PLANER_AUTH_DIENST_TICKET`. Neue Geheimnisse gibt es nicht.
- Entwicklung: `cd packages/server && dart run bin/mitarbeiter.dart liste` mit denselben Variablen; ohne `PLANER_DATENVERZEICHNIS` hält der Auth-Server Konten nur im Arbeitsspeicher (so legt `tool/smoke.sh` sein Testkonto an).
