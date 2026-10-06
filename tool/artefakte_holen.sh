#!/usr/bin/env bash
# Lädt die Linux-Artefakte (Router, Auth-Server, Web-App) des letzten
# erfolgreichen Build-Chain-Laufs auf main nach artefakte/ – Grundlage für
# das Ansible-Deployment (deploy/).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="premiumterrassen-cmd/terrassenplaner"
ZWEIG="${1:-main}"
LAUF="$(gh run list -R "$REPO" -w build-chain.yml -b "$ZWEIG" -s success -L 1 --json databaseId -q '.[0].databaseId')"
[ -n "$LAUF" ] || { echo "Kein erfolgreicher Lauf auf $ZWEIG gefunden"; exit 1; }
rm -rf "$ROOT/artefakte"
gh run download "$LAUF" -R "$REPO" -n planer-artefakte -D "$ROOT/artefakte"
chmod +x "$ROOT"/artefakte/*/bin/* 2>/dev/null || true
echo "Artefakte von Lauf $LAUF in artefakte/: $(ls "$ROOT/artefakte" | tr '\n' ' ')"
