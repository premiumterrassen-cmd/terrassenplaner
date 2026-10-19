import 'dart:io';
import 'dart:typed_data';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/objectbox.g.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

Uint8List _aenderung(int seq, {String schluessel = ''}) => baueAenderung(
  schluessel: schluessel.isEmpty ? 'k:$seq' : schluessel,
  knoten: 'k',
  seq: seq,
  entitaet: 'Benutzer',
  uid: 'u-$seq',
  partition: 'global',
  hlc: 'h-$seq',
  art: 'anlegen',
);

void main() {
  late Directory ordner;
  late Store store;
  late RohSpeicher roh;
  late int aenderung;

  setUp(() {
    ordner = Directory.systemTemp.createTempSync('roh-speicher-');
    store = openStore(directory: '${ordner.path}/daten');
    roh = RohSpeicher(store);
    aenderung = RohSpeicher.entitaetId<Aenderung>(store);
  });

  tearDown(() {
    roh.schliesse();
    store.close();
    ordner.deleteSync(recursive: true);
  });

  test('Entitäts-ID kommt aus dem ObjectBox-Modell', () {
    expect(
      aenderung,
      getObjectBoxModel().model.findEntityByName('Aenderung')!.id.id,
    );
  });

  test('roh gespeicherte Datensätze sind normale ObjectBox-Objekte', () {
    final ids = roh.speichere(aenderung, [_aenderung(1), _aenderung(2)]);
    expect(ids, hasLength(2));
    expect(ids.every((id) => id > 0), isTrue);
    final box = store.box<Aenderung>();
    expect(box.count(), 2);
    final zweite = box.get(ids[1])!;
    expect([zweite.schluessel, zweite.seq, zweite.uid], ['k:2', 2, 'u-2']);
  });

  test('roh gelesen wird das ObjectBox-Speicherformat', () {
    final id = store.box<Aenderung>().put(
      Aenderung(
        knoten: 'k',
        seq: 5,
        entitaet: 'Benutzer',
        uid: 'u-5',
        partition: 'global',
        hlc: 'h-5',
        art: 'aendern',
      ),
    );
    final sicht = AenderungSicht(roh.lies(aenderung, id)!);
    expect([sicht.schluessel, sicht.seq, sicht.art], ['k:5', 5, 'aendern']);
  });

  test('unbekannte ID liefert null', () {
    expect(roh.lies(aenderung, 4711), isNull);
  });

  test('Fehler rollt die ganze Transaktion zurück', () {
    expect(
      () => roh.speichere(aenderung, [
        _aenderung(1),
        _aenderung(2, schluessel: 'k:1'),
      ]),
      throwsA(isA<ObjectBoxException>()),
    );
    expect(store.box<Aenderung>().count(), 0);
  });

  test('unbekannte Entität wird abgewiesen', () {
    expect(
      () => roh.speichere(9999, [_aenderung(1)]),
      throwsA(isA<ObjectBoxException>()),
    );
    expect(() => roh.lies(9999, 1), throwsA(isA<ObjectBoxException>()));
  });

  test('ungültige ID beim Lesen wird abgewiesen', () {
    expect(() => roh.lies(aenderung, 0), throwsA(isA<ObjectBoxException>()));
  });

  test('leerer Stapel speichert nichts', () {
    expect(roh.speichere(aenderung, const []), isEmpty);
  });

  test('Schließen gibt nur die eigene Referenz frei', () {
    final zweiter = RohSpeicher(store)..schliesse();
    expect(zweiter, isNotNull);
    expect(roh.speichere(aenderung, [_aenderung(9)]), hasLength(1));
  });

  test('Bibliothek: erst lib/ im Arbeitsverzeichnis, sonst Systempfad', () {
    expect(
      objectBoxBibliothek('/srv', 'libobjectbox.so', (_) => true),
      '/srv/lib/libobjectbox.so',
    );
    expect(
      objectBoxBibliothek('/srv', 'libobjectbox.so', (_) => false),
      'libobjectbox.so',
    );
  });
}
