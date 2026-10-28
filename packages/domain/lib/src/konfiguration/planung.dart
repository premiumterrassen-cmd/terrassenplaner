import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;

import 'planungsstand.dart';

/// Eine Fläche der Planung (M4-14): eigene Einstellungen in allen Schritten
/// und wie oft sie gebaut wird. Die Häufigkeit vervielfacht die Mengen dieser
/// Fläche („Häufigkeit der Fläche“, Fachkonzept 13).
final class Terrassenflaeche {
  Terrassenflaeche(this.stand, {this.haeufigkeit = 1}) {
    if (haeufigkeit < 1 || haeufigkeit > hoechsteHaeufigkeit) {
      throw ArgumentError.value(
        haeufigkeit,
        'haeufigkeit',
        'zwischen 1 und $hoechsteHaeufigkeit',
      );
    }
  }

  const Terrassenflaeche._(this.stand) : haeufigkeit = 1;

  static const start = Terrassenflaeche._(Planungsstand.start);

  /// Obergrenze der Häufigkeit (zweistelliges Eingabefeld).
  static const hoechsteHaeufigkeit = 99;

  final Planungsstand stand;
  final int haeufigkeit;

  @override
  bool operator ==(Object other) =>
      other is Terrassenflaeche &&
      other.stand == stand &&
      other.haeufigkeit == haeufigkeit;

  @override
  int get hashCode => Object.hash(stand, haeufigkeit);
}

/// Eine Konfiguration mit mehreren Flächen (M4-14, Reiter 1, 2 …) und der
/// Fläche, die gerade bearbeitet wird. Unveränderlich wie [Planungsstand],
/// damit Rückgängig auch Anlegen, Löschen und Wechseln umfasst.
final class Planung {
  Planung(List<Terrassenflaeche> flaechen, {this.aktiv = 0})
    : flaechen = List.unmodifiable(flaechen) {
    if (flaechen.isEmpty) {
      throw ArgumentError.value(flaechen, 'flaechen', 'mindestens eine Fläche');
    }
    RangeError.checkValidIndex(aktiv, flaechen, 'aktiv');
  }

  const Planung._(this.flaechen) : aktiv = 0;

  /// Liest eine Planung aus dem Transportformat ([zuBytes]).
  factory Planung.ausBytes(Uint8List bytes) {
    final puffer = fb.BufferContext.fromBytes(bytes);
    final wurzel = puffer.derefObject(0);
    return Planung(
      [
        ...const fb.ListReader<Terrassenflaeche>(
          _FlaechenLeser(),
        ).vTableGet(puffer, wurzel, _versatz(_flaechenPlatz), const []),
      ],
      aktiv: const fb.Uint16Reader().vTableGet(
        puffer,
        wurzel,
        _versatz(_aktivPlatz),
        0,
      ),
    );
  }

  /// Startkonfiguration: eine Fläche wie im alten Planer (F01).
  static const start = Planung._([Terrassenflaeche.start]);

  final List<Terrassenflaeche> flaechen;

  /// Index der bearbeiteten Fläche in [flaechen].
  final int aktiv;

  /// Planungsstand der bearbeiteten Fläche.
  Planungsstand get aktuell => flaechen[aktiv].stand;

  /// Häufigkeit der bearbeiteten Fläche.
  int get haeufigkeit => flaechen[aktiv].haeufigkeit;

  /// Ersetzt den Stand der bearbeiteten Fläche.
  Planung mitStand(Planungsstand stand) =>
      _mit(Terrassenflaeche(stand, haeufigkeit: haeufigkeit));

  Planung mitHaeufigkeit(int haeufigkeit) =>
      _mit(Terrassenflaeche(aktuell, haeufigkeit: haeufigkeit));

  /// „Fläche hinzufügen“: neue Fläche mit der Startkonfiguration, die gleich
  /// bearbeitet wird.
  Planung mitNeuerFlaeche() =>
      Planung([...flaechen, Terrassenflaeche.start], aktiv: flaechen.length);

  /// Wechselt zu Reiter [index].
  Planung gewaehlt(int index) => Planung(flaechen, aktiv: index);

  /// Löscht Fläche [index]; die letzte Fläche bleibt. Danach wird die Fläche
  /// davor bearbeitet, wenn die gelöschte die bearbeitete oder eine frühere
  /// war.
  Planung ohneFlaeche(int index) {
    RangeError.checkValidIndex(index, flaechen, 'index');
    if (flaechen.length == 1) {
      throw StateError('die letzte Fläche kann nicht gelöscht werden');
    }
    return Planung(
      [...flaechen]..removeAt(index),
      aktiv: index > aktiv || aktiv == 0 ? aktiv : aktiv - 1,
    );
  }

  Planung _mit(Terrassenflaeche flaeche) =>
      Planung([...flaechen]..[aktiv] = flaeche, aktiv: aktiv);

  /// `{ 0: schema (uint16), 1: flaechen ([{ 0: stand ([uint8], Planungsstand
  /// als eigener FlatBuffer), 1: haeufigkeit (uint16) }]), 2: aktiv (uint16) }`.
  /// Neue Felder nur anhängen (docs/architektur/datenmodell.md).
  Uint8List zuBytes() {
    final fbb = fb.Builder();
    final flaechenOrt = fbb.writeList([
      for (final f in flaechen) _flaeche(fbb, f),
    ]);
    fbb
      ..startTable(3)
      ..addUint16(_schemaPlatz, schema)
      ..addOffset(_flaechenPlatz, flaechenOrt)
      ..addUint16(_aktivPlatz, aktiv);
    fbb.finish(fbb.endTable());
    return fbb.buffer;
  }

  static int _flaeche(fb.Builder fbb, Terrassenflaeche f) {
    final standOrt = fbb.writeListUint8(f.stand.zuBytes());
    fbb
      ..startTable(2)
      ..addOffset(0, standOrt)
      ..addUint16(1, f.haeufigkeit);
    return fbb.endTable();
  }

  /// Version des Transportformats.
  static const schema = 1;

  static const _schemaPlatz = 0;
  static const _flaechenPlatz = 1;
  static const _aktivPlatz = 2;

  @override
  bool operator ==(Object other) {
    if (other is! Planung ||
        other.aktiv != aktiv ||
        other.flaechen.length != flaechen.length) {
      return false;
    }
    for (var i = 0; i < flaechen.length; i++) {
      if (other.flaechen[i] != flaechen[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(aktiv, Object.hashAll(flaechen));
}

/// vtable-Versatz eines Feldplatzes.
int _versatz(int platz) => 4 + 2 * platz;

final class _FlaechenLeser extends fb.TableReader<Terrassenflaeche> {
  const _FlaechenLeser();

  @override
  Terrassenflaeche createObject(fb.BufferContext puffer, int ort) {
    final stand = const fb.Uint8ListReader().vTableGetNullable(
      puffer,
      ort,
      _versatz(0),
    );
    if (stand == null) {
      throw const FormatException('Fläche ohne Planungsstand');
    }
    return Terrassenflaeche(
      Planungsstand.ausBytes(Uint8List.fromList(stand)),
      haeufigkeit: const fb.Uint16Reader().vTableGet(
        puffer,
        ort,
        _versatz(1),
        1,
      ),
    );
  }
}
