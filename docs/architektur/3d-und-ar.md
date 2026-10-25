# 3D und AR (M3-10)

3D-Ansicht und AR kommen direkt nach dem Go-Live (M12). Damit M4 (Geometrie-Kern) nicht später umgebaut werden muss, legt M3-10 die Architektur jetzt fest und belegt sie mit einem Prototyp.

## Entscheidung

1. **Ein Geometriemodell im domain-Paket** für 2D, 3D und alle Berechnungen. Bauteile sind achsparallele Quader in Millimetern (`Bauteil`, `Quader`, `Bauteilart` in `packages/domain/lib/src/geometrie/`); Koordinaten: `x` längs der Dielen, `y` nach oben, `z` quer. Mengen, Zuschnitte, 2D-Zeichnung und 3D-Modell lesen dieselben Bauteile – es gibt keine zweite Geometrie nur für die Anzeige. Der Geometrie-Kern (M4-01) baut darauf auf und ersetzt die Prototyp-Funktion `rechteckTerrasse`.
2. **Der Server erzeugt das 3D-Modell als GLB** (glTF 2.0 binär, `packages/server/lib/src/modell3d/glb.dart`, eigener Schreiber ohne Fremdpaket): Meter, y nach oben, je Bauteilart ein Material. Die App rechnet nichts – „Frontend bleibt doof“.
3. **Übertragung über WAMP** als Binärargument (`Uint8List`) im FlatBuffers-Transport – kein zusätzlicher HTTP-Endpunkt, gleiche Anmeldung und Rechte wie alle anderen Aufrufe (`…kunde.modell3d.rechteck`, Prototyp).
4. **Anzeige mit `<model-viewer>`** (Google, Apache-2.0, 4.4.0) als HTML-Element in Flutter Web (`HtmlElementView`), WebGL. Die Bibliothek liegt unverändert in `packages/app/web/model-viewer/` (Herkunft und Lizenz dort) und wird erst beim Öffnen der 3D-Ansicht geladen – der normale Start bleibt ohne 1 MB JavaScript. Kein CDN zur Laufzeit.
5. **Dieselbe Datei für Download und AR**: model-viewer startet AR mit dem angezeigten GLB (`ar-modes="webxr scene-viewer quick-look"`): Android über Scene Viewer, iOS über Quick Look (USDZ erzeugt model-viewer im Browser aus dem GLB), sonst WebXR. Download = dasselbe GLB.

## Varianten

| Variante | Vorteile | Nachteile | Ergebnis |
|---|---|---|---|
| **Server erzeugt GLB, App zeigt mit model-viewer** | eine Datei für Anzeige, Download, AR; App ohne Geometrie; AR für Android und iOS ohne eigenen Code | 1 MB JS (nur bei Bedarf geladen); Bearbeiten in 3D nur über den Server | **gewählt** (Alexander, 25.10.2026) |
| Server erzeugt GLB, eigener WebGL-Viewer in Dart | keine Fremdbibliothek | AR (Quick Look, Scene Viewer, WebXR) müsste in M12 neu gebaut werden | verworfen |
| three.js in der App | viele Möglichkeiten (z. B. Ziehen in 3D) | AR nur über WebXR, kein iOS Quick Look ohne Zusatz; Versuchung, Geometrie im Browser zu rechnen | verworfen |
| App berechnet das Modell selbst | kein Server-Aufruf beim Drehen | widerspricht „Frontend bleibt doof“ und der Sternstruktur; zweite Geometrie | verworfen |

## Prototyp

- `rechteckTerrasse` (domain): durchgehende Dielen mit 5 mm Fuge (R-B06), letzte auf Restbreite; Unterkonstruktion bündig an den Stirnseiten, dazwischen höchstens im Achsabstand.
- `Modell3dDienst` (server): Rechteck 0,5–20 m je Seite, Beispielaufbau Diele 120 x 23 mm, UK 70 x 45 mm im empfohlenen Achsabstand der Robinie.
- App: `…/?prototyp=3d` öffnet `Modell3dSeite` (Terrasse 4 x 3 m). Smoke-Test `integration_test/modell3d_test.dart` lädt das GLB in headless Chrome (WebAssembly) und prüft, dass model-viewer es geladen hat.

## Messwerte (lokal, `server.Modell3d.*`)

| Messung | Wert |
|---|---|
| GLB erzeugen, 4 x 3 m (13 Lagen UK im Achsabstand 350 mm, 24 Dielen) | 0,6 ms, 28 KB |
| GLB erzeugen, 12 x 8 m | 1,4 ms, 74 KB |
| Erzeugen + Übertragen über den Router, 4 x 3 m | 3,4 ms je Aufruf |

Ein GLB je Planungsänderung ist damit unkritisch; Kompression (Draco/Meshopt) ist bei diesen Größen unnötig – model-viewer bräuchte dafür außerdem Decoder aus dem Netz.

## Folgen für spätere Meilensteine

- **M4-01 Geometrie-Kern:** liefert Bauteile im Modell oben (Quader genügen für Dielen, UK, Stellfüße; Gehrungen und Schrägen kommen als weitere Körper hinzu – dann wird das GLB-Netz je Körper statt je Quader erzeugt).
- **2D-Zeichnung (M4/M5):** zeichnet die Draufsicht derselben Bauteile.
- **M12 3D/AR:** Kamera, Licht, Holzstruktur (Textur im GLB), Download-Knopf, AR-Knopf – an der Architektur ändert sich nichts.
- Ist das GLB groß (z. B. mehrere Flächen mit Treppen), kann es als typisierte Nutzlast (PPT) laufen; der Router reicht die Bytes ohne Umkodierung durch (siehe `docs/erkenntnisse/flatbuffers.md`).
