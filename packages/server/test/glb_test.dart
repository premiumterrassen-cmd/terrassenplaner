import 'dart:convert';
import 'dart:typed_data';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

/// Gelesenes GLB: JSON-Teil und Binärblock.
typedef _Glb = ({Map<String, Object?> json, ByteData bin, ByteData kopf});

_Glb _lies(Uint8List glb) {
  final kopf = ByteData.sublistView(glb);
  final jsonLaenge = kopf.getUint32(12, Endian.little);
  final json = jsonDecode(
    utf8.decode(glb.sublist(20, 20 + jsonLaenge)),
  ) as Map<String, Object?>;
  final bin = 20 + jsonLaenge;
  final binLaenge = kopf.getUint32(bin, Endian.little);
  return (
    json: json,
    bin: ByteData.sublistView(glb, bin + 8, bin + 8 + binLaenge),
    kopf: kopf,
  );
}

List<Map<String, Object?>> _liste(Object? wert) =>
    (wert! as List).cast<Map<String, Object?>>();

/// Werte eines Zugriffs als Liste (Float oder Uint32).
List<num> _werte(_Glb glb, int zugriff) {
  final a = _liste(glb.json['accessors'])[zugriff];
  final v = _liste(glb.json['bufferViews'])[a['bufferView']! as int];
  final start = v['byteOffset']! as int;
  final komponenten = a['type'] == 'VEC3' ? 3 : 1;
  final anzahl = (a['count']! as int) * komponenten;
  expect(v['byteLength'], anzahl * 4);
  return [
    for (var i = 0; i < anzahl; i++)
      a['componentType'] == 5126
          ? glb.bin.getFloat32(start + i * 4, Endian.little)
          : glb.bin.getUint32(start + i * 4, Endian.little),
  ];
}

Quader _quader(int x, int y, int z, int l, int h, int b) => Quader(
  x: Millimeter(x),
  y: Millimeter(y),
  z: Millimeter(z),
  laenge: Millimeter(l),
  hoehe: Millimeter(h),
  breite: Millimeter(b),
);

