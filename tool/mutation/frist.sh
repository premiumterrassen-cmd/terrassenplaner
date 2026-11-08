#!/usr/bin/env bash
# Testbefehl eines Mutanten mit harter Frist: frist.sh <sekunden> <befehl ...>
#
# mutation_test beendet einen Testlauf nach seinem Timeout nur mit SIGTERM;
# `dart test` wartet darauf erst die laufenden Tests ab. Rechnet ein Mutant
# (fast) endlos, läuft der alte Prozess neben den folgenden Mutanten weiter,
# bis der Runner keinen Speicher mehr hat (Exit 143, M6-01). Hier wird der
# Befehl nach <sekunden> mit SIGKILL beendet – das zählt als erkannt.
# Begründung: docs/erkenntnisse/mutation-tests.md
#
# Der Befehl läuft in einer eigenen Prozessgruppe (set -m), und beendet wird
# die ganze Gruppe: `dart test` startet Test-Runner, die wiederum Server
# starten (z. B. bin/auth_server.dart). Mit SIGKILL nur auf `dart test`
# blieben sie als Waisen liegen (108 Prozesse, Last ~16, 08.11.2026).
set -u
frist="$1"
shift
set -m
"$@" &
pid=$!
set +m
beende() { kill -KILL -- "-$pid" 2>/dev/null; }
(
  sleep "$frist"
  beende
) &
waechter=$!
# auch das SIGTERM von mutation_test beendet den Befehl sofort
trap 'beende; kill -KILL "$waechter" 2>/dev/null; exit 143' TERM INT
wait "$pid" 2>/dev/null
status=$?
kill "$waechter" 2>/dev/null
# Reste der Gruppe (vom Befehl gestartete, nicht beendete Prozesse)
beende
exit "$status"
