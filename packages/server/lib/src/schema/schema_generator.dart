import 'dart:convert';

/// Erzeugt aus dem ObjectBox-Modell (`objectbox-model.json`) Dart-Code für
/// das domain-Paket: je Entität einen Bauer und eine Sicht im
/// ObjectBox-Speicherformat (#110). So sind Wire- und Speicher-Layout gleich
/// und ein Datensatz kann ohne Umkodieren vom Frontend bis in die Datenbank
/// laufen.
///
/// Feldplatz = Property-ID − 1, Tabellengröße = höchste ID + 1 (wie der
/// ObjectBox-Generator). Die lokale ObjectBox-ID wird nie geschrieben oder
/// gelesen – nach außen gilt nur die `uid` (docs/architektur/datenmodell.md).
abstract final class SchemaGenerator {
  /// Kopfzeile der erzeugten Datei; der Drift-Test erkennt daran den Ursprung.
  static const kopf =
      '// ERZEUGT von packages/server/bin/schema_erzeugen.dart aus '
      'objectbox-model.json – nicht von Hand ändern.';

  /// Erzeugt den Quelltext für die [entitaeten] (Name → nullbare Felder);
  /// unformatiert – `dart format` übernimmt danach das Layout.
  static String erzeuge(
    String modellJson,
    Map<String, Set<String>> entitaeten,
  ) {
    final modell = jsonDecode(modellJson) as Map<String, dynamic>;
    final alle = {
      for (final e in modell['entities'] as List<dynamic>)
        (e as Map<String, dynamic>)['name'] as String: e,
    };
    final quelle = StringBuffer()
      ..writeln(kopf)
      ..writeln()
      ..writeln("import 'dart:typed_data';")
      ..writeln()
      ..writeln("import 'package:flat_buffers/flat_buffers.dart' as fb;");
    for (final MapEntry(key: name, value: nullbar) in entitaeten.entries) {
      final entitaet = alle[name];
      if (entitaet == null) {
        throw ArgumentError.value(name, 'entitaeten', 'nicht im Modell');
      }
      quelle.write(
        _entitaet(name, _idPlatz(entitaet), _felder(entitaet, nullbar)),
      );
    }
    return quelle.toString();
  }

