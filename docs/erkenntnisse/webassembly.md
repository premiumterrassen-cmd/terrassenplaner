# Web-App als WebAssembly (M0-16, 06.10.2026)

## Umsetzung

- Build-Chain und Smoke-Tests: `flutter build web --release --wasm` bzw. `flutter drive … --wasm` (dart2wasm + Skwasm-Renderer). Der Build enthält zusätzlich die JavaScript-Fassung; `flutter_bootstrap.js` wählt im Browser automatisch (WasmGC-fähige Browser → WASM, sonst JS + CanvasKit).
- nginx (systemd und Container) sendet `Cross-Origin-Opener-Policy: same-origin` und `Cross-Origin-Embedder-Policy: require-corp` – Voraussetzung für mehrthreadiges Skwasm (`crossOriginIsolated`). Die Header werden in Locations mit eigenem `add_header` wiederholt (nginx erbt sie sonst nicht). gzip für `.wasm`/`.js`.
- **Impeller:** Flutter 3.47.6 bietet Impeller im Web nicht an – Web rendert über CanvasKit/Skwasm. Bei jedem Flutter-Update prüfen.

## Größen (Stand Grundgerüst, gzip)

| Pfad | Programm | Renderer | zusammen |
|---|---|---|---|
| WebAssembly | `main.dart.wasm` 498 KB | `skwasm.wasm` 1.503 KB | ≈ 2,0 MB |
| JavaScript (Rückfall) | `main.dart.js` 503 KB | `canvaskit.wasm` 2.851 KB | ≈ 3,35 MB |

→ Der WASM-Pfad lädt rund 40 % weniger. Ladezeiten im Browser werden mit dem Ladebildschirm (M3-08) gemessen.

## Deployment-Befunde (06.10.2026)

- Debian-nginx kennt `.mjs` nicht → `main.dart.mjs` kam als `application/octet-stream`, Chrome lädt das Modul nicht (weiße Seite). Lösung: eigene Location mit `default_type text/javascript`.
- Flutter-Dateien ohne Hash im Namen (`main.dart.mjs/.wasm/.js`, `index.html`, Bootstrap, Service-Worker) mit `Cache-Control: no-cache` ausliefern – sonst hängen Browser an alten oder fehlerhaften Fassungen.
- Geprüft auf https://alto.terrassenplaner.eu: `skwasm.wasm`, `main.dart.mjs`, `main.dart.wasm` geladen, `crossOriginIsolated === true`.
