#!/usr/bin/env python3
"""Schreibt die Größen der Startdateien in build/web/index.html (#startgroessen).

Grundlage der echten Prozentanzeige des Ladebildschirms (M3-08).
Aufruf nach `flutter build web`: tool/startgroessen.py packages/app/build/web
"""
import json
import re
import sys
from pathlib import Path

PLATZHALTER = re.compile(r'(<script id="startgroessen" type="application/json">)\{\}(</script>)')
RELEVANT = re.compile(r'^(main\.dart\.(js|mjs|wasm)|canvaskit/[^/]+\.(js|wasm)|assets/.*)$')


def main():
    web = Path(sys.argv[1] if len(sys.argv) > 1 else 'packages/app/build/web')
    dateien = {}
    for datei in sorted(web.rglob('*')):
        rel = datei.relative_to(web).as_posix()
        if datei.is_file() and RELEVANT.match(rel) and not rel.endswith('.symbols'):
            dateien[rel] = datei.stat().st_size
    index = web / 'index.html'
    html = index.read_text(encoding='utf-8')
    if not PLATZHALTER.search(html):
        sys.exit('Platzhalter #startgroessen in index.html nicht gefunden')
    daten = json.dumps({'version': 1, 'dateien': dateien}, separators=(',', ':'))
    index.write_text(PLATZHALTER.sub(lambda m: m.group(1) + daten + m.group(2), html), encoding='utf-8')
    print(f'{len(dateien)} Startdateien, {sum(dateien.values()) // 1024} KB → {index}')


if __name__ == '__main__':
    main()