  /// Feldplatz der lokalen ObjectBox-ID: wird nur als Platzhalter 0 („neu“)
  /// geschrieben, damit ObjectBox beim Speichern die neue ID eintragen kann.
  static int _idPlatz(Map<String, dynamic> entitaet) => _platz(
    (entitaet['properties'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .firstWhere((p) => (p['flags'] as int? ?? 0) & _idFlag != 0),
  );

  static int _platz(Map<String, dynamic> property) =>
      int.parse((property['id'] as String).split(':').first) - 1;

  static List<_Feld> _felder(
    Map<String, dynamic> entitaet,
    Set<String> nullbar,
  ) {
    final felder = <_Feld>[];
    for (final p in entitaet['properties'] as List<dynamic>) {
      final property = p as Map<String, dynamic>;
      final flags = property['flags'] as int? ?? 0;
      if (flags & _idFlag != 0) continue;
      final name = property['name'] as String;
      felder.add(
        _Feld(
          name,
          _platz(property),
          _Typ.aus(property['type'] as int, name),
          nullbar: nullbar.contains(name),
        ),
      );
    }
    return felder;
  }

  static String _entitaet(String name, int idPlatz, List<_Feld> felder) {
    final tabelle = felder.map((f) => f.platz).reduce(_max) + 2;
    final q = StringBuffer()
      ..writeln()
      ..writeln('/// Baut einen $name-Datensatz im ObjectBox-Speicherformat.')
      ..writeln('Uint8List baue$name({');
    for (final f in felder) {
      q.writeln(
        f.nullbar
            ? '  ${f.typ.dart}? ${f.name},'
            : '  required ${f.typ.dart} ${f.name},',
      );
    }
    q
      ..writeln('}) {')
      ..writeln('  final fbb = fb.Builder(initialSize: 256);');
    for (final f in felder.where((f) => f.typ.istText)) {
      q.writeln(
        f.nullbar
            ? '  final ${f.name}Ort = ${f.name} == null ? null : '
                  'fbb.writeString(${f.name});'
            : '  final ${f.name}Ort = fbb.writeString(${f.name});',
      );
    }
    q
      ..writeln('  fbb.startTable($tabelle);')
      ..writeln('  fbb.addInt64($idPlatz, 0);');
    for (final f in felder) {
      q.writeln(
        f.typ.istText
            ? '  fbb.addOffset(${f.platz}, ${f.name}Ort);'
            : '  fbb.${f.typ.schreiber}(${f.platz}, ${f.name});',
      );
    }
    q
      ..writeln('  fbb.finish(fbb.endTable());')
      ..writeln('  return fbb.buffer;')
      ..writeln('}')
      ..writeln()
      ..writeln(
        '/// Sicht auf einen $name-Datensatz im ObjectBox-Speicherformat;',
      )
      ..writeln(
        '/// liest Felder erst beim Zugriff und ohne Kopie des Puffers.',
      )
      ..writeln('class ${name}Sicht {')
      ..writeln('  ${name}Sicht(Uint8List bytes)')
      ..writeln('    : _puffer = fb.BufferContext.fromBytes(bytes) {')
      ..writeln('    _wurzel = _puffer.derefObject(0);')
      ..writeln('  }')
      ..writeln()
      ..writeln("  static const schemaName = '$name';")
      ..writeln()
      ..writeln('  final fb.BufferContext _puffer;')
      ..writeln('  late final int _wurzel;');
    for (final f in felder) {
      final versatz = 4 + 2 * f.platz;
      q
        ..writeln()
        ..writeln(
          f.nullbar
              ? '  ${f.typ.dart}? get ${f.name} => const ${f.typ.leser}'
                    '.vTableGetNullable(_puffer, _wurzel, $versatz);'
              : '  ${f.typ.dart} get ${f.name} => const ${f.typ.leser}'
                    '.vTableGet(_puffer, _wurzel, $versatz, ${f.typ.vorgabe});',
        );
    }
    q.writeln('}');
    return q.toString();
  }

  static int _max(int a, int b) => a > b ? a : b;

  static const _idFlag = 1;
}

final class _Feld {
  _Feld(this.name, this.platz, this.typ, {required this.nullbar});

  final String name;
  final int platz;
  final _Typ typ;
  final bool nullbar;
}

/// ObjectBox-Property-Typen (`OBXPropertyType`) und ihre FlatBuffers-Abbildung.
enum _Typ {
  bool_(1, 'bool', 'addBool', 'fb.BoolReader()', 'false'),
  byte_(2, 'int', 'addInt8', 'fb.Int8Reader()', '0'),
  short_(3, 'int', 'addInt16', 'fb.Int16Reader()', '0'),
  int_(5, 'int', 'addInt32', 'fb.Int32Reader()', '0'),
  long_(6, 'int', 'addInt64', 'fb.Int64Reader()', '0'),
  float_(7, 'double', 'addFloat32', 'fb.Float32Reader()', '0.0'),
  double_(8, 'double', 'addFloat64', 'fb.Float64Reader()', '0.0'),
  string_(9, 'String', '', 'fb.StringReader(asciiOptimization: true)', "''"),
  date_(10, 'int', 'addInt64', 'fb.Int64Reader()', '0');

  const _Typ(this.code, this.dart, this.schreiber, this.leser, this.vorgabe);

  final int code;
  final String dart;
  final String schreiber;
  final String leser;
  final String vorgabe;

  bool get istText => this == _Typ.string_;

  static _Typ aus(int code, String feld) => _Typ.values.firstWhere(
    (t) => t.code == code,
    orElse: () => throw UnsupportedError(
      'ObjectBox-Typ $code (Feld $feld) wird vom Schema-Generator nicht '
      'unterstützt – Generator erweitern.',
    ),
  );
}
