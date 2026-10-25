import 'dart:convert';
import 'dart:typed_data';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Farbe (linear RGB) und Name je Bauteilart im 3D-Modell.
const bauteilFarben = {
  Bauteilart.diele: (name: 'Diele Robinie', rgb: [0.55, 0.36, 0.18]),
  Bauteilart.unterkonstruktion: (
    name: 'Unterkonstruktion',
    rgb: [0.3, 0.2, 0.1],
  ),
};

/// Erzeugt aus den Bauteilen ein glTF-2.0-Binärmodell (GLB, M3-10) – eine
/// Datei für Anzeige im Browser, Download und später AR (M12). Einheit
/// Meter, y nach oben; je Bauteilart ein Material.
Uint8List glbAus(List<Bauteil> teile) {
  final daten = BytesBuilder(copy: false);
  final ansichten = <Map<String, Object?>>[];
  final zugriffe = <Map<String, Object?>>[];
  final materialien = <Map<String, Object?>>[];
  final primitive = <Map<String, Object?>>[];

  int ansicht(Uint8List bytes, int ziel) {
    ansichten.add({
      'buffer': 0,
      'byteOffset': daten.length,
      'byteLength': bytes.length,
      'target': ziel,
    });
    daten.add(bytes);
    return ansichten.length - 1;
  }

  for (final art in Bauteilart.values) {
    final quader = [
      for (final t in teile)
        if (t.art == art) t.quader,
    ];
    if (quader.isEmpty) continue;
    final netz = _Netz.aus(quader);
    zugriffe
      ..add({
        'bufferView': ansicht(netz.positionen.buffer.asUint8List(), _vertices),
        'componentType': _float,
        'count': netz.positionen.length ~/ 3,
        'type': 'VEC3',
        'min': netz.min,
        'max': netz.max,
      })
      ..add({
        'bufferView': ansicht(netz.normalen.buffer.asUint8List(), _vertices),
        'componentType': _float,
        'count': netz.normalen.length ~/ 3,
        'type': 'VEC3',
      })
      ..add({
        'bufferView': ansicht(netz.indizes.buffer.asUint8List(), _indizes),
        'componentType': _uint32,
        'count': netz.indizes.length,
        'type': 'SCALAR',
      });
    final farbe = bauteilFarben[art]!;
    materialien.add({
      'name': farbe.name,
      'pbrMetallicRoughness': {
        'baseColorFactor': [...farbe.rgb, 1.0],
        'metallicFactor': 0.0,
        'roughnessFactor': 0.8,
      },
    });
    final erster = zugriffe.length - 3;
    primitive.add({
      'attributes': {'POSITION': erster, 'NORMAL': erster + 1},
      'indices': erster + 2,
      'material': materialien.length - 1,
    });
  }
  if (primitive.isEmpty) {
    throw ArgumentError.value(teile.length, 'teile', 'keine Bauteile');
  }

  final binaer = daten.takeBytes();
  final json = utf8.encode(
    jsonEncode({
      'asset': {'version': '2.0', 'generator': glbGenerator},
      'scene': 0,
      'scenes': [
        {
          'nodes': [0],
        },
      ],
      'nodes': [
        {'name': 'Terrasse', 'mesh': 0},
      ],
      'meshes': [
        {'name': 'Terrasse', 'primitives': primitive},
      ],
      'materials': materialien,
      'accessors': zugriffe,
      'bufferViews': ansichten,
      'buffers': [
        {'byteLength': binaer.length},
      ],
    }),
  );
  return _glb(json, binaer);
}

/// Kennung im glTF-Feld `asset.generator`.
const glbGenerator = 'Terrassenplaner ALTO HOLZ';

const _float = 5126;
const _uint32 = 5125;
const _vertices = 34962;
const _indizes = 34963;

