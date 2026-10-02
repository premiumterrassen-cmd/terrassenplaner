#!/usr/bin/env bash
# Führt alle Feature-Benchmarks (packages/*/benchmark/*_benchmark.dart) aus,
# schreibt benchmark-results/<umgebung>.json und vergleicht mit dem Vorwert
# benchmarks/baseline-<umgebung>.json.
#
#   tool/benchmark.sh                    Vergleich, Verschlechterung wird gemeldet
#   tool/benchmark.sh --strict           Verschlechterung über der Schwelle = Exit 1
#   tool/benchmark.sh --update-baseline  aktuelle Werte als neuen Vorwert speichern
#
# Umgebung: BENCH_ENV (Standard "lokal", in der Build-Chain "ci"),
# Schwelle: BENCH_THRESHOLD in Prozent (Standard 20).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENVIRONMENT="${BENCH_ENV:-lokal}"
THRESHOLD="${BENCH_THRESHOLD:-20}"
MODE="${1:-compare}"
OUT="$ROOT/benchmark-results/$ENVIRONMENT.json"
BASELINE="$ROOT/benchmarks/baseline-$ENVIRONMENT.json"
mkdir -p "$ROOT/benchmark-results"

raw="$(mktemp)"
trap 'rm -f "$raw"' EXIT
for file in "$ROOT"/packages/*/benchmark/*_benchmark.dart; do
  [ -e "$file" ] || continue
  pkg_dir="$(dirname "$(dirname "$file")")"
  echo "== Benchmark: ${file#"$ROOT"/}"
  (cd "$pkg_dir" && dart run "benchmark/$(basename "$file")") | tee -a "$raw"
done

python3 - "$raw" "$OUT" "$BASELINE" "$MODE" "$THRESHOLD" <<'PY'
import json, re, sys, os, datetime
raw, out, baseline, mode, threshold = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], float(sys.argv[5])
results = {}
for line in open(raw):
    m = re.match(r'^(\S+)\(RunTime\): ([0-9.eE+-]+) us\.$', line.strip())
    if m:
        results[m.group(1)] = float(m.group(2))
doc = {"erstellt": datetime.datetime.now().isoformat(timespec="seconds"), "einheit": "µs je Durchlauf", "werte": results}
json.dump(doc, open(out, "w"), indent=2, ensure_ascii=False)
print(f"{len(results)} Benchmark(s) → {os.path.relpath(out)}")
if mode == "--update-baseline":
    json.dump(doc, open(baseline, "w"), indent=2, ensure_ascii=False)
    print(f"Vorwert gespeichert: {os.path.relpath(baseline)}")
    sys.exit(0)
if not os.path.exists(baseline):
    print(f"Kein Vorwert ({os.path.relpath(baseline)}) – mit --update-baseline anlegen.")
    sys.exit(0)
base = json.load(open(baseline))["werte"]
worse = []
for name, value in sorted(results.items()):
    if name not in base:
        print(f"NEU         {name}: {value:.2f} µs")
        continue
    delta = (value - base[name]) / base[name] * 100
    tag = "SCHLECHTER" if delta > threshold else "ok"
    print(f"{tag:<11} {name}: {value:.2f} µs (Vorwert {base[name]:.2f}, {delta:+.1f} %)")
    if delta > threshold:
        worse.append(name)
if worse:
    print(f"WARNUNG: {len(worse)} Benchmark(s) mehr als {threshold:.0f} % langsamer als der Vorwert")
    sys.exit(1 if mode == "--strict" else 0)
PY
