# FlatBuffers-Transport (#110, Schritt 1)

Stand 18.10.2026, connectanum 3.0.0-beta.8.

## Umstellung

- Die Web-App verbindet sich mit `WebSocketTransport.withFlatBuffersSerializer` (Unterprotokoll `wamp.2.flatbuffers`). Der Router nimmt das ohne Einstellung an; Dienste und Tests mit JSON laufen parallel weiter.
- Läuft im Browser (Flutter Web, WASM): Smoke-Test Web-App → Router → Hallo-Dienst in headless Chrome grün.

## Messung `router_rpc_benchmark` (lokal, je 2 Läufe, WebSocket, Echo-RPC)

| Kodierung | klein (`ping`) | groß (500 Dielen als Liste von Maps) |
|---|---|---|
| JSON | 2,85–2,94 ms | 3,33–3,47 ms |
| CBOR | 2,69–2,72 ms | 7,55–7,59 ms |
| FlatBuffers | 2,57–2,74 ms | 7,42–7,94 ms |

## Befund

- **Kleine Nachrichten:** FlatBuffers ist am schnellsten (rund 5–10 % unter JSON).
- **Große dynamische Nutzlasten:** Dynamische Argumente (Listen, Maps) werden auch im FlatBuffers-Umschlag als **CBOR** kodiert (connectanum-Doku zu `LazyPayloadEncoding`). Der CBOR-Codec ist dabei gut doppelt so langsam wie JSON; der FlatBuffers-Umschlag selbst kostet fast nichts. → an Alexander gemeldet (CBOR-Codec bei großen Listen/Maps).
- **Folgerung:** Der Geschwindigkeitsgewinn kommt nicht vom Umschalten des Transports, sondern von **typisierten Nutzlasten**: ein Schema-FlatBuffer als „Packed PPT Payload“ (`LazyMessagePayload.packed`), den der Router unverändert weiterreicht. Fachdaten (Planungen, Artikel) deshalb nie als dynamische Listen/Maps übertragen, sondern mit dem gemeinsamen Schema aus Schritt 2.
