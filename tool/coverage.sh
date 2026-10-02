#!/usr/bin/env bash
# Misst die Unit-Test-Abdeckung aller Pakete und bricht unter 100 % ab.
# Ergebnis: coverage/lcov.info (zusammengeführt) und eine Zusammenfassung.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/coverage"
EXCLUDE="$ROOT/tool/coverage_exclude.txt"
rm -rf "$OUT" && mkdir -p "$OUT"

(cd "$ROOT/packages/domain" && dart test --coverage-package="^terrassenplaner_domain$" --coverage-path="$OUT/domain.info")
(cd "$ROOT/packages/server" && dart test --coverage-package="^terrassenplaner_server$" --coverage-path="$OUT/server.info")
(cd "$ROOT/packages/app" && flutter test --coverage --coverage-package="^terrassenplaner_app$" --coverage-path="$OUT/app.info")

# Pfade relativ zur Workspace-Wurzel vereinheitlichen und zusammenführen.
for pkg in domain server app; do
  sed -e "s#^SF:$ROOT/#SF:#" -e "s#^SF:lib/#SF:packages/$pkg/lib/#" "$OUT/$pkg.info"
done > "$OUT/lcov.info"

# Quelldateien mit ausführbarem Code, die in keinem Bericht auftauchen, zählen als ungetestet.
missing=0
while IFS= read -r file; do
  rel="${file#"$ROOT"/}"
  grep -qxF "$rel" <(grep -v '^#' "$EXCLUDE") && continue
  grep -qxF "SF:$rel" "$OUT/lcov.info" && continue
  if grep -vqE '^[[:space:]]*$|^[[:space:]]*//|^(library|export|import|part)([[:space:];]|$)' "$file"; then
    echo "NICHT GETESTET (fehlt im Bericht): $rel"
    missing=$((missing + 1))
  fi
done < <(find "$ROOT/packages"/*/lib "$ROOT/packages"/*/bin -name '*.dart' ! -name '*.g.dart' 2>/dev/null | sort)

awk -v missing="$missing" '
  /^SF:/ { file = substr($0, 4) }
  /^LF:/ { lf[file] += substr($0, 4); total += substr($0, 4) }
  /^LH:/ { lh[file] += substr($0, 4); hit += substr($0, 4) }
  END {
    for (f in lf) if (lh[f] < lf[f]) printf "UNVOLLSTÄNDIG: %s (%d/%d Zeilen)\n", f, lh[f], lf[f]
    pct = total ? 100 * hit / total : 100
    printf "Abdeckung: %d/%d Zeilen = %.2f %%\n", hit, total, pct
    if (hit < total || missing > 0) { print "FEHLER: Abdeckung unter 100 %"; exit 1 }
    print "OK: 100 % Abdeckung"
  }' "$OUT/lcov.info"
