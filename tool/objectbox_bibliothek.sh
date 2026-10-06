#!/usr/bin/env bash
# Stellt die native ObjectBox-Bibliothek (objectbox-c, feste Version, geprüfte
# Prüfsumme) unter packages/server/lib/ bereit – dort sucht das Dart-Paket
# objectbox zuerst. Die Datei ist nicht im Repository (.gitignore).
# Aufruf: tool/objectbox_bibliothek.sh [zielordner]
set -euo pipefail

VERSION="v5.3.2"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZIEL="${1:-$ROOT/packages/server/lib}"
URL="https://github.com/objectbox/objectbox-c/releases/download/$VERSION"

case "$(uname -s)" in
  Darwin) ARCHIV="objectbox-macos-universal.zip"; SHA="680c598573ede04b9762565d48d4e161ad286f786f159abb8da89353bfa1d0bc"; DATEI="libobjectbox.dylib" ;;
  Linux)  ARCHIV="objectbox-linux-x64.tar.gz";   SHA="6dbb5450c36dd11ee9074f16ecc61e79b45ff43c2082934601f3166b39c8a613"; DATEI="libobjectbox.so" ;;
  *) echo "Betriebssystem nicht unterstützt"; exit 1 ;;
esac

if [ -f "$ZIEL/$DATEI" ]; then
  echo "ObjectBox-Bibliothek vorhanden: $ZIEL/$DATEI"
  exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -sSfL -o "$TMP/$ARCHIV" "$URL/$ARCHIV"
echo "$SHA  $TMP/$ARCHIV" | shasum -a 256 -c - >/dev/null
case "$ARCHIV" in
  *.zip) unzip -q "$TMP/$ARCHIV" -d "$TMP/x" ;;
  *)     mkdir -p "$TMP/x" && tar xzf "$TMP/$ARCHIV" -C "$TMP/x" ;;
esac
mkdir -p "$ZIEL"
cp "$TMP/x/lib/$DATEI" "$ZIEL/$DATEI"
echo "ObjectBox $VERSION bereitgestellt: $ZIEL/$DATEI"
