#!/usr/bin/env bash
# Frontend-Smoke-Tests (integration_test) der Web-App headless in Chrome.
# Voraussetzung: Chrome und ein passender chromedriver im PATH.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${CHROMEDRIVER_PORT:-4444}"
export PATH="$HOME/.local/bin:$PATH"   # lokaler chromedriver (Chrome for Testing)

chromedriver --port="$PORT" >/dev/null 2>&1 &
DRIVER_PID=$!
trap 'kill "$DRIVER_PID" 2>/dev/null || true' EXIT
sleep 2

cd "$ROOT/packages/app"
status=0
for test in integration_test/*_test.dart; do
  echo "== Smoke-Test: $test"
  flutter drive \
    --driver=test_driver/integration_test.dart \
    --target="$test" \
    -d web-server --browser-name=chrome --headless \
    --driver-port="$PORT" || status=1
done
exit $status
