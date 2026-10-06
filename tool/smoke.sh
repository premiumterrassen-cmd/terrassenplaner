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

# Router mit Hallo-Dienst für den Ende-zu-Ende-Test (M0-12); Geheimnisse nur für den Test.
(cd "$ROOT/packages/server" && PLANER_AUTH_TOKEN=smoke PLANER_AUTH_DIENST_TICKET=smoke \
  PLANER_PORT="$WAMP_PORT" PLANER_HEALTH_LISTEN="127.0.0.1:$((WAMP_PORT + 1))" \
  dart run bin/server.dart >/tmp/planer-smoke-router.log 2>&1) &
ROUTER_PID=$!
trap 'kill "$DRIVER_PID" 2>/dev/null || true; pkill -f "bin/server.dart" 2>/dev/null || true; kill "$ROUTER_PID" 2>/dev/null || true' EXIT
for _ in $(seq 1 120); do
  curl -sf "http://127.0.0.1:$((WAMP_PORT + 1))/healthz" >/dev/null && break
  sleep 1
done

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
    ${CHROME_EXECUTABLE:+--chrome-binary="$CHROME_EXECUTABLE"} || status=1
done
exit $status
