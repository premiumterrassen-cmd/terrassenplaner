import 'dart:convert';
import 'dart:io';

import 'mitarbeiter_zugang.dart';

/// Quelle der Mitarbeiter-Zugänge für den Auth-Server.
abstract interface class MitarbeiterQuelle {
  MitarbeiterZugang? finde(String authId);
}

/// Mitarbeiter-Zugänge im Speicher (Tests) bzw. aus einer JSON-Datei, die
/// beim Start in die Datenbank übernommen wird (siehe [DatenbankMitarbeiter]).
class MitarbeiterVerzeichnis implements MitarbeiterQuelle {
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

  @override
  MitarbeiterZugang? finde(String authId) => _zugaenge[authId];

  int get anzahl => _zugaenge.length;

  Iterable<MitarbeiterZugang> get alle => _zugaenge.values;
}
