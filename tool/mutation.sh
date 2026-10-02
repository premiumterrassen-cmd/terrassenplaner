#!/usr/bin/env bash
# Mutation-Tests aller Pakete (mutation_test). Bricht ab, wenn ein Paket unter
# der Schwelle aus tool/mutation/<paket>.xml liegt (Ziel 95 %).
# Aufruf: tool/mutation.sh [paket ...]   (ohne Angabe: domain server app)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
packages=("$@")
[ ${#packages[@]} -eq 0 ] && packages=(domain server app)

failed=()
for pkg in "${packages[@]}"; do
  echo "== Mutation-Tests: $pkg"
  if ! dart run mutation_test --output="mutation-test-report/$pkg" "tool/mutation/$pkg.xml"; then
    failed+=("$pkg")
  fi
done

if [ ${#failed[@]} -gt 0 ]; then
  echo "FEHLER: Mutation-Score unter der Schwelle in: ${failed[*]}"
  exit 1
fi
echo "OK: alle Pakete erreichen die Mutations-Schwelle"
