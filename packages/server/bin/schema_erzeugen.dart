import 'dart:io';

import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// Erzeugt `packages/domain/lib/src/schema/transport.g.dart` aus dem
/// ObjectBox-Modell und formatiert sie mit `dart format`. Aufruf aus der
/// Workspace-Wurzel: `dart run packages/server/bin/schema_erzeugen.dart`
Future<void> main() async {
  final modell = File(transportSchemaModell).readAsStringSync();
  File(transportSchemaZiel)
    ..createSync(recursive: true)
    ..writeAsStringSync(SchemaGenerator.erzeuge(modell, transportEntitaeten));
  final format = await Process.run(Platform.resolvedExecutable, [
    'format',
    transportSchemaZiel,
  ]);
  stdout.writeln('Erzeugt: $transportSchemaZiel');
  exitCode = format.exitCode;
}
