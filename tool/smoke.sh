#!/usr/bin/env bash
# Frontend-Smoke-Tests (integration_test) der Web-App headless in Chrome,
# gebaut als WebAssembly wie im Deployment (M0-16).
# Voraussetzung: Chrome und ein passender chromedriver im PATH; CHROME_EXECUTABLE
# legt fest, welches Chrome gestartet wird (Build-Chain: zum chromedriver passend).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${CHROMEDRIVER_PORT:-4444}"
export PATH="$HOME/.local/bin:$PATH"   # lokaler chromedriver (Chrome for Testing)

WAMP_PORT="${SMOKE_WAMP_PORT:-8099}"

chromedriver --port="$PORT" >/dev/null 2>&1 &
DRIVER_PID=$!

# Auth-Server (Mitarbeiter-Anmeldung, M9-10) und Router mit Hallo-Dienst für
# die Ende-zu-Ende-Tests (M0-12); Geheimnisse nur für den Test. Ports:
# Router WAMP_PORT (+1 Health), Auth-Server WAMP_PORT+2 (+3 Health).
# Eigene Logs und nur die eigenen Prozesse beenden: Mehrere Läufe mit eigenen
# Ports (SMOKE_WAMP_PORT, CHROMEDRIVER_PORT) dürfen parallel laufen.
AUTH_ADRESSE="127.0.0.1:$((WAMP_PORT + 2))"
AUTH_LOG="$(mktemp "${TMPDIR:-/tmp}/planer-smoke-auth.XXXXXX")"
ROUTER_LOG="$(mktemp "${TMPDIR:-/tmp}/planer-smoke-router.XXXXXX")"
echo "Auth-Log: $AUTH_LOG, Router-Log: $ROUTER_LOG"
(cd "$ROOT/packages/server" && PLANER_AUTH_TOKEN=smoke PLANER_AUTH_DIENST_TICKET=smoke \
  PLANER_AUTH_LISTEN="$AUTH_ADRESSE" PLANER_AUTH_HEALTH_LISTEN="127.0.0.1:$((WAMP_PORT + 3))" \
  exec dart run bin/auth_server.dart >"$AUTH_LOG" 2>&1) &
AUTH_PID=$!
# Prozess samt Kindern (dart run startet den Server ggf. als eigenen Prozess).
beende() {
  pkill -P "$1" 2>/dev/null || true
  kill "$1" 2>/dev/null || true
}
ROUTER_PID=""
trap 'beende "$DRIVER_PID"; beende "$AUTH_PID"; [ -n "$ROUTER_PID" ] && beende "$ROUTER_PID"' EXIT
warte_auf_health() {
  for _ in $(seq 1 120); do
    curl -sf "http://127.0.0.1:$1/healthz" >/dev/null && return
    sleep 1
  done
}
# Erst der Auth-Server, dann der Router: zwei gleichzeitige `dart run` stören
# sich beim Bündeln der nativen Bibliotheken in .dart_tool/lib.
warte_auf_health $((WAMP_PORT + 3))
(cd "$ROOT/packages/server" && PLANER_AUTH_TOKEN=smoke PLANER_AUTH_DIENST_TICKET=smoke \
  PLANER_PORT="$WAMP_PORT" PLANER_HEALTH_LISTEN="127.0.0.1:$((WAMP_PORT + 1))" \
  PLANER_AUTH_ADRESSE="$AUTH_ADRESSE" \
  exec dart run bin/server.dart >"$ROUTER_LOG" 2>&1) &
ROUTER_PID=$!
warte_auf_health $((WAMP_PORT + 1))

# Testkonto nur für diesen Lauf (Konten liegen nur im Arbeitsspeicher des
# Auth-Servers); das Passwort geht über stdin an das Werkzeug.
SMOKE_EMAIL="smoke@example.test"
SMOKE_PASSWORT="$(openssl rand -hex 16)"
printf '%s\n' "$SMOKE_PASSWORT" | (cd "$ROOT/packages/server" && \
  PLANER_AUTH_ADRESSE="$AUTH_ADRESSE" PLANER_AUTH_DIENST_TICKET=smoke \
  dart run bin/mitarbeiter.dart anlegen "$SMOKE_EMAIL")

cd "$ROOT/packages/app"
status=0
for test in integration_test/*_test.dart; do
  echo "== Smoke-Test: $test"
  flutter drive \
    --driver=test_driver/integration_test.dart \
    --target="$test" \
    -d web-server --browser-name=chrome --headless --wasm \
    --driver-port="$PORT" \
    --dart-define=PLANER_WAMP_URL="ws://127.0.0.1:$WAMP_PORT/ws" \
    --dart-define=SMOKE_MITARBEITER_EMAIL="$SMOKE_EMAIL" \
    --dart-define=SMOKE_MITARBEITER_PASSWORT="$SMOKE_PASSWORT" \
    ${CHROME_EXECUTABLE:+--chrome-binary="$CHROME_EXECUTABLE"} || status=1
done

# Ladebildschirm (M3-08) im Release-Build mit Größenliste: kalter Start, Cache,
# Barrierefreiheit, langsam, offline, Fehler – WebAssembly- und JS-Weg.
echo "== Ladebildschirm: tool/ladebild/pruefung.mjs"
flutter build web --release --wasm
python3 "$ROOT/tool/startgroessen.py" build/web
LADEBILD_WAMP_PORT="$WAMP_PORT" node "$ROOT/tool/ladebild/pruefung.mjs" build/web || status=1
exit $status
