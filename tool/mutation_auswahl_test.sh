#!/usr/bin/env bash
# Prüft die Dateiauswahl von tool/mutation.sh (MUTATION_BASIS) in einem
# Wegwerf-Repository, ohne Mutationen auszuführen.
# Aufruf: tool/mutation_auswahl_test.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(mktemp -d)"
trap 'rm -rf "$REPO"' EXIT
fehler=0

pruefe() {
  local name="$1"
  shift
  if "$@"; then
    echo "ok   $name"
  else
    echo "FEHL $name"
    fehler=1
  fi
}

lauf() {
  (cd "$REPO" && MUTATION_NUR_KONFIGURATION=1 MUTATION_BASIS="${1:-}" tool/mutation.sh)
}

anlegen() {
  mkdir -p "$(dirname "$REPO/$1")"
  echo "// $1" >"$REPO/$1"
}

git_() { git -C "$REPO" -c user.name=Test -c user.email=test@example.invalid "$@"; }

# Ausgangsstand wie auf main
mkdir -p "$REPO/tool"
cp -r "$ROOT/tool/mutation.sh" "$ROOT/tool/mutation" "$REPO/tool/"
for datei in packages/domain/lib/a.dart packages/domain/lib/b.dart \
  packages/domain/lib/c.dart packages/server/lib/x/y.dart \
  packages/server/test/x/y_test.dart packages/app/lib/main.dart \
  packages/app/lib/seite.dart packages/app/lib/src/modell3d/modell3d_ansicht_web.dart; do
  anlegen "$datei"
done
git_ init -q -b main
git_ add -A && git_ commit -qm start
git_ switch -qc feature/test

# Ohne Basis: alles mit den festen Paketkonfigurationen
ausgabe="$(lauf)"
for pkg in domain server app; do
  pruefe "ohne Basis: $pkg vollständig" grep -qF "Mutation-Tests: $pkg (tool/mutation/$pkg.xml)" <<<"$ausgabe"
done

# Feature-Branch: geänderte, neue (auch nicht committete) und gelöschte Dateien
echo "// geändert" >>"$REPO/packages/domain/lib/a.dart"
anlegen packages/domain/lib/neu.g.dart
git_ rm -q packages/domain/lib/c.dart
echo "// geändert" >>"$REPO/packages/server/test/x/y_test.dart"
echo "// geändert" >>"$REPO/packages/app/lib/main.dart"
echo "// geändert" >>"$REPO/packages/app/lib/src/modell3d/modell3d_ansicht_web.dart"
anlegen packages/app/test/ohne_gegenstueck_test.dart
git_ add -A && git_ commit -qm feature
anlegen packages/domain/lib/unversioniert.dart

ausgabe="$(lauf main)"
domain="$REPO/mutation-test-report/konfiguration/domain.xml"
server="$REPO/mutation-test-report/konfiguration/server.xml"
pruefe "domain: eigene Konfiguration" grep -qF "domain (mutation-test-report/konfiguration/domain.xml)" <<<"$ausgabe"
pruefe "domain: geänderte Datei" grep -qF "<file>packages/domain/lib/a.dart</file>" "$domain"
pruefe "domain: neue, nicht committete Datei" grep -qF "<file>packages/domain/lib/unversioniert.dart</file>" "$domain"
pruefe "domain: unveränderte Datei fehlt" bash -c "! grep -qF 'lib/b.dart' '$domain'"
pruefe "domain: gelöschte Datei fehlt" bash -c "! grep -qF 'lib/c.dart' '$domain'"
pruefe "domain: generierter Code fehlt" bash -c "! grep -qF '.g.dart</file>' <(sed -n '/<files>/,/<\/files>/p' '$domain')"
pruefe "domain: kein <directories>" bash -c "! grep -qF '<directories>' '$domain'"
pruefe "domain: Testbefehl samt Timeout erhalten" grep -qF 'timeout="300">dart test</command>' "$domain"
pruefe "domain: Schwelle erhalten" grep -qF '<threshold failure="95">' "$domain"
pruefe "server: Gegenstück eines geänderten Tests" grep -qF "<file>packages/server/lib/x/y.dart</file>" "$server"
pruefe "server: Timeout erhalten" grep -qF 'timeout="120">dart test --fail-fast</command>' "$server"
pruefe "app: nur ausgeschlossene Dateien → übersprungen" grep -qF "app – keine geänderten Quelldateien" <<<"$ausgabe"

# Geänderte Paketkonfiguration: dieses Paket vollständig
echo "<!-- geändert -->" >>"$REPO/tool/mutation/app.xml"
ausgabe="$(lauf main)"
pruefe "app.xml geändert: app vollständig" grep -qF "app (tool/mutation/app.xml)" <<<"$ausgabe"
pruefe "app.xml geändert: domain weiter eingeschränkt" grep -qF "domain (mutation-test-report/konfiguration/domain.xml)" <<<"$ausgabe"

# Branch ohne Änderungen (z. B. nach dem Merge): nichts zu tun
git_ checkout -q -- tool/mutation/app.xml
rm -rf "$REPO/packages/domain/lib/unversioniert.dart" "$REPO/mutation-test-report"
git_ switch -qc feature/leer main
ausgabe="$(lauf main)"
for pkg in domain server app; do
  pruefe "ohne Änderungen: $pkg übersprungen" grep -qF "$pkg – keine geänderten Quelldateien" <<<"$ausgabe"
done

exit "$fehler"
