import 'dart:convert';
import 'dart:io';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Artikeldatei auf dem Datenträger (M2-06): Der Importer erzeugt sie, der
/// Server prüft regelmäßig, ob ein neuer Stand vorliegt.
class ArtikeldateiQuelle {
  ArtikeldateiQuelle(this.pfad, {Iterable<Holzart>? holzarten})
    : holzarten = List.unmodifiable(holzarten ?? [robinie]);

  /// Umgebungsvariable mit dem Pfad der Artikeldatei.
  static const umgebungsvariable = 'PLANER_ARTIKELDATEI';

  /// Standardpfad, relativ zum Arbeitsverzeichnis des Dienstes.
  static const standardPfad = 'artikel.json';

  /// Stand, solange noch keine Artikeldatei vorliegt.
  static final leer = Artikeldatei(
    quelle: 'keine Artikeldatei',
    version: 'leer',
    eintraege: const [],
  );

  final String pfad;
  final List<Holzart> holzarten;
  DateTime? _gelesen;

  /// Die Artikeldatei, wenn sie seit dem letzten Aufruf neu ist oder sich
  /// geändert hat; sonst `null`. Ein fehlerhafter Stand wirft genau einmal
  /// (der nächste Versuch folgt erst bei der nächsten Änderung).
  Artikeldatei? neuerStand() {
    final datei = File(pfad);
    if (!datei.existsSync()) return null;
    final geaendert = datei.lastModifiedSync();
    if (geaendert == _gelesen) return null;
    _gelesen = geaendert;
    return Artikeldatei.ausJson(
      jsonDecode(datei.readAsStringSync()) as Map<String, Object?>,
      holzarten,
    );
  }
}
