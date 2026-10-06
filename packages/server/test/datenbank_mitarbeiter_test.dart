import 'dart:io';

import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

MitarbeiterZugang _zugang(String id, {String stored = 's'}) =>
    MitarbeiterZugang(
      authId: id,
      salt: 'salz',
      iterationen: 4096,
      storedKey: stored,
      serverKey: 'server',
    );

void main() {
  late Directory ordner;
  late Datenbank db;
  late DatenbankMitarbeiter quelle;

  setUp(() {
    ordner = Directory.systemTemp.createTempSync('planer-mitarbeiter-');
    db = Datenbank.oeffne(ordner.path, knoten: 'k');
    quelle = DatenbankMitarbeiter(db);
  });

  tearDown(() {
    db.schliesse();
    ordner.deleteSync(recursive: true);
  });

  test('übernimmt neue Zugänge und findet sie wieder', () {
    expect(quelle.uebernimm([_zugang('anna'), _zugang('bob')]), 2);
    final anna = quelle.finde('anna')!;
    expect(anna.alsJson(), _zugang('anna').alsJson());
    expect(quelle.finde('carla'), isNull);
    expect(quelle.datenbank, same(db));
  });

  test('gleiche Zugänge werden nicht erneut geschrieben', () {
    quelle.uebernimm([_zugang('anna')]);
    expect(quelle.uebernimm([_zugang('anna')]), 0);
    expect(db.letzteSequenz, 1);
  });

  test('geänderte Schlüssel aktualisieren den vorhandenen Benutzer', () {
    quelle.uebernimm([_zugang('anna')]);
    final uid = db.benutzer('anna')!.uid;
    expect(quelle.uebernimm([_zugang('anna', stored: 'neu')]), 1);
    expect(quelle.finde('anna')!.storedKey, 'neu');
    expect(db.benutzer('anna')!.uid, uid);
    expect(db.aenderungenSeit(1).single.art, 'aendern');
  });

  for (final feld in ['salt', 'iterationen', 'serverKey']) {
    test('Änderung an $feld wird erkannt', () {
      quelle.uebernimm([_zugang('anna')]);
      final z = _zugang('anna');
      final geaendert = MitarbeiterZugang(
        authId: 'anna',
        salt: feld == 'salt' ? 'anders' : z.salt,
        iterationen: feld == 'iterationen' ? 8192 : z.iterationen,
        storedKey: z.storedKey,
        serverKey: feld == 'serverKey' ? 'anders' : z.serverKey,
      );
      expect(quelle.uebernimm([geaendert]), 1);
      expect(quelle.finde('anna')!.alsJson(), geaendert.alsJson());
    });
  }
}
