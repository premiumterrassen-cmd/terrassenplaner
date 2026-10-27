#!/usr/bin/env bash
# Mutation-Tests aller Pakete (mutation_test). Bricht ab, wenn ein Paket unter
# der Schwelle aus tool/mutation/<paket>.xml liegt (Ziel 95 %).
# Aufruf: tool/mutation.sh [paket ...]   (ohne Angabe: domain server app)
#
# MUTATION_BASIS=<ref> (z. B. origin/main): nur die seit dem gemeinsamen Vorfahren
#   mit <ref> geänderten Dateien mutieren (Feature-Branches). Leer: alles (main).
# MUTATION_NUR_KONFIGURATION=1: nur die Konfigurationen erzeugen, nichts ausführen.
# Begründung: docs/erkenntnisse/mutation-tests.md
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
packages=("$@")
[ ${#packages[@]} -eq 0 ] && packages=(domain server app)
BASIS="${MUTATION_BASIS:-}"
AUSGABE="mutation-test-report/konfiguration"

# Geänderte Dateien seit dem gemeinsamen Vorfahren mit $BASIS – committet,
# im Arbeitsbaum oder neu (lokale Läufe), gelöschte nicht.
geaenderte_dateien() {
  local vorfahr
  vorfahr="$(git merge-base "$BASIS" HEAD)"
  { git diff --name-only --diff-filter=d "$vorfahr"
    git ls-files --others --exclude-standard; } | sort -u
}

# Zu mutierende Quelldateien eines Pakets: geänderte lib-Dateien und die
# lib-Gegenstücke geänderter Tests (test/x/y_test.dart → lib/x/y.dart), ohne
# generierten Code und ohne die in der Paketkonfiguration ausgeschlossenen Dateien.
quelldateien() {
  local pkg="$1" vorlage="tool/mutation/$1.xml" datei kandidat
  local ausgeschlossen
  ausgeschlossen="$(sed -n 's#^ *<file>\(packages/[^<]*\)</file>#\1#p' "$vorlage")"
  while IFS= read -r datei; do
    case "$datei" in
      "packages/$pkg/lib/"*.dart) kandidat="$datei" ;;
      "packages/$pkg/test/"*_test.dart)
        kandidat="packages/$pkg/lib/${datei#"packages/$pkg/test/"}"
        kandidat="${kandidat%_test.dart}.dart" ;;
      *) continue ;;
    esac
    [[ "$kandidat" == *.g.dart ]] && continue
    [ -f "$kandidat" ] || continue
    grep -qxF "$kandidat" <<<"$ausgeschlossen" && continue
    echo "$kandidat"
  done <<<"$GEAENDERT" | sort -u
}

# Paketkonfiguration mit <files> statt <directories>; Testbefehl, Timeouts,
# Ausschlüsse und Schwelle bleiben unverändert.
konfiguration_fuer_dateien() {
  local vorlage="$1"
  shift
  awk -v dateien="$*" '
    /<directories>/ {
      print "  <files>"
      n = split(dateien, liste, " ")
      for (i = 1; i <= n; i++) print "    <file>" liste[i] "</file>"
      print "  </files>"
      ueberspringen = 1
    }
    !ueberspringen { print }
    /<\/directories>/ { ueberspringen = 0 }
  ' "$vorlage"
}

# Gibt den Pfad der zu verwendenden Konfiguration aus, leer = nichts zu tun.
konfiguration() {
  local pkg="$1" vorlage="tool/mutation/$1.xml"
  # Geänderte Paketkonfiguration (Regeln, Ausschlüsse, Timeouts) betrifft alle Dateien.
  if [ -z "$BASIS" ] || grep -qxF "$vorlage" <<<"$GEAENDERT"; then
    echo "$vorlage"
    return
  fi
  local dateien
  dateien="$(quelldateien "$pkg")"
  [ -z "$dateien" ] && return
  mkdir -p "$AUSGABE"
  # shellcheck disable=SC2086 # Pfade enthalten keine Leerzeichen
  konfiguration_fuer_dateien "$vorlage" $dateien >"$AUSGABE/$pkg.xml"
  echo "$AUSGABE/$pkg.xml"
}

GEAENDERT=""
if [ -n "$BASIS" ]; then
  GEAENDERT="$(geaenderte_dateien)"
  echo "== Nur geänderte Dateien seit $(git merge-base "$BASIS" HEAD | cut -c1-8) ($BASIS)"
fi

failed=()
for pkg in "${packages[@]}"; do
  config="$(konfiguration "$pkg")"
  if [ -z "$config" ]; then
    echo "== Mutation-Tests: $pkg – keine geänderten Quelldateien, übersprungen"
    continue
  fi
  echo "== Mutation-Tests: $pkg ($config)"
  [ -n "${MUTATION_NUR_KONFIGURATION:-}" ] && continue
  if ! dart run mutation_test --output="mutation-test-report/$pkg" "$config"; then
    failed+=("$pkg")
  fi
done

if [ ${#failed[@]} -gt 0 ]; then
  echo "FEHLER: Mutation-Score unter der Schwelle in: ${failed[*]}"
  exit 1
fi
echo "OK: alle Pakete erreichen die Mutations-Schwelle"
