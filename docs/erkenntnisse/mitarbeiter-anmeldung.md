# Mitarbeiter-Anmeldung (M9-10, 04.11.2026)

## Entscheidungen

- **Verfahren: WAMP-SCRAM aus connectanum** (`wamp-scram`), wie in M0-08 vorbereitet. Das Passwort verlässt den Browser nie, auch nicht verschlüsselt; der Server speichert nur `StoredKey`/`ServerKey` mit Salt. Ticket wäre einfacher, schickt aber das Passwort zum Server; WAMP-CRA ist veraltet.
- **Schlüsselableitung: Argon2id** (`argon2id13`, 19 MiB, 2 Durchläufe, 16 Byte Salt – OWASP-Empfehlung) statt PBKDF2 (M0-08: 100.000 Durchläufe). connectanum bietet beides; Argon2id ist speicherhart und damit auf GPUs teurer zu knacken. Rechenaufwand fällt nur im Browser (Web Worker von connectanum mit hash-wasm) und einmal im Verwaltungswerkzeug an, nie im Auth-Server.
- **Sitzung statt Token:** Nach der Anmeldung hält die App eine WAMP-Sitzung mit Rolle `mitarbeiter` offen und schickt alle Aufrufe darüber (anonym: eine kurze Sitzung je Aufruf). Das Passwort wird nach dem Handschlag verworfen (`ScramAuthentication.dispose`); nichts landet im Browser-Speicher. Neu laden oder Verbindungsabbruch = abgemeldet.
- **Laden ohne Prüfcode:** `KonfigurationsDienst` registriert mit `disclose_caller`; der Router setzt `caller_authrole` selbst (Aufrufer können es nicht vorgeben, geprüft). Mitarbeiter laden mit Nummer allein (Prüfcode fehlt oder falsch), die Antwort bringt die vollständige Kennung mit – SPEICHERN führt dann dieselbe Nummer weiter. LADEN antwortet jetzt `[inhalt, kennung]`.
- **Konten verwalten über WAMP statt Datei:** `PLANER_MITARBEITER_DATEI` und `bin/mitarbeiter_zugang.dart` entfallen (die Datei hätte bei jedem Start geänderte Passwörter zurückgesetzt). `bin/mitarbeiter.dart` ruft Verwaltungsprozeduren im Auth-Realm auf, weil ObjectBox nur einen Prozess je Datenbank erlaubt (Betrieb: `docs/betrieb/mitarbeiter.md`).
- **Fehlversuche:** connectanum-eigene Sperre im Planer-Realm (`RealmLimitSettings`: 5 Fehlversuche → 15 Minuten), Ende-zu-Ende getestet. Dazu dauerhafte Sperre je Konto (`Benutzer.gesperrt`); gesperrt sieht aus wie unbekannt.
- **Kopfzeile:** Nur ANMELDEN bzw. ABMELDEN; „Angemeldet als …“ steht in der Statuszeile. Beschriftungen jetzt ab 1800 px (`Kopfzeile.textAb`, Deutsch braucht 1800 px).

## Befunde für Alexander (connectanum 3.0.0-beta.8)

1. **Sperre nach Fehlversuchen nur im Router-Worker:** `AuthSecurityTracker` ist statischer Zustand je Isolat. Bei Remote-Anmeldung zählt und prüft der Router-Worker; der `AuthServer` zählt ebenfalls (`_recordFailure`), prüft `isLocked` aber nie. Bei mehreren Worker-Isolaten bekommt ein Angreifer `maxFailedAuth × Worker` Versuche, und nach einem Neustart ist alles vergessen. Wunsch: Prüfung (auch) im AuthServer oder ein austauschbarer Speicher für den Tracker.
2. **Schein-Herausforderung verrät Konten:** `fakeChallengeOnHelloFailure` antwortet für unbekannte Konten mit PBKDF2/2000 Durchläufen ohne `kdf`. Echte Konten (Argon2id bzw. PBKDF2 mit anderen Durchläufen) sind daran unterscheidbar. Wunsch: Parameter der Schein-Herausforderung konfigurierbar bzw. wie das Realm-Standardverfahren.
3. **`memory:`-Datenbank nach `close()` (beobachtet):** Eine ObjectBox-`memory:`-Datenbank mit gleichem Namen behält im selben Prozess nach `close()` ihren Inhalt (Tests nutzen deshalb eindeutige Namen) – ObjectBox, nicht connectanum.

## Tests

- Server: `zugriff_test.dart` (echter Auth-Prozess: Rolle, Sperre nach Fehlversuchen, gesperrtes Konto, Laden ohne Prüfcode nur für Mitarbeiter), `auth_server_prozess_test.dart` (Verwaltung über WAMP, Rollen trennen Anmeldung und Verwaltung), `mitarbeiterkonten_test.dart`, `mitarbeiter_werkzeug_test.dart`, `konfigurations_dienst_test.dart` (Kunde kann sich nicht als Mitarbeiter ausgeben).
- App: `planer_verbindung_test.dart` (Anmelden gegen echten Router und Auth-Prozess, Abmelden, Verbindungsabbruch), `anmeldung_test.dart` (Dialog, Kopfzeile, LADEN ohne Prüfcode), `sprache_test.dart` (kein Überlauf, an- und abgemeldet).
- Smoke (`integration_test/anmeldung_test.dart`): SPEICHERN → ANMELDEN (falsch, dann richtig; Argon2id im Browser) → LADEN mit Nummer allein → ABMELDEN → Nummer allein ist wieder „unbekannt“. Das Testkonto legt `tool/smoke.sh` je Lauf mit Zufallspasswort im Arbeitsspeicher des Auth-Servers an.
