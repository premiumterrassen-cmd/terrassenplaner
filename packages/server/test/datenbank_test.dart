import 'dart:io';
import 'dart:math';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

Benutzer _anna() => Benutzer(
  authId: 'anna',
  salt: 's',
  iterationen: 1,
  storedKey: 'a',
  serverKey: 'b',
);

void main() {
  late Directory ordner;
  late Datenbank db;
  var zeit = 1000;

  setUp(() {
    ordner = Directory.systemTemp.createTempSync('planer-db-');
    zeit = 1000;
    db = Datenbank.oeffne(
      '${ordner.path}/daten',
      knoten: 'knoten-a',
      uhr: HlcUhr(
        'knoten-a',
        uhr: () => DateTime.fromMillisecondsSinceEpoch(zeit),
      ),
      ids: UuidV7(
        uhr: () => DateTime.fromMillisecondsSinceEpoch(zeit),
        zufall: Random(1),
      ),
    );
  });

  tearDown(() {
    db.schliesse();
    ordner.deleteSync(recursive: true);
  });

  test('neuer Datensatz bekommt uid, HLC, Knoten und Protokolleintrag', () {
    final anna = db.speichere(_anna());
    expect(anna.id, greaterThan(0));
    expect(UuidV7.zeitstempel(anna.uid), 1000);
    expect(anna.hlc, '0000000001000-0000-knoten-a');
    expect(anna.knoten, 'knoten-a');
    expect(anna.partition, 'global');
    expect(anna.schema, 1);
    expect(anna.geloeschtAm, isNull);
    expect(anna.rolle, 'mitarbeiter');

    final protokoll = db.aenderungenSeit(0);
    expect(protokoll, hasLength(1));
    final eintrag = protokoll.single;
    expect(eintrag.schluessel, 'knoten-a:1');
    expect(eintrag.seq, 1);
    expect(eintrag.knoten, 'knoten-a');
    expect(eintrag.entitaet, 'Benutzer');
    expect(eintrag.uid, anna.uid);
    expect(eintrag.partition, 'global');
    expect(eintrag.hlc, anna.hlc);
    expect(eintrag.art, 'anlegen');
  });

  test('Änderung behält uid, neuer HLC, Sequenz lückenlos', () {
    final anna = db.speichere(_anna());
    final uid = anna.uid;
    zeit = 2000;
    db.speichere(anna..storedKey = 'neu');
    expect(anna.uid, uid);
    expect(anna.hlc, '0000000002000-0000-knoten-a');
    expect(db.letzteSequenz, 2);
    expect(db.aenderungenSeit(1).single.art, 'aendern');
    expect(db.aenderungenSeit(0).map((a) => a.seq), [1, 2]);
    expect(db.aenderungenSeit(2), isEmpty);
  });

  test('Löschen als Grabstein: bleibt gespeichert, nicht mehr auffindbar', () {
    final anna = db.speichere(_anna());
    expect(db.benutzer('anna'), isNotNull);
    zeit = 3000;
    db.loesche(anna);
    expect(anna.geloeschtAm, 3000);
    expect(db.benutzer('anna'), isNull);
    expect(db.store.box<Benutzer>().count(), 1);
    expect(db.aenderungenSeit(1).single.art, 'loeschen');
  });

  test('benutzer() findet nach authid', () {
    db.speichere(_anna());
    expect(db.benutzer('anna')!.storedKey, 'a');
    expect(db.benutzer('bob'), isNull);
  });

  test('leeres Protokoll: Sequenz 0', () {
    expect(db.letzteSequenz, 0);
    expect(db.aenderungenSeit(0), isEmpty);
  });

  test('Kennzahlen: Dateigröße, Sequenz, Anzahl je Entität', () {
    db.speichere(_anna());
    final k = db.kennzahlen();
    expect(k.dateigroesse, greaterThan(0));
    expect(k.letzteSequenz, 1);
    expect(k.anzahl, {'Benutzer': 1, 'Aenderung': 1});
  });

  test('Sicherung lässt sich als eigene Datenbank öffnen', () {
    db.speichere(_anna());
    final ziel = '${ordner.path}/sicherung';
    db.sichere(ziel);
    final kopie = Datenbank.oeffne(ziel, knoten: 'knoten-a');
    addTearDown(kopie.schliesse);
    expect(kopie.benutzer('anna')!.authId, 'anna');
    expect(kopie.letzteSequenz, 1);
    expect(kopie.verzeichnis, ziel);
    expect(kopie.knoten, 'knoten-a');
  });

  test('ohne Uhr und ID-Erzeuger: aktuelle Zeit', () {
    final ziel = '${ordner.path}/standard';
    final standard = Datenbank.oeffne(ziel, knoten: 'k');
    addTearDown(standard.schliesse);
    final b = standard.speichere(_anna());
    expect(
      UuidV7.zeitstempel(b.uid),
      closeTo(DateTime.now().millisecondsSinceEpoch, 5000),
    );
    expect(Hlc.ausText(b.hlc).knoten, 'k');
  });
}
