#!/usr/bin/env bash
# Testbefehl eines Mutanten mit harter Frist: frist.sh <sekunden> <befehl ...>
#
# mutation_test beendet einen Testlauf nach seinem Timeout nur mit SIGTERM;
# `dart test` wartet darauf erst die laufenden Tests ab. Rechnet ein Mutant
# (fast) endlos, läuft der alte Prozess neben den folgenden Mutanten weiter,
# bis der Runner keinen Speicher mehr hat (Exit 143, M6-01). Hier wird der
# Befehl nach <sekunden> mit SIGKILL beendet – das zählt als erkannt.
# Begründung: docs/erkenntnisse/mutation-tests.md
set -u
frist="$1"
shift
"$@" &
pid=$!
(
  sleep "$frist"
  kill -KILL "$pid" 2>/dev/null
) &
waechter=$!
# auch das SIGTERM von mutation_test beendet den Befehl sofort
trap 'kill -KILL "$pid" "$waechter" 2>/dev/null; exit 143' TERM INT
wait "$pid"
status=$?
kill "$waechter" 2>/dev/null
exit "$status"
