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

# Schritt 2: gemeinsames Schema (19.10.2026)

## Aufbau

- **Generator** `packages/server/bin/schema_erzeugen.dart` (Logik in `lib/src/schema/schema_generator.dart`) liest `objectbox-model.json` und erzeugt `packages/domain/lib/src/schema/transport.g.dart`: je freigegebener Entität `baue<Entität>(…)` und `<Entität>Sicht` (liest Felder erst beim Zugriff, ohne Kopie).
- **Layout = ObjectBox:** Feldplatz = Property-ID − 1, Tabellengröße = höchste ID + 1, die lokale ObjectBox-ID wird weder geschrieben noch gelesen (neue Datensätze tragen ID 0). Unterstützt: bool, byte, short, int, long, float, double, String, Date; andere Typen brechen mit Hinweis ab.
- **Freigabe** in `lib/src/schema/transport_schema.dart` (Allowlist mit nullbaren Feldern) – zunächst nur `Aenderung` (Änderungsprotokoll, Grundlage für M11). Vertrauliches wie `Benutzer` (SCRAM-Schlüssel) gelangt so nie ins Frontend; ein Test sichert das ab.
- **Stapel** (`packages/domain/lib/src/schema/stapel.dart`): Umschlag für viele Datensätze einer Entität in einer Nachricht; jeder Eintrag ist ein vollständiger ObjectBox-FlatBuffer und wird als echter Ausschnitt des Puffers gelesen (`AusschnittLeser`, ohne Kopie).
- **Transport:** Packed PPT mit `WampNamen.pptSchema` = `x_terrassenplaner`, `pptSerializer` = `flatbuffers`; Dienst liest mit `onLazyInvokePayload` → `payload.packedPayloadBytes`.

## Absicherung

- Drift-Test: Generatorausgabe + `dart format` muss der eingecheckten Datei entsprechen – wer das ObjectBox-Modell ändert, muss neu erzeugen.
- Layout-Tests: ObjectBox liest mit dem domain-Paket gebaute Bytes (`objectFromFB`), das domain-Paket liest ObjectBox-Bytes (`objectToFB`), Speichern und Zurücklesen.
- PPT-Test: Stapel aus drei Änderungen kommt byte-genau samt PPT-Kennung beim Dienst an.

## Messung `stapel_rpc_benchmark` (500 Änderungen hin und zurück, Bauen + Lesen aller Felder)

| Variante | Rundlauf |
|---|---|
| JSON (Liste von Maps) | 4,37–5,06 ms |
| FlatBuffers typisiert (Stapel, Packed PPT) | 4,09–4,23 ms |

Aufgeteilt (500 Datensätze, ohne Netz): FlatBuffers bauen 0,21 ms / lesen 0,10 ms gegenüber JSON kodieren 0,40 ms / dekodieren 0,21 ms → **Kodierung etwa halb so teuer**, Nachricht aber etwa ein Drittel größer (88 KB gegenüber 66 KB: je Datensatz eigene vtable und eigener Puffer, damit er einzeln speicherbar bleibt).

## Befund

- Der Kodierungsgewinn ist real, im Rundlauf aber klein, weil **ein leerer RPC über den Router schon rund 2,8 ms** kostet (localhost). Diese Grundlatenz dominiert → an Alexander gemeldet (Weg Client → Router-Worker → interne Dienst-Sitzung).
- Der große Hebel von Schritt 3 liegt im Backend: Bytes ohne Objekt-Mapping in ObjectBox speichern (Adapter) und große Lesemengen ohne Umkodieren ausliefern.
