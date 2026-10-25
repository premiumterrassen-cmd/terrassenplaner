# model-viewer 4.4.0 (Fremdbibliothek)

- Quelle: npm-Paket `@google/model-viewer@4.4.0`, Datei `dist/model-viewer.min.js` unverändert (Integrität des Pakets per SHA-512 aus der npm-Registry geprüft, 25.10.2026).
- Lizenz: Apache-2.0 (`LICENSE`); das Bündel enthält lit (BSD-3-Clause), three.js (MIT) und fflate (MIT) mit ihren Lizenzhinweisen im Quelltext.
- Zweck: Anzeige des vom Server erzeugten GLB im Browser, später AR mit derselben Datei (M3-10, M12). Wird erst beim Öffnen der 3D-Ansicht geladen.
- Lädt zur Laufzeit nichts aus dem Netz nach, solange Modelle ohne Draco-/Basis-Kompression kommen (unsere GLB-Dateien sind unkomprimiert).
