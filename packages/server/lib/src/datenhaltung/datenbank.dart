import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../../objectbox.g.dart';
import 'entitaeten.dart';

/// Kennzahlen für das Monitoring (M0-14).
class Kennzahlen {
  const Kennzahlen({
    required this.dateigroesse,
    required this.letzteSequenz,
    required this.anzahl,
  });

  final int dateigroesse;
  final int letzteSequenz;
  final Map<String, int> anzahl;
}

/// ObjectBox-Datenbank eines Backend-Dienstes mit Basisfeldern und
/// Änderungsprotokoll (M0-15, docs/architektur/datenmodell.md).
class Datenbank {
  Datenbank._(this.store, this.verzeichnis, this.knoten, this._uhr, this._ids);

  /// Öffnet (oder legt an) die Datenbank in [verzeichnis] für [knoten].
  factory Datenbank.oeffne(
    String verzeichnis, {
    required String knoten,
    HlcUhr? uhr,
    UuidV7? ids,
  }) {
    // openStore legt das Verzeichnis selbst an.
    return Datenbank._(
      openStore(directory: verzeichnis),
      verzeichnis,
      knoten,
      uhr ?? HlcUhr(knoten),
      ids ?? UuidV7(),
    );
  }

  final Store store;
  final String verzeichnis;
  final String knoten;
  final HlcUhr _uhr;
  final UuidV7 _ids;

  /// Speichert [objekt] (neu oder geändert) und protokolliert die Änderung in
  /// derselben Transaktion. Vergibt `uid`, setzt `hlc` und `knoten`.
  T speichere<T extends Basisdatensatz>(T objekt) => store.runInTransaction(
    TxMode.write,
    () => _schreibe(objekt, objekt.uid.isEmpty ? 'anlegen' : 'aendern'),
  );

  /// Löscht [objekt] als Grabstein (bleibt gespeichert, `geloeschtAm` gesetzt).
  T loesche<T extends Basisdatensatz>(T objekt) =>
      store.runInTransaction(TxMode.write, () {
        final hlc = _uhr.jetzt();
        objekt.geloeschtAm = hlc.millis;
        return _schreibe(objekt, 'loeschen', hlc: hlc);
      });

  T _schreibe<T extends Basisdatensatz>(T objekt, String art, {Hlc? hlc}) {
    if (objekt.uid.isEmpty) objekt.uid = _ids.neu();
    objekt
      ..hlc = (hlc ?? _uhr.jetzt()).toString()
      ..knoten = knoten;
    store.box<T>().put(objekt);
    store.box<Aenderung>().put(
      Aenderung(
        knoten: knoten,
        seq: letzteSequenz + 1,
        entitaet: T.toString(),
        uid: objekt.uid,
        partition: objekt.partition,
        hlc: objekt.hlc,
        art: art,
      ),
    );
    return objekt;
  }

  /// Höchste Sequenznummer dieses Knotens im Änderungsprotokoll (0 = leer).
  int get letzteSequenz {
    final abfrage =
        store
            .box<Aenderung>()
            .query(Aenderung_.knoten.equals(knoten))
            .order(Aenderung_.seq, flags: Order.descending)
            .build()
          ..limit = 1;
    try {
      return abfrage.findFirst()?.seq ?? 0;
    } finally {
      abfrage.close();
    }
  }

  /// Änderungen dieses Knotens nach Sequenznummer [seq], aufsteigend.
  List<Aenderung> aenderungenSeit(int seq) {
    final abfrage = store
        .box<Aenderung>()
        .query(
          Aenderung_.knoten.equals(knoten).and(Aenderung_.seq.greaterThan(seq)),
        )
        .order(Aenderung_.seq)
        .build();
    try {
      return abfrage.find();
    } finally {
      abfrage.close();
    }
  }

  /// Benutzer (Mitarbeiter) nach authid, ohne Grabsteine.
  Benutzer? benutzer(String authId) {
    final abfrage = store
        .box<Benutzer>()
        .query(
          Benutzer_.authId.equals(authId).and(Benutzer_.geloeschtAm.isNull()),
        )
        .build();
    try {
      return abfrage.findFirst();
    } finally {
      abfrage.close();
    }
  }

  Kennzahlen kennzahlen() => Kennzahlen(
    dateigroesse: File(p.join(verzeichnis, 'data.mdb')).lengthSync(),
    letzteSequenz: letzteSequenz,
    anzahl: {
      'Benutzer': store.box<Benutzer>().count(),
      'Aenderung': store.box<Aenderung>().count(),
    },
  );

  /// Konsistente Sicherung: kopiert die Datenbankdatei innerhalb einer
  /// Schreibtransaktion nach [zielVerzeichnis] – andere Schreiber warten so
  /// lange, die Kopie ist damit in sich stimmig.
  void sichere(String zielVerzeichnis) {
    Directory(zielVerzeichnis).createSync(recursive: true);
    store.runInTransaction(TxMode.write, () {
      File(p.join(verzeichnis, 'data.mdb'))
          .copySync(p.join(zielVerzeichnis, 'data.mdb'));
    });
  }

  void schliesse() => store.close();
}
