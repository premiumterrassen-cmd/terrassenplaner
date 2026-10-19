/// Entitäten, die als FlatBuffers über WAMP laufen dürfen (#110), mit ihren
/// nullbaren Feldern. Nur hier gelistete Entitäten erhalten Code im
/// domain-Paket – vertrauliche Daten (z. B. SCRAM-Schlüssel in `Benutzer`)
/// gelangen so nie ins Frontend.
const transportEntitaeten = <String, Set<String>>{
  // Änderungsprotokoll: Grundlage für Abgleich und Verteilung (M11).
  'Aenderung': {},
};

/// Ziel der erzeugten Datei, relativ zur Workspace-Wurzel.
const transportSchemaZiel = 'packages/domain/lib/src/schema/transport.g.dart';

/// Quelle: das eingecheckte ObjectBox-Modell, relativ zur Workspace-Wurzel.
const transportSchemaModell = 'packages/server/lib/objectbox-model.json';
