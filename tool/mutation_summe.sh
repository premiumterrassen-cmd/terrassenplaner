#!/usr/bin/env bash
# Summiert die Berichte der Teilläufe je Paket und prüft die Schwelle aus
# tool/mutation/<paket>.xml – sie gilt je Paket, nicht je Teil. Ein fehlender
# Teil (Absturz, Zeitlimit) zählt als Fehler.
# Aufruf: tool/mutation_summe.sh <berichte> [paket ...]   (ohne Angabe: domain server app)
# <berichte> enthält je Teil einen Ordner mutation-teil-<paket>-<nummer>-von-<anzahl>.
# Begründung: docs/erkenntnisse/mutation-tests.md
set -euo pipefail

BERICHTE="$1"
shift
packages=("$@")
[ ${#packages[@]} -eq 0 ] && packages=(domain server app)

# Summe eines xunit-Attributs über alle Regeln eines Berichts-Satzes.
summe() {
  local attribut="$1"
  shift
  cat "$@" | grep -o "<testsuite [^>]*>" | sed "s/.* $attribut=\"\([0-9]*\)\".*/\1/" |
    awk '{ s += $1 } END { print s + 0 }'
}

fehlgeschlagen=()
for pkg in "${packages[@]}"; do
  ordner=("$BERICHTE/mutation-teil-$pkg"-*-von-*)
  if [ ! -d "${ordner[0]}" ]; then
    echo "== $pkg: keine Berichte gefunden"
    fehlgeschlagen+=("$pkg")
    continue
  fi
  anzahl="${ordner[0]##*-von-}"
  berichte=()
  for teil in "${ordner[@]}"; do
    [ -f "$teil/$pkg/mutation-test.xunit.xml" ] && berichte+=("$teil/$pkg/mutation-test.xunit.xml")
  done
  if [ ${#berichte[@]} -ne "$anzahl" ]; then
    echo "== $pkg: nur ${#berichte[@]} von $anzahl Teilen vorhanden"
    fehlgeschlagen+=("$pkg")
    continue
  fi
  mutanten="$(summe tests "${berichte[@]}")"
  unerkannt="$(($(summe failures "${berichte[@]}") + $(summe errors "${berichte[@]}")))"
  schwelle="$(sed -n 's/.*<threshold failure="\([0-9.]*\)".*/\1/p' "$(dirname "$0")/mutation/$pkg.xml")"
  # Wie mutation_test: Timeouts und nicht abgedeckte Zeilen zählen als unerkannt.
  if awk -v m="$mutanten" -v u="$unerkannt" -v s="$schwelle" \
    'BEGIN { score = m > 0 ? 100 - 100 * u / m : 100
             printf "%.2f %%", score
             exit !(score >= s) }'; then
    echo " == $pkg: $unerkannt von $mutanten Mutanten unerkannt (Schwelle $schwelle %)"
  else
    echo " == $pkg: $unerkannt von $mutanten Mutanten unerkannt, UNTER der Schwelle $schwelle %"
    fehlgeschlagen+=("$pkg")
  fi
done

if [ ${#fehlgeschlagen[@]} -gt 0 ]; then
  echo "FEHLER: Mutation-Vollauf nicht bestanden in: ${fehlgeschlagen[*]}"
  exit 1
fi
echo "OK: alle Pakete erreichen die Mutations-Schwelle"
