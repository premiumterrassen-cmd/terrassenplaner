import 'dart:async';
import 'dart:io';

import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

Benutzer _benutzer(String authId) => Benutzer(
  authId: authId,
  salt: 's',
  kdf: 'argon2id13',
  iterationen: 1,
  speicher: 8,
  storedKey: 'a',
  serverKey: 'b',
);

void main() {
  late Directory ordner;
  late Datenbank db;
  late String ziel;
  final zeit = DateTime.utc(2026, 11, 5, 3, 15);

  setUp(() {
    ordner = Directory.systemTemp.createTempSync('planer-sicherung-');
    db = Datenbank.oeffne('${ordner.path}/daten', knoten: 'knoten-a');
    ziel = '${ordner.path}/sicherung';
  });

  tearDown(() {
    db.schliesse();
    ordner.deleteSync(recursive: true);
  });

  /// Stellt die Sicherung wie das Skript planer-wiederherstellung her: Datei
  /// in ein leeres Datenverzeichnis legen und als Datenbank öffnen.
  Datenbank wiederherstellen() {
    final daten = Directory('${ordner.path}/wiederhergestellt')..createSync();
    File('$ziel/${Sicherungsdienst.datei}').copySync('${daten.path}/data.mdb');
    final kopie = Datenbank.oeffne(daten.path, knoten: 'knoten-a');
    addTearDown(kopie.schliesse);
    return kopie;
  }

  test('legt geprüfte Kopie und Stand ab, Arbeitsordner verschwindet', () {
    db
      ..speichere(_benutzer('anna'))
      ..speichere(_benutzer('bert'));

    expect(Sicherungsdienst.sichere(db, ziel, zeit), 2);

    expect(
      File('$ziel/stand').readAsStringSync(),
      '${zeit.millisecondsSinceEpoch ~/ 1000} 2\n',
    );
    expect(Directory('$ziel/.entstehend').existsSync(), isFalse);
    final kopie = wiederherstellen();
    expect(kopie.benutzer('anna')!.authId, 'anna');
    expect(kopie.benutzer('bert')!.authId, 'bert');
    expect(kopie.letzteSequenz, 2);
  });

  test('Reste eines abgebrochenen Laufs werden verworfen, neuer Stand ersetzt '
      'den alten', () {
    db.speichere(_benutzer('anna'));
    Sicherungsdienst.sichere(db, ziel, zeit);
    Directory('$ziel/.entstehend').createSync();
    File('$ziel/.entstehend/data.mdb').writeAsStringSync('kaputt');
    db.speichere(_benutzer('bert'));

    expect(Sicherungsdienst.sichere(db, ziel, zeit), 2);

    expect(File('$ziel/stand').readAsStringSync(), endsWith(' 2\n'));
    expect(wiederherstellen().benutzer('bert'), isNotNull);
  });

  test('Probe-Wiederherstellung erkennt abweichende Sequenz', () {
    db.speichere(_benutzer('anna'));
    final kopie = '${ordner.path}/probe';
    db.sichere(kopie);

    expect(
      () => Sicherungsdienst.probeWiederherstellung(kopie, 'knoten-a', 2),
      throwsA(
        isA<SicherungUngueltig>().having(
          (f) => f.toString(),
          'Meldung',
          'SicherungUngueltig: Sequenz 1 statt 2',
        ),
      ),
    );
    // Die Probe schließt die Kopie auch im Fehlerfall wieder.
    expect(Sicherungsdienst.probeWiederherstellung(kopie, 'knoten-a', 1), 1);
  });

  test('sichert bei jeder Anforderung und meldet ins Protokoll', () async {
    final anforderungen = StreamController<Object?>();
    final meldungen = <String>[];
    final dienst = Sicherungsdienst.starte(
      db,
      ziel,
      anforderungen.stream,
      protokoll: meldungen.add,
      uhr: () => zeit,
    );
    addTearDown(dienst.stoppe);

    db.speichere(_benutzer('anna'));
    anforderungen.add(null);
    await pumpEventQueue();
    expect(meldungen, ['Sicherung $ziel (Sequenz 1)']);
    expect(
      File('$ziel/stand').readAsStringSync(),
      '${zeit.millisecondsSinceEpoch ~/ 1000} 1\n',
    );

    db.speichere(_benutzer('bert'));
    anforderungen.add(null);
    await pumpEventQueue();
    expect(meldungen.last, 'Sicherung $ziel (Sequenz 2)');

    await dienst.stoppe();
    anforderungen.add(null);
    await pumpEventQueue();
    expect(meldungen, hasLength(2));
  });

  test('Fehler beenden den Dienst nicht', () async {
    File(ziel).writeAsStringSync('kein Verzeichnis');
    final anforderungen = StreamController<Object?>();
    final meldungen = <String>[];
    final dienst = Sicherungsdienst.starte(
      db,
      ziel,
      anforderungen.stream,
      protokoll: meldungen.add,
    );
    addTearDown(dienst.stoppe);

    anforderungen
      ..add(null)
      ..add(null);
    await pumpEventQueue();

    expect(meldungen, hasLength(2));
    expect(meldungen.first, startsWith('Sicherung fehlgeschlagen: '));
  });

  test('ohne Protokoll und Uhr: still, aktuelle Zeit', () async {
    final anforderungen = StreamController<Object?>();
    final dienst = Sicherungsdienst.starte(db, ziel, anforderungen.stream);
    addTearDown(dienst.stoppe);

    anforderungen.add(null);
    await pumpEventQueue();

    final sekunden = int.parse(
      File('$ziel/stand').readAsStringSync().split(' ').first,
    );
    expect(
      sekunden,
      closeTo(DateTime.now().millisecondsSinceEpoch ~/ 1000, 60),
    );
    // Fehler ohne Protokoll werden ebenso geschluckt.
    Directory(ziel).deleteSync(recursive: true);
    File(ziel).writeAsStringSync('kein Verzeichnis');
    anforderungen.add(null);
    await pumpEventQueue();
  });
}
