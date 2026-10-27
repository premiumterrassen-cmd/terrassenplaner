# Ladebildschirm (M3-08, 06.10.2026)

**Technik** nach dem Verfahren von dls-gmbh.biz/mein-essen (eigener Code), **Gestaltung** wie der bisherige Terrassenplaner (Vorgabe Alexander 06.10.2026).

## Aufbau

- `packages/app/web/index.html` – Ladebild als reines HTML/CSS, sofort sichtbar: RobinienWelt-Logo (`web/ladebild/robinienwelt-logo.svg`, aus dem bisherigen Planer), Jahresring-Motiv, Karte mit Titel, Balken (#b0864b auf #dcdcdc), Prozent, Status; Hintergrund #f5f0e8; Knopf „Erneut versuchen“ (#95c11c).
- `web/ladebild/fortschritt.js` – echte Prozentanzeige: zählt geladene Bytes (fetch wird über `pipeThrough` mit einem zählenden `TransformStream` durchgereicht, ohne Puffern – WebAssembly kompiliert weiter streamend; Skripte/Cache über Ressourcen-Zeiten) gegen die Größenliste. Plan = Einstieg des gewählten Builds (`main.dart.wasm` + `.mjs` bzw. `main.dart.js`) + Renderer in der Variante, die Flutter für den Browser wählt (`skwasm`, `skwasm_heavy`, `wimp` bzw. `canvaskit`, `chromium/canvaskit`, `webparagraph/canvaskit`). Prozent steigt monoton, 100 % erst wenn Flutter zeichnet; bei Unstimmigkeit unbestimmter Balken. Phasen: laden → Darstellung vorbereiten → öffnen; Hinweise „langsam“ (10 s ohne Fortschritt) und „offline“; Fehler mit „Erneut versuchen“. `planerLadebildschirm.zustand()` für Tests/Fehlersuche.
- `web/flutter_bootstrap.js` – eigener Start: meldet Phasen, ruft nach `runApp()` `fertig()` (zwei Bilder abwarten, 0,2 s ausblenden, bei „Bewegung reduzieren“ sofort entfernen). Renderer kommt per `canvasKitBaseUrl: 'canvaskit/'` vom **eigenen Server** statt von gstatic.com (messbar, keine Google-Anfrage).
- `tool/startgroessen.py` – schreibt nach `flutter build web` die Größen der Startdateien in `#startgroessen` (Build-Chain), auch aus Unterordnern von `canvaskit/`.
- `tool/ladebild/pruefung.mjs` – Prüfung und Benchmark im echten headless Chrome über das DevTools-Protokoll (Node, ohne Zusatzpakete); läuft in `tool/smoke.sh` gegen den Release-Build mit Router.

## Geprüft (`tool/ladebild/pruefung.mjs`, 27.10.2026)

Zwei Browser-Umgebungen: mit WebGL (Software-Rendering) wählt Flutter WebAssembly + Skwasm, ohne WebGL den JS-Build + CanvasKit.

| Fall | Prüfung |
|---|---|
| kalter Start | Ladebild im ersten HTML und gemalt, bevor es entfernt wird; Plan erkannt und Größen stimmen; Prozent monoton, 99 % vor dem ersten Bild, endet bei 100 %; keine Anfrage an fremde Server (Schriften lokal); keine Konsolenfehler; `fetch` wiederhergestellt |
| Browser-Cache | zweiter Start im selben Kontext: ebenso monoton bis 100 % |
| barrierefrei | `role=status` + `aria-live=polite`, `progressbar` mit Name und 0–100, `aria-valuenow` wird gesetzt, Logo mit Alternativtext; „Bewegung reduzieren“ → sofort entfernt statt ausgeblendet |
| langsam | Programmdatei angehalten → nach 10 s Hinweis, danach Start |
| offline | Netz aus → Hinweis, Netz an → Hinweis weg, danach Start |
| Fehler | Programmdatei scheitert → „Start nicht möglich“ ohne Prozent, „Erneut versuchen“ sichtbar; Klick startet die App |

## Gefunden und behoben

- **Kein Prozentwert im JS-Build (Flutter 3.47):** Ohne Skwasm lädt Flutter in Chromium `canvaskit/chromium/canvaskit.*`. `startgroessen.py` erfasste nur `canvaskit/*`, der Plan blieb leer → nur unbestimmter Balken. Jetzt auch Unterordner; `wimp` zählt als Skwasm-Variante.
- **CI-Linux: `--disable-gpu` reicht nicht für den JS-Build.** Chrome bietet dort weiter WebGL über SwiftShader an, der Loader nimmt WebAssembly. Die JS-Umgebung schaltet WebGL zusätzlich mit `--disable-webgl --disable-3d-apis` ab.
- **Prüfung „sofort sichtbar“:** Mit Software-WebGL meldet Chrome `first-contentful-paint` erst nach dem GPU-Start (> 2 s, teils nach dem Entfernen des Ladebilds). Der Vergleich mit dem Entfernen gilt darum nur ohne WebGL (dort ≈ 50–70 ms). Mit WebGL wird geprüft, dass das Ladebild im ersten HTML steht und per CSS sichtbar ist.
- **Tab im Hintergrund:** Dort pausiert `requestAnimationFrame`. Das Ladebild bleibt dann stehen, bis der Tab sichtbar wird (gewollt). Die Prüfung holt deshalb jede Testseite nach vorn (`Page.bringToFront`), sonst schlug „langsam“ gelegentlich fehl.
- **Späte Abfang-Ereignisse:** Nach `Fetch.disable` kann noch ein `Fetch.requestPaused` eintreffen. Das `continueRequest` darauf scheitert („Fetch domain is not enabled“) und brachte die Prüfung in der CI zum Absturz. Fehler nach dem Freigeben werden jetzt ignoriert (Chrome setzt die Anfrage selbst fort), solange das Abfangen aktiv ist, landen sie als Konsolenfehler im Fall.
- **Ohne erreichbaren WAMP-Router wirft die App eine unbehandelte Ausnahme** (beide Builds, nach dem Ladebild). Gehört zum Verbindungsaufbau, nicht zum Ladebild – eigener Punkt. Die Prüfung läuft darum mit Router (`/ws` wird wie von Traefik weitergereicht).

## Benchmark

`tool/benchmark.sh` mit `LADEBILD_WEB=packages/app/build/web` (Build-Chain: Job „Benchmarks“). Median aus 7 Starts in frischen Browser-Kontexten (ohne HTTP-Cache, nach einem Aufwärmstart), lokal (MacBook, 27.10.2026):

| Wert | lokal |
|---|---|
| `app.Ladebild.ErstesBild` – Navigation bis `fertig()` | 131 ms |
| `app.Ladebild.ErstesBildOhneZaehlen` – dasselbe mit leerer Hülle statt `fortschritt.js` | 139 ms |
| `app.Ladebild.Skriptzeit` – CPU-Zeit in `fortschritt.js` | 13 ms |

Der Mehraufwand des Zählens ist nicht messbar (Unterschied im Rauschen). Die Skriptzeit besteht fast ganz aus dem Weiterreichen der Datenstücke, die der Browser sonst selbst an den WebAssembly-Compiler gibt; die händische `pull`-Schleife und `pipeThrough` kosten gleich viel. Der allererste Start im headless Chrome dauert länger (≈ 1,6–2,7 s), weil dort die Software-GPU anläuft.
