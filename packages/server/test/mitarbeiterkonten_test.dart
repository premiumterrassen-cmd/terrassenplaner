import 'dart:io';

import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

MitarbeiterZugang _zugang(String id, {String stored = 's'}) =>
    MitarbeiterZugang(
      authId: id,
      salt: 'salz',
      iterationen: 3,
      speicher: 64,
      storedKey: stored,
      serverKey: 'server',
    );

Matcher _kontoFehler(String meldung) => throwsA(
  isA<KontoFehler>()
      .having((e) => e.meldung, 'meldung', meldung)
      .having((e) => '$e', 'text', meldung),
);

void main() {
  late Directory ordner;
  late Datenbank db;
  late Mitarbeiterkonten konten;

  setUp(() {
    ordner = Directory.systemTemp.createTempSync('planer-mitarbeiter-');
    db = Datenbank.oeffne(ordner.path, knoten: 'k');
    konten = Mitarbeiterkonten(db);
  });

  tearDown(() {
    db.schliesse();
    ordner.deleteSync(recursive: true);
  });

  test('legt Konten an und findet sie wieder', () {
    konten
      ..anlegen(_zugang('bob@x.de'))
      ..anlegen(_zugang('anna@x.de'));
    final anna = konten.finde('anna@x.de')!;
    expect(anna.alsJson(), _zugang('anna@x.de').alsJson());
    expect(anna.gesperrt, isFalse);
    expect(konten.finde('carla@x.de'), isNull);
    expect(konten.datenbank, same(db));
    expect(konten.liste(), [
      (authId: 'anna@x.de', gesperrt: false),
      (authId: 'bob@x.de', gesperrt: false),
    ]);
    final b = db.benutzer('anna@x.de')!;
    expect([b.rolle, b.schema, b.partition], ['mitarbeiter', 2, 'global']);
    expect(db.aenderungenSeit(0).map((a) => a.art), ['anlegen', 'anlegen']);
  });

  test('kein zweites Konto mit derselben Adresse', () {
    konten.anlegen(_zugang('anna@x.de'));
    expect(
      () => konten.anlegen(_zugang('anna@x.de', stored: 'neu')),
      _kontoFehler('Konto anna@x.de gibt es schon'),
    );
    expect(konten.finde('anna@x.de')!.storedKey, 's');
    expect(db.letzteSequenz, 1);
  });

  test('Passwort setzen ersetzt alle Schlüssel, behält uid und Sperre', () {
    konten
      ..anlegen(_zugang('anna@x.de'))
      ..sperre('anna@x.de', gesperrt: true);
    final uid = db.benutzer('anna@x.de')!.uid;
    const neu = MitarbeiterZugang(
      authId: 'anna@x.de',
      salt: 'neues-salz',
      kdf: 'pbkdf2',
      iterationen: 4096,
      speicher: 0,
      storedKey: 'neu-s',
      serverKey: 'neu-v',
    );
    konten.setzePasswort(neu);
    final z = konten.finde('anna@x.de')!;
    expect(z.alsJson(), neu.alsJson());
    expect(z.gesperrt, isTrue);
    expect(db.benutzer('anna@x.de')!.uid, uid);
    expect(db.aenderungenSeit(2).single.art, 'aendern');
  });

  test('sperren und entsperren', () {
    konten.anlegen(_zugang('anna@x.de'));
    konten.sperre('anna@x.de', gesperrt: true);
    expect(konten.finde('anna@x.de')!.gesperrt, isTrue);
    expect(konten.liste(), [(authId: 'anna@x.de', gesperrt: true)]);
    konten.sperre('anna@x.de', gesperrt: false);
    expect(konten.finde('anna@x.de')!.gesperrt, isFalse);
    expect(db.letzteSequenz, 3);
  });

  test('unbekannte Konten: Fehler, nichts geschrieben', () {
    expect(
      () => konten.setzePasswort(_zugang('anna@x.de')),
      _kontoFehler('Konto anna@x.de gibt es nicht'),
    );
    expect(
      () => konten.sperre('anna@x.de', gesperrt: true),
      _kontoFehler('Konto anna@x.de gibt es nicht'),
    );
    expect(db.letzteSequenz, 0);
    expect(konten.liste(), isEmpty);
  });

  test('gelöschte Konten (Grabstein) zählen nicht', () {
    konten.anlegen(_zugang('anna@x.de'));
    db.loesche(db.benutzer('anna@x.de')!);
    expect(konten.finde('anna@x.de'), isNull);
    expect(konten.liste(), isEmpty);
  });
}
