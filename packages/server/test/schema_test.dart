import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:objectbox/internal.dart' show EntityDefinition;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/objectbox.g.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

/// Kleines Modell mit allen unterstützten ObjectBox-Typen.
String _modell(List<Map<String, Object>> properties) => jsonEncode({
  'entities': [
    {
      'name': 'Probe',
      'properties': [
        {'id': '1:1', 'name': 'id', 'type': 6, 'flags': 1},
        ...properties,
      ],
    },
  ],
});

Map<String, Object> _p(int id, String name, int typ) => {
  'id': '$id:$id',
  'name': name,
  'type': typ,
};

void main() {
  group('Schema-Generator', () {
    test(
      'eingecheckte Datei entspricht dem ObjectBox-Modell (Drift)',
      () async {
        final wurzel = Directory.current.parent.parent.path;
        final modell = File('$wurzel/$transportSchemaModell')
            .readAsStringSync();
        final ordner = Directory.systemTemp.createTempSync('schema-');
        addTearDown(() => ordner.deleteSync(recursive: true));
        final datei = File('${ordner.path}/transport.g.dart')
          ..writeAsStringSync(
            SchemaGenerator.erzeuge(modell, transportEntitaeten),
          );
        final format = await Process.run(Platform.resolvedExecutable, [
          'format',
          datei.path,
        ]);
        expect(format.exitCode, 0);
        expect(
          datei.readAsStringSync(),
          File('$wurzel/$transportSchemaZiel').readAsStringSync(),
          reason: 'dart run packages/server/bin/schema_erzeugen.dart ausführen',
        );
      },
    );

    test('bildet alle unterstützten Typen auf FlatBuffers ab', () {
      final quelle = SchemaGenerator.erzeuge(
        _modell([
          _p(2, 'aktiv', 1),
          _p(3, 'b', 2),
          _p(4, 's', 3),
          _p(5, 'i', 5),
          _p(6, 'l', 6),
          _p(7, 'f', 7),
          _p(8, 'd', 8),
          _p(9, 'text', 9),
          _p(10, 'datum', 10),
        ]),
        {
          'Probe': {'datum', 'text'},
        },
      );
      expect(quelle, startsWith(SchemaGenerator.kopf));
      for (final teil in [
        'required bool aktiv,',
        'fbb.addBool(1, aktiv);',
        'fbb.addInt8(2, b);',
        'fbb.addInt16(3, s);',
        'fbb.addInt32(4, i);',
        'fbb.addInt64(5, l);',
        'fbb.addFloat32(6, f);',
        'fbb.addFloat64(7, d);',
        'String? text,',
        'final textOrt = text == null ? null : fbb.writeString(text);',
        'fbb.addOffset(8, textOrt);',
        'int? datum,',
        'fbb.addInt64(9, datum);',
        'fbb.startTable(11);',
        "static const schemaName = 'Probe';",
        'bool get aktiv => const fb.BoolReader()'
            '.vTableGet(_puffer, _wurzel, 6, false);',
        'double get d => const fb.Float64Reader()'
            '.vTableGet(_puffer, _wurzel, 18, 0.0);',
        'String? get text => const fb.StringReader(asciiOptimization: true)'
            '.vTableGetNullable(_puffer, _wurzel, 20);',
        'int? get datum => const fb.Int64Reader()'
            '.vTableGetNullable(_puffer, _wurzel, 22);',
      ]) {
        expect(quelle, contains(teil));
      }
      // Die lokale ObjectBox-ID gelangt nie nach außen.
      expect(quelle, isNot(contains(' id')));
    });

    test('unbekannte Entität wird abgewiesen', () {
      expect(
        () => SchemaGenerator.erzeuge(_modell([]), {'Fehlt': {}}),
        throwsArgumentError,
      );
    });

    test('nicht unterstützter Typ verlangt eine Erweiterung', () {
      expect(
        () => SchemaGenerator.erzeuge(_modell([_p(2, 'bytes', 23)]), {
          'Probe': {},
        }),
        throwsA(
          isA<UnsupportedError>().having(
            (e) => e.message,
            'message',
            contains('ObjectBox-Typ 23 (Feld bytes) wird vom Schema-Generator'),
          ),
        ),
      );
    });

    test('vertrauliche Entitäten sind nicht für den Transport freigegeben', () {
      expect(transportEntitaeten.keys, isNot(contains('Benutzer')));
    });
  });

  group('gleiches Layout wie ObjectBox', () {
    late Directory ordner;
    late Store store;
    final binding =
        getObjectBoxModel().bindings[Aenderung]! as EntityDefinition<Aenderung>;

    setUp(() {
      ordner = Directory.systemTemp.createTempSync('schema-db-');
      store = openStore(directory: '${ordner.path}/daten');
    });

    tearDown(() {
      store.close();
      ordner.deleteSync(recursive: true);
    });

    test('ObjectBox liest Datensätze aus dem domain-Paket', () {
      final bytes = baueAenderung(
        schluessel: 'k:1',
        knoten: 'k',
        seq: 1,
        entitaet: 'Benutzer',
        uid: 'u-1',
        partition: 'global',
        hlc: 'h-1',
        art: 'anlegen',
      );
      final a = binding.objectFromFB(store, ByteData.sublistView(bytes));
      expect(a.id, 0, reason: 'neue Datensätze tragen keine lokale ID');
      expect(
        [a.schluessel, a.knoten, a.seq, a.entitaet, a.uid, a.partition, a.hlc],
        ['k:1', 'k', 1, 'Benutzer', 'u-1', 'global', 'h-1'],
      );
      expect(a.art, 'anlegen');
    });

    test('domain-Paket liest Datensätze aus ObjectBox', () {
      final fbb = fb.Builder();
      binding.objectToFB(
        Aenderung(
          knoten: 'k',
          seq: 2,
          entitaet: 'Benutzer',
          uid: 'u-2',
          partition: 'global',
          hlc: 'h-2',
          art: 'loeschen',
        )..id = 42,
        fbb,
      );
      final sicht = AenderungSicht(fbb.buffer);
      expect(
        [sicht.schluessel, sicht.knoten, sicht.seq, sicht.uid, sicht.art],
        ['k:2', 'k', 2, 'u-2', 'loeschen'],
      );
      expect(
        [sicht.entitaet, sicht.partition, sicht.hlc],
        ['Benutzer', 'global', 'h-2'],
      );
    });

    test('gespeicherter Datensatz kommt unverändert zurück', () {
      final box = store.box<Aenderung>();
      final bytes = baueAenderung(
        schluessel: 'k:3',
        knoten: 'k',
        seq: 3,
        entitaet: 'Benutzer',
        uid: 'u-3',
        partition: 'global',
        hlc: 'h-3',
        art: 'aendern',
      );
      final id = box.put(
        binding.objectFromFB(store, ByteData.sublistView(bytes)),
      );
      final fbb = fb.Builder();
      binding.objectToFB(box.get(id)!, fbb);
      expect(AenderungSicht(fbb.buffer).hlc, 'h-3');
    });
  });
}
