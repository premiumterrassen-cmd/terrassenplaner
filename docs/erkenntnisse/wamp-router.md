# WAMP-Router (M0-07, 02.10.2026)

## Aufbau

- `packages/server/lib/src/router/router_einstellungen.dart` – Betriebsparameter (Host, Port, WebSocket-Pfad, Realm, Health-Adresse) aus Umgebungsvariablen `PLANER_*`; erzeugt die `RouterSettings` von `connectanum_router` 3.0.0-beta.5 per Builder-API (typisiert und testbar statt YAML).
- `packages/server/lib/src/router/planer_router.dart` – startet `NativeTransportRuntime` + `Router`, liefert die gebundenen Ports, beendet geordnet (`RouterBinding.dispose()` = Drain).
- Realm `de.robinienwelt.terrassenplaner`, WebSocket unter `/ws`, Health unter `http://<PLANER_HEALTH_LISTEN>/healthz` (200 bereit, 503 beim Start/Drain).
- **Vorläufig** anonyme Anmeldung mit vollen Rechten im Planer-Realm – Rollen und Rechte folgen in M0-08 (#8).

## Erkenntnisse

- Die native Transportschicht (`ct_ffi`, Rust) holt sich der Build-Hook von `connectanum_router`/`connectanum_client` automatisch als vorgebautes Release `v3.0.0-beta.5` von GitHub (konsultaner/connectanum-dart), wenn kein Rust installiert ist. Für reproduzierbare Builds kann der Release-Tag in der Wurzel-`pubspec.yaml` unter `hooks.user_defines` fest gesetzt werden.
- `dart build cli` erzeugt ein Bündel `build/server/bundle/{bin,lib}` mit der nativen Bibliothek – das ist das Deploy-Artefakt.
- Der Health-Endpunkt entsteht über `withOpenMetricsHttpRoutes()` als zusätzlicher HTTP-Listener; er wird im Deployment nicht nach außen freigegeben (nur Traefik-intern bzw. für Überwachung).
- **connectanum_bench** ist laut eigener Beschreibung ein internes Werkzeug des connectanum-Projekts und braucht einen Rust-Orchestrator; für uns ungeeignet. Stattdessen eigener Benchmark `server.Router.rpcRundlauf` (benchmark_harness) über die echte Router-Konfiguration.
- Erster Messwert (MacBook, lokal): ≈ 5,1 ms je RPC-Rundlauf (JSON über den Dart-WebSocket-Client). Für Bedienung ausreichend; in M10-02 (Lasttest) prüfen, ob MessagePack oder der native WebSocket-Client des connectanum-Pakets nennenswert schneller ist.

## Upgrade auf 3.0.0-beta.6 (03.10.2026, #103)

- Alle connectanum-Pakete gemeinsam auf beta.6; native Transportschicht als Release `v3.0.0-beta.6`.
- Neu: Sperrdatei `connectanum_native_runtime.lock` im temporären Verzeichnis – eine Transportschicht je `TMPDIR` (betrifft Diensttrennung Router/Auth-Server, siehe authentifizierung.md).
- `connectanum_auth_server` prüft Dienst-Zugangsdaten (Auth-Token) jetzt vor allem anderen; `authenticate.hello` ohne Token antwortet mit `status: failure` statt Schemafehler.
- Remote-Auth-Delegation an einen Auth-Server in einem eigenen Prozess funktioniert (Mitarbeiter-Anmeldung per `wamp-scram`).

## Upgrade auf 3.0.0-beta.7 (06.10.2026, #104)

- Sperre der Transportschicht je Prozess statt je `TMPDIR` → Test-Hilfe ohne eigenes `TMPDIR`.
- Saubereres Herunterfahren (Dispose, interne Sitzungen); unsere Programme beenden sich nach SIGINT/SIGTERM von selbst, nachdem beide Signal-Abos abgemeldet werden.
- **Benchmark:** `server.Router.rpcRundlauf` mit beta.7 in drei Läufen 3,02–3,14 ms gegenüber Vorwert 2,62 ms (beta.6) → **+15 bis +20 %** (lokal, MacBook). Unter der Alarmschwelle von 20 %, aber reproduzierbar – an Alexander gemeldet; Vorwert bleibt bis zur Klärung bei beta.6.

## Upgrade auf 3.0.0-beta.8 (10.10.2026, #109)

- Alle connectanum-Pakete gemeinsam auf beta.8 (client, router, auth_server, core); ohne Codeänderung lauffähig, Abdeckung 100 %.
- Neu: FlatBuffers-WAMP-Serialisierer (`wamp.2.flatbuffers`, RawSocket-ID 5), natives FlatBuffers-Routing mit beibehaltenen, segmentierten Payloads (Router reicht Nutzdaten ohne Umkodieren weiter), native Builder/eingefrorene Puffer/External-Producer-Leases (Zero-Copy auf nativen Transporten), typisierte FlatBuffers-E2EE. Im Browser gibt es den Serialisierer über WebSocket, aber keine nativ verwalteten Puffer.
- ObjectBox-Anbindung ist laut connectanum-Doku **nicht** Teil von core, sondern eines eigenen Pakets `connectanum_objectbox_adapter` (Stand 10.10.2026 nicht auf pub.dev).
- **Benchmark (A/B auf derselben Maschine, je 3 Läufe):** `server.Router.rpcRundlauf` beta.7 2,94–3,02 ms, beta.8 2,98–3,01 ms → **kein Unterschied**. Der gespeicherte Vorwert 2,62 ms (beta.6) stammt aus einem anderen Maschinenzustand; die gemeldete beta.7-Verschlechterung ist damit nicht belastbar. Der Benchmark nutzt weiter JSON – FlatBuffers wird erst mit dem eigenen Issue gemessen.

## Leerlauf-CPU auf dem Server (06.10.2026, beta.7)

Ohne Last gemessen (30 s, Debian 13, 2 Kerne): `planer-router` ≈ 6,3 % und `planer-auth` ≈ 6,8 % eines Kerns, Traefik 0 %. Zusammen rund 13 % eines Kerns ohne einzige Verbindung – deutet auf aktives Abfragen (Polling) in der Transportschicht/den Worker-Isolates. An Alexander (Maintainer) gemeldet; für M10-02 (Last- und Leistungstest) und das Monitoring (M0-14) beobachten.