/// GLB-Container: Kopf, JSON-Block (mit Leerzeichen auf 4 Byte aufgefüllt),
/// Binärblock (mit Nullen aufgefüllt).
Uint8List _glb(List<int> json, Uint8List binaer) {
  final jsonLaenge = _auf4(json.length);
  final binLaenge = _auf4(binaer.length);
  final gesamt = 12 + 8 + jsonLaenge + 8 + binLaenge;
  final aus = Uint8List(gesamt);
  final kopf = ByteData.sublistView(aus);
  kopf
    ..setUint32(0, 0x46546C67, Endian.little) // „glTF“
    ..setUint32(4, 2, Endian.little)
    ..setUint32(8, gesamt, Endian.little)
    ..setUint32(12, jsonLaenge, Endian.little)
    ..setUint32(16, 0x4E4F534A, Endian.little); // „JSON“
  aus
    ..setRange(20, 20 + json.length, json)
    ..fillRange(20 + json.length, 20 + jsonLaenge, 0x20);
  final bin = 20 + jsonLaenge;
  kopf
    ..setUint32(bin, binLaenge, Endian.little)
    ..setUint32(bin + 4, 0x004E4942, Endian.little); // „BIN“
  aus.setRange(bin + 8, bin + 8 + binaer.length, binaer);
  return aus;
}

int _auf4(int n) => (n + 3) & ~3;

/// Dreiecksnetz aus Quadern: je Seite vier Ecken mit eigener Normale.
final class _Netz {
  _Netz(this.positionen, this.normalen, this.indizes);

  factory _Netz.aus(List<Quader> quader) {
    final positionen = Float32List(quader.length * 24 * 3);
    final normalen = Float32List(quader.length * 24 * 3);
    final indizes = Uint32List(quader.length * 36);
    var ecke = 0;
    var index = 0;
    for (final q in quader) {
      final von = [q.x.m, q.y.m, q.z.m];
      final bis = [(q.x + q.laenge).m, (q.y + q.hoehe).m, (q.z + q.breite).m];
      for (final (normale, ecken) in _seiten) {
        final erste = ecke;
        for (final e in ecken) {
          for (var achse = 0; achse < 3; achse++) {
            positionen[ecke * 3 + achse] = e[achse] == 0
                ? von[achse]
                : bis[achse];
            normalen[ecke * 3 + achse] = normale[achse];
          }
          ecke++;
        }
        for (final i in const [0, 1, 2, 0, 2, 3]) {
          indizes[index++] = erste + i;
        }
      }
    }
    return _Netz(positionen, normalen, indizes);
  }

  final Float32List positionen;
  final Float32List normalen;
  final Uint32List indizes;

  List<double> get min => _grenze((a, b) => a < b ? a : b);
  List<double> get max => _grenze((a, b) => a > b ? a : b);

  List<double> _grenze(double Function(double, double) waehle) => [
    for (var achse = 0; achse < 3; achse++)
      [for (var i = achse; i < positionen.length; i += 3) positionen[i]]
          .reduce(waehle),
  ];
}

/// Die sechs Seiten eines Quaders: Normale und Ecken (0 = von, 1 = bis je
/// Achse) gegen den Uhrzeigersinn von außen gesehen.
const _seiten = <(List<double>, List<List<int>>)>[
  (
    [1, 0, 0],
    [
      [1, 0, 0],
      [1, 1, 0],
      [1, 1, 1],
      [1, 0, 1],
    ],
  ),
  (
    [-1, 0, 0],
    [
      [0, 0, 0],
      [0, 0, 1],
      [0, 1, 1],
      [0, 1, 0],
    ],
  ),
  (
    [0, 1, 0],
    [
      [0, 1, 0],
      [0, 1, 1],
      [1, 1, 1],
      [1, 1, 0],
    ],
  ),
  (
    [0, -1, 0],
    [
      [0, 0, 0],
      [1, 0, 0],
      [1, 0, 1],
      [0, 0, 1],
    ],
  ),
  (
    [0, 0, 1],
    [
      [0, 0, 1],
      [1, 0, 1],
      [1, 1, 1],
      [0, 1, 1],
    ],
  ),
  (
    [0, 0, -1],
    [
      [0, 0, 0],
      [0, 1, 0],
      [1, 1, 0],
      [1, 0, 0],
    ],
  ),
];
