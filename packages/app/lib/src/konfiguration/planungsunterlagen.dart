import 'dart:typed_data';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'datei_stub.dart' if (dart.library.js_interop) 'datei_web.dart';

/// Holt die Planungsunterlagen (M9-06) einer gespeicherten Version vom
/// Server – erzeugt werden sie dort, die App bietet sie nur an.
typedef UnterlagenLaden = Future<Uint8List> Function(
  KonfigurationsStand stand,
  String sprache,
);

/// Bietet eine Datei zum Speichern oder Öffnen an (im Browser: Download).
typedef DateiAnbieten = void Function(Uint8List inhalt, String dateiname);

/// PDF-Knopf (M9-06): Unterlagen vom Server holen und anbieten.
final class Unterlagenabruf {
  const Unterlagenabruf(this.laden, {this.anbieten = dateiAnbieten});

  final UnterlagenLaden laden;
  final DateiAnbieten anbieten;

  /// Dateiname mit Nummer und Version, ohne Prüfcode (der steht im PDF).
  static String dateiname(KonfigurationsStand stand) =>
      'Planungsunterlagen_${stand.nummer.wert}_V${stand.version}.pdf';

  /// Holt die Unterlagen von [stand] in [sprache] und bietet sie an.
  Future<void> hole(KonfigurationsStand stand, String sprache) async =>
      anbieten(await laden(stand, sprache), dateiname(stand));
}
