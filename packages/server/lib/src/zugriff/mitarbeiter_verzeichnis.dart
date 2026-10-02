import 'dart:convert';
import 'dart:io';

import 'mitarbeiter_zugang.dart';

/// Quelle der Mitarbeiter-Zugänge. Vorläufig eine JSON-Datei, später ObjectBox
/// (M0-15, Entität `Benutzer`).
class MitarbeiterVerzeichnis {
  MitarbeiterVerzeichnis(Iterable<MitarbeiterZugang> zugaenge)
    : _zugaenge = {for (final z in zugaenge) z.authId: z};

  /// Leeres Verzeichnis – nur Kunden (anonym) können sich anmelden.
  MitarbeiterVerzeichnis.leer() : _zugaenge = const {};

  /// Liest eine JSON-Liste von Zugängen (Format von [MitarbeiterZugang.alsJson]).
  factory MitarbeiterVerzeichnis.ausDatei(String pfad) {
    final liste = jsonDecode(File(pfad).readAsStringSync()) as List<Object?>;
    return MitarbeiterVerzeichnis(
      liste.cast<Map<String, Object?>>().map(MitarbeiterZugang.ausJson),
    );
  }

  final Map<String, MitarbeiterZugang> _zugaenge;

  MitarbeiterZugang? finde(String authId) => _zugaenge[authId];

  int get anzahl => _zugaenge.length;
}
