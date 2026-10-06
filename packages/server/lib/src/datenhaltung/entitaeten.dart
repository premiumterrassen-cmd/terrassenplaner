import 'package:objectbox/objectbox.dart';

/// Gemeinsame Basisfelder aller gespeicherten Datensätze
/// (docs/architektur/datenmodell.md). `id` ist die lokale ObjectBox-ID und
/// wird nie nach außen gegeben – Verweise laufen über [uid].
abstract interface class Basisdatensatz {
  int get id;

  /// Globale ID (UUIDv7).
  String get uid;
  set uid(String wert);

  /// Partitionsschlüssel für die spätere Verteilung (M11).
  String get partition;
  set partition(String wert);

  /// Hybrid-Logical-Clock-Zeitstempel der letzten Änderung.
  String get hlc;
  set hlc(String wert);

  /// Knoten, auf dem zuletzt geändert wurde.
  String get knoten;
  set knoten(String wert);

  /// Grabstein: Zeitpunkt der Löschung (ms seit 1970) oder null.
  int? get geloeschtAm;
  set geloeschtAm(int? wert);

  /// Schema-Version des Datensatzes.
  int get schema;
  set schema(int wert);
}

/// Eintrag im Änderungsprotokoll – in derselben Transaktion wie die Änderung
/// geschrieben, lückenlos fortlaufend je Knoten.
@Entity()
class Aenderung {
  Aenderung({
    required this.knoten,
    required this.seq,
    required this.entitaet,
    required this.uid,
    required this.partition,
    required this.hlc,
    required this.art,
  }) : schluessel = '$knoten:$seq';

  @Id()
  int id = 0;

  /// `knoten:seq` – je Knoten eindeutig.
  @Unique()
  String schluessel;

  String knoten;

  @Index()
  int seq;

  String entitaet;
  String uid;
  String partition;
  String hlc;

  /// `anlegen`, `aendern` oder `loeschen`.
  String art;
}

/// Mitarbeiter-Zugang (Referenzdaten, Partition `global`): nur abgeleitete
/// SCRAM-Schlüssel, nie das Passwort.
@Entity()
class Benutzer implements Basisdatensatz {
  Benutzer({
    required this.authId,
    required this.salt,
    required this.iterationen,
    required this.storedKey,
    required this.serverKey,
    this.rolle = 'mitarbeiter',
  });

  @override
  @Id()
  int id = 0;

  @override
  @Unique()
  String uid = '';

  @override
  String partition = 'global';

  @override
  String hlc = '';

  @override
  String knoten = '';

  @override
  int? geloeschtAm;

  @override
  int schema = 1;

  @Unique()
  String authId;

  String salt;
  int iterationen;
  String storedKey;
  String serverKey;
  String rolle;
}