void main() {
  final teile = [
    Bauteil(Bauteilart.unterkonstruktion, _quader(0, 0, 0, 70, 45, 1000)),
    Bauteil(Bauteilart.diele, _quader(0, 45, 0, 2000, 23, 120)),
    Bauteil(Bauteilart.diele, _quader(0, 45, 125, 2000, 23, 120)),
  ];

  test('GLB-Kopf und Blöcke nach glTF 2.0', () {
    final glb = glbAus(teile);
    final g = _lies(glb);
    expect(g.kopf.getUint32(0, Endian.little), 0x46546C67);
    expect(g.kopf.getUint32(4, Endian.little), 2);
    expect(g.kopf.getUint32(8, Endian.little), glb.length);
    expect(g.kopf.getUint32(16, Endian.little), 0x4E4F534A);
    final jsonLaenge = g.kopf.getUint32(12, Endian.little);
    expect(jsonLaenge % 4, 0);
    expect(glb[20 + jsonLaenge - 1], anyOf(0x20, 0x7D));
    expect(g.kopf.getUint32(20 + jsonLaenge + 4, Endian.little), 0x004E4942);
    expect(g.bin.lengthInBytes % 4, 0);
    expect(glb.length % 4, 0);
    expect(
      _liste(g.json['buffers']).single['byteLength'],
      lessThanOrEqualTo(g.bin.lengthInBytes),
    );
    expect(g.json['asset'], {'version': '2.0', 'generator': glbGenerator});
    expect(glbGenerator, 'Terrassenplaner ALTO HOLZ');
    expect(g.json['scene'], 0);
    expect(g.json['scenes'], [
      {
        'nodes': [0],
      },
    ]);
    expect(g.json['nodes'], [
      {'name': 'Terrasse', 'mesh': 0},
    ]);
  });

  test('je Bauteilart ein Primitiv mit Material', () {
    final g = _lies(glbAus(teile));
    final mesh = _liste(g.json['meshes']).single;
    expect(mesh['name'], 'Terrasse');
    final primitive = _liste(mesh['primitives']);
    expect(primitive, [
      {
        'attributes': {'POSITION': 0, 'NORMAL': 1},
        'indices': 2,
        'material': 0,
      },
      {
        'attributes': {'POSITION': 3, 'NORMAL': 4},
        'indices': 5,
        'material': 1,
      },
    ]);
    expect(_liste(g.json['materials']), [
      {
        'name': 'Diele Robinie',
        'pbrMetallicRoughness': {
          'baseColorFactor': [0.55, 0.36, 0.18, 1.0],
          'metallicFactor': 0.0,
          'roughnessFactor': 0.8,
        },
      },
      {
        'name': 'Unterkonstruktion',
        'pbrMetallicRoughness': {
          'baseColorFactor': [0.3, 0.2, 0.1, 1.0],
          'metallicFactor': 0.0,
          'roughnessFactor': 0.8,
        },
      },
    ]);
    final zugriffe = _liste(g.json['accessors']);
    expect([for (final a in zugriffe) a['count']], [48, 48, 72, 24, 24, 36]);
    expect(
      [for (final a in zugriffe) a['type']],
      ['VEC3', 'VEC3', 'SCALAR', 'VEC3', 'VEC3', 'SCALAR'],
    );
    expect(
      [for (final a in zugriffe) a['componentType']],
      [5126, 5126, 5125, 5126, 5126, 5125],
    );
    expect(
      [for (final v in _liste(g.json['bufferViews'])) v['target']],
      [34962, 34962, 34963, 34962, 34962, 34963],
    );
    var ende = 0;
    for (final v in _liste(g.json['bufferViews'])) {
      expect(v['buffer'], 0);
      expect(v['byteOffset'], ende, reason: 'lückenlos hintereinander');
      ende += v['byteLength']! as int;
    }
    expect(_liste(g.json['buffers']).single['byteLength'], ende);
  });

  test('Positionen in Metern mit Grenzen', () {
    final g = _lies(glbAus(teile));
    final dielen = _liste(g.json['accessors'])[0];
    expect(dielen['min'], [0.0, closeTo(0.045, 1e-6), 0.0]);
    expect(dielen['max'], [2.0, closeTo(0.068, 1e-6), closeTo(0.245, 1e-6)]);
    final uk = _liste(g.json['accessors'])[3];
    expect(uk['min'], [0.0, 0.0, 0.0]);
    expect(uk['max'], [closeTo(0.07, 1e-6), closeTo(0.045, 1e-6), 1.0]);
    final positionen = _werte(g, 0);
    for (var achse = 0; achse < 3; achse++) {
      final werte = [
        for (var i = achse; i < positionen.length; i += 3) positionen[i],
      ];
      expect(
        werte.reduce((a, b) => a < b ? a : b),
        closeTo((dielen['min']! as List)[achse] as num, 1e-6),
      );
      expect(
        werte.reduce((a, b) => a > b ? a : b),
        closeTo((dielen['max']! as List)[achse] as num, 1e-6),
      );
    }
  });

  test('Dreiecke zeigen nach außen, Normalen passen', () {
    final g = _lies(glbAus(teile));
    for (final erster in [0, 3]) {
      final p = _werte(g, erster);
      final n = _werte(g, erster + 1);
      final idx = _werte(g, erster + 2).cast<int>();
      expect(idx.every((i) => i < p.length ~/ 3), isTrue);
      for (var t = 0; t < idx.length; t += 3) {
        List<double> ecke(int i) => [
          for (var a = 0; a < 3; a++) p[idx[t + i] * 3 + a].toDouble(),
        ];
        final (a, b, c) = (ecke(0), ecke(1), ecke(2));
        final u = [for (var k = 0; k < 3; k++) b[k] - a[k]];
        final v = [for (var k = 0; k < 3; k++) c[k] - a[k]];
        final kreuz = [
          u[1] * v[2] - u[2] * v[1],
          u[2] * v[0] - u[0] * v[2],
          u[0] * v[1] - u[1] * v[0],
        ];
        final normale = [for (var k = 0; k < 3; k++) n[idx[t] * 3 + k]];
        final skalar = [for (var k = 0; k < 3; k++) kreuz[k] * normale[k]]
            .reduce((x, y) => x + y);
        expect(skalar, greaterThan(0), reason: 'Dreieck ${t ~/ 3}');
        for (var i = 0; i < 3; i++) {
          expect(
            [for (var k = 0; k < 3; k++) n[idx[t + i] * 3 + k]],
            normale,
            reason: 'eine Normale je Seite',
          );
        }
      }
    }
  });

  test('nur vorhandene Bauteilarten, leeres Modell ist ein Fehler', () {
    final g = _lies(glbAus([teile.first]));
    expect(_liste(g.json['materials']).single['name'], 'Unterkonstruktion');
    expect(
      () => glbAus(const []),
      throwsA(
        isA<ArgumentError>()
            .having((e) => e.name, 'name', 'teile')
            .having((e) => e.message, 'message', 'keine Bauteile'),
      ),
    );
  });

  test('Farben je Bauteilart', () {
    expect(bauteilFarben.keys, Bauteilart.values);
  });

  test('jede Seite liegt außen am Quader, auf den ihre Normale zeigt', () {
    final g = _lies(glbAus(teile));
    for (final erster in [0, 3]) {
      final p = _werte(g, erster);
      final n = _werte(g, erster + 1);
      for (var quader = 0; quader < p.length ~/ 72; quader++) {
        double wert(int ecke, int achse) =>
            p[(quader * 24 + ecke) * 3 + achse].toDouble();
        for (var seite = 0; seite < 6; seite++) {
          final normale = [
            for (var k = 0; k < 3; k++) n[(quader * 24 + seite * 4) * 3 + k],
          ];
          final achse = normale.indexWhere((v) => v != 0);
          final alle = [for (var e = 0; e < 24; e++) wert(e, achse)];
          final aussen = normale[achse] > 0
              ? alle.reduce((a, b) => a > b ? a : b)
              : alle.reduce((a, b) => a < b ? a : b);
          for (var e = seite * 4; e < seite * 4 + 4; e++) {
            expect(
              wert(e, achse),
              aussen,
              reason: 'Quader $quader Seite $seite',
            );
          }
        }
      }
    }
  });
}
