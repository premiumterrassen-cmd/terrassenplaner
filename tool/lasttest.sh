#!/usr/bin/env bash
# Last- und Leistungstest (M10-02), langer Lauf – manuell, nicht in der
# Build-Chain (Laufzeit rund 5 Minuten). Den kurzen Lauf für die Build-Chain
# misst packages/server/benchmark/lasttest_benchmark.dart.
#
# Baut Router und Lastwerkzeug wie in der Build-Chain (dart build cli, AOT),
# startet den echten Router (bin/server.dart) nur lokal auf freien Ports mit
# eigener ObjectBox-Datenbank und erfundener Artikeldatei, fährt die
# Szenarien (gleichzeitige Nutzer, viele Sitzungen, große Projekte,
# Router-Durchsatz), misst Speicher und CPU des Router-Prozesses und prüft
# die Zielwerte. Nie gegen den Produktivserver richten.
#
#   tool/lasttest.sh                         alle Szenarien, je 60 s
#   tool/lasttest.sh --dauer 10              kürzer
#   tool/lasttest.sh --szenario nutzer       nur ein Szenario (mehrfach möglich)
#
# Ergebnis: benchmark-results/lasttest-<LASTTEST_ENV:-lokal>.json,
# Exit 1, wenn ein Zielwert verfehlt ist. Bericht: docs/abnahme/lasttest.md.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SERVER="$ROOT/packages/server"
UMGEBUNG="${LASTTEST_ENV:-lokal}"
AUSGABE="$ROOT/benchmark-results/lasttest-$UMGEBUNG.json"
TMP="$(mktemp -d)"
mkdir -p "$ROOT/benchmark-results"
"$ROOT/tool/objectbox_bibliothek.sh" >/dev/null

frei() { python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()'; }

server_pid=""
aufraeumen() {
  if [ -n "$server_pid" ]; then kill "$server_pid" 2>/dev/null || true; wait "$server_pid" 2>/dev/null || true; fi
  cp "$TMP/server.log" "$ROOT/benchmark-results/lasttest-$UMGEBUNG-router.log" 2>/dev/null || true
  rm -rf "$TMP"
}
trap aufraeumen EXIT

echo "== Bauen (dart build cli)"
(cd "$SERVER" && dart build cli --target=bin/server.dart --output="$TMP/server" >/dev/null)
(cd "$SERVER" && dart build cli --target=bin/lasttest.dart --output="$TMP/lasttest" >/dev/null)
"$TMP/lasttest/bundle/bin/lasttest" artikeldatei "$TMP/artikel.json"

PORT="$(frei)"
echo "== Router starten (Port $PORT)"
# Arbeitsverzeichnis packages/server: dort liegt lib/libobjectbox.*.
(cd "$SERVER" && exec env \
  PLANER_AUTH_TOKEN=lasttest \
  PLANER_AUTH_DIENST_TICKET=lasttest \
  PLANER_PORT="$PORT" \
  PLANER_HEALTH_LISTEN="127.0.0.1:$(frei)" \
  PLANER_AUTH_ADRESSE="127.0.0.1:$(frei)" \
  PLANER_DATENVERZEICHNIS="$TMP/daten" \
  PLANER_KNOTEN=lasttest \
  PLANER_ARTIKELDATEI="$TMP/artikel.json" \
  "$TMP/server/bundle/bin/server" >"$TMP/server.log" 2>&1) &
server_pid=$!
for _ in $(seq 1 100); do
  grep -q "Artikeldaten lasttest-1" "$TMP/server.log" 2>/dev/null && grep -q "WAMP ws://" "$TMP/server.log" && break
  sleep 0.2
done
if ! grep -q "WAMP ws://" "$TMP/server.log"; then
  cat "$TMP/server.log"
  echo "FEHLER: Router nicht gestartet"
  exit 1
fi

echo "== Lasttest"
"$TMP/lasttest/bundle/bin/lasttest" lauf \
  --url "ws://127.0.0.1:$PORT/ws" \
  --pid "$server_pid" \
  --ausgabe "$AUSGABE" \
  "$@"
echo "Bericht: ${AUSGABE#"$ROOT"/}"
