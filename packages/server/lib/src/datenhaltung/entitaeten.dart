import 'dart:typed_data';

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

/// Kopf einer gespeicherten Konfiguration (M9-05, Bewegungsdaten): fachlicher
/// Schlüssel ist die Konfigurationsnummer, sie ist zugleich die Partition.
@Entity()
class Konfiguration implements Basisdatensatz {
  Konfiguration({
    required this.nummer,
    required this.tag,
    required this.laufend,
  }) : partition = nummer;

  @override
  @Id()
  int id = 0;

  @override
  @Unique()
  String uid = '';

  @override
  String partition;

  @override
  String hlc = '';

  @override
  String knoten = '';

  @override
  int? geloeschtAm;

  @override
  int schema = 1;

  /// Konfigurationsnummer `JJJJ-MM-TT-NNNN`.
  @Unique()
  String nummer;

  /// Kalendertag `JJJJ-MM-TT` – für die laufende Nummer je Tag.
  @Index()
  String tag;

  /// Laufende Nummer des Tages (`NNNN`).
  int laufend;

  /// HLC von Version 1 (Anlegen); [hlc] ist die letzte Änderung.
  String erstelltAm = '';

  /// Höchste gespeicherte Version (0 = noch keine).
  int aktuelleVersion = 0;
}

/// Eine Version einer Konfiguration (M9-05): wird einmal angelegt und nie
/// geändert (append-only). [inhalt] ist die Planung im Transportformat
/// (`Planung.zuBytes`), das seine eigene Schema-Version trägt.
@Entity()
class KonfigurationsVersion implements Basisdatensatz {
  KonfigurationsVersion({
    required this.nummer,
    required this.version,
    required this.inhalt,
  }) : partition = nummer,
       schluessel = '$nummer/$version';

  @override
  @Id()
  int id = 0;

  @override
  @Unique()
  String uid = '';

  @override
  String partition;

  @override
  String hlc = '';

  @override
  String knoten = '';

  @override
  int? geloeschtAm;

  @override
  int schema = 1;

  /// `JJJJ-MM-TT-NNNN/version` – fachlicher Schlüssel.
  @Unique()
  String schluessel;

  @Index()
  String nummer;

  int version;

  @Property(type: PropertyType.byteVector)
  Uint8List inhalt;
}

/// Automatisch zwischengespeicherter Stand (M9-05) je Sitzungsschlüssel des
/// Browsers: genau ein Datensatz, der überschrieben wird – keine Versionen.
/// [nummer]/[version] nennen die gespeicherte Konfiguration, auf der er
/// beruht (leer = noch nie gespeichert). Nach [ablaufAm] gilt er als weg.
@Entity()
class Zwischenstand implements Basisdatensatz {
  Zwischenstand({required this.schluessel, required this.inhalt})
    : partition = schluessel;

  @override
  @Id()
  int id = 0;

  @override
  @Unique()
  String uid = '';

  @override
  String partition;

  @override
  String hlc = '';

  @override
  String knoten = '';

  @override
  int? geloeschtAm;

  @override
  int schema = 1;

  @Unique()
  String schluessel;

  @Property(type: PropertyType.byteVector)
  Uint8List inhalt;

  String nummer = '';
  int version = 0;

  /// Ablauf (ms seit 1970).
  int ablaufAm = 0;
}
