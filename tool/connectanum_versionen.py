#!/usr/bin/env python3
"""Prüft, ob es neuere connectanum-Versionen (inkl. Beta) auf pub.dev gibt.

Vergleicht die in pubspec.lock aufgelösten Versionen aller connectanum_*-Pakete
mit pub.dev. Gibt die Funde aus; mit --issue wird je neuer Version ein
GitHub-Issue (Label connectanum-update) angelegt, falls noch keines offen ist.
Exit-Code 0 immer, außer bei Netzwerk-/Parserfehlern.
"""
import json
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LABEL = "connectanum-update"


def version_key(version):
    """Sortierschlüssel nach SemVer: 3.0.0-beta.5 < 3.0.0-beta.10 < 3.0.0."""
    main, _, pre = version.partition("-")
    nums = tuple(int(x) for x in main.split("."))
    if not pre:
        return nums + ((1,),)
    parts = tuple((0, int(p), "") if p.isdigit() else (1, 0, p) for p in re.split(r"[.]", pre))
    return nums + ((0,) + parts,)


def locked_versions():
    lock = (ROOT / "pubspec.lock").read_text()
    found = {}
    for m in re.finditer(r'^  (connectanum_[a-z_]+):\n(?:    .*\n)*?    version: "([^"]+)"', lock, re.M):
        found[m.group(1)] = m.group(2)
    return found


def published_versions(package):
    with urllib.request.urlopen(f"https://pub.dev/api/packages/{package}", timeout=30) as r:
        data = json.load(r)
    return [v["version"] for v in data["versions"] if not v.get("retracted")]


def open_issue_titles():
    out = subprocess.run(
        ["gh", "issue", "list", "--label", LABEL, "--state", "open", "--json", "title", "-L", "100"],
        check=True, capture_output=True, text=True, cwd=ROOT,
    ).stdout
    return {i["title"] for i in json.loads(out)}


def main():
    create = "--issue" in sys.argv
    locked = locked_versions()
    if not locked:
        sys.exit("Keine connectanum-Pakete in pubspec.lock gefunden")
    newer = {}
    for package, current in sorted(locked.items()):
        latest = max(published_versions(package), key=version_key)
        state = "NEU" if version_key(latest) > version_key(current) else "aktuell"
        print(f"{state:<8} {package}: {current} → {latest}")
        if state == "NEU":
            newer.setdefault(latest, []).append(f"{package} {current} → {latest}")
    if not newer or not create:
        return
    titles = open_issue_titles()
    for version, lines in sorted(newer.items(), key=lambda kv: version_key(kv[0])):
        title = f"connectanum {version} verfügbar – Upgrade"
        if title in titles:
            print(f"Issue existiert bereits: {title}")
            continue
        body = "\n".join([
            "Neue connectanum-Version auf pub.dev (automatisch erkannt).", "",
            *[f"- {line}" for line in lines], "",
            f"Changelog: https://pub.dev/packages/connectanum_router/versions/{version}/changelog", "",
            "### Vorgehen (CLAUDE.md)",
            f"- [ ] Branch `feature/connectanum-{version}`, alle connectanum-Pakete gemeinsam auf {version}",
            "- [ ] Changelog lesen, Breaking Changes und neue Möglichkeiten (z. B. Serialisierer) bewerten",
            "- [ ] Alle Gates grün: Analyse, 100 % Abdeckung, Mutation ≥ 95 %, Smoke-Tests, Build",
            "- [ ] Benchmarks mit Vorwert vergleichen (`server.Router.rpcRundlauf`), Erkenntnis in docs/erkenntnisse/",
            "- [ ] CLAUDE.md/README Versionsangaben aktualisieren",
        ])
        url = subprocess.run(
            ["gh", "issue", "create", "--title", title, "--body", body, "--label", LABEL],
            check=True, capture_output=True, text=True, cwd=ROOT,
        ).stdout.strip()
        print(f"Issue angelegt: {url}")


if __name__ == "__main__":
    main()
