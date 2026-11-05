import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;

import '../artikel/artikel.dart';
import '../artikel/einheiten.dart';
import '../ergebnisse/materialliste.dart';
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
  Planung(
    List<Terrassenflaeche> flaechen, {
    this.aktiv = 0,
    Map<Positionsschluessel, int> mengen = const {},
    this.verschnittvariante = 0,
  }) : flaechen = List.unmodifiable(flaechen),
       mengen = Map.unmodifiable(mengen) {
    if (flaechen.isEmpty) {
      throw ArgumentError.value(flaechen, 'flaechen', 'mindestens eine Fläche');
    }
    RangeError.checkValueInInterval(
      verschnittvariante,
      0,
      hoechsteVerschnittvariante,
      'verschnittvariante',
    );
    RangeError.checkValidIndex(aktiv, flaechen, 'aktiv');
    for (final anzahl in this.mengen.values) {
      if (anzahl < 0) {
        throw ArgumentError.value(anzahl, 'mengen', 'nicht negativ');
      }
    }
  }

  const Planung._(this.flaechen)
    : aktiv = 0,
      mengen = const {},
      verschnittvariante = 0;

  /// Liest eine Planung aus dem Transportformat ([zuBytes]).
  factory Planung.ausBytes(Uint8List bytes) {
    final puffer = fb.BufferContext.fromBytes(bytes);
    final wurzel = puffer.derefObject(0);
    return Planung(
      [
        ...const fb.ListReader<Terrassenflaeche>(_FlaechenLeser())
            .vTableGet(puffer, wurzel, _versatz(_flaechenPlatz), const []),
      ],
      aktiv: const fb.Uint16Reader().vTableGet(
        puffer,
        wurzel,
        _versatz(_aktivPlatz),
        0,
      ),
      mengen: {
        for (final ort in const fb.ListReader<int>(
          _Tabellenort(),
        ).vTableGet(puffer, wurzel, _versatz(_mengenPlatz), const []))
          _schluessel(puffer, ort): const fb.Uint32Reader().vTableGet(
            puffer,
            ort,
            _versatz(3),
            0,
          ),
      },
      verschnittvariante: const fb.Uint8Reader().vTableGet(
        puffer,
        wurzel,
        _versatz(_verschnittvariantePlatz),
        0,
      ),
    );
  }

  static Positionsschluessel _schluessel(fb.BufferContext puffer, int ort) => (
    nummer: Artikelnummer(
      const fb.StringReader().vTableGet(puffer, ort, _versatz(0), ''),
    ),
    laenge: switch (const fb.Int32Reader().vTableGetNullable(
      puffer,
      ort,
      _versatz(1),
    )) {
      final mm? => Millimeter(mm),
      null => null,
    },
    zusatz: Materialzusatz.ausNummer(
      const fb.Uint8Reader().vTableGet(puffer, ort, _versatz(2), 0),
    ),
  );

  /// Startkonfiguration: eine Fläche wie im alten Planer (F01).
  static const start = Planung._([Terrassenflaeche.start]);

  final List<Terrassenflaeche> flaechen;

  /// Index der bearbeiteten Fläche in [flaechen].
  final int aktiv;

  /// Planungsstand der bearbeiteten Fläche.
  Planungsstand get aktuell => flaechen[aktiv].stand;

  /// Geänderte Mengen der Mitarbeiter-Ansicht (M9-03, R-D04) je Position
  /// der Materialliste; sie gelten für die ganze Planung. Der Server
  /// übernimmt sie nur von Mitarbeitern (M9-10).
  final Map<Positionsschluessel, int> mengen;

  /// Gewählte Verschnittvariante (M9-01, Fachkonzept 7.1) ab 1; 0 = nicht
  /// optimiert – dann wird jede Teilfläche für sich zugeschnitten (M5-08).
  /// Sie gilt für die ganze Planung und bleibt bei Änderungen gewählt;
  /// gibt es weniger Varianten, gilt die letzte.
  final int verschnittvariante;

  /// Höchstens so viele Varianten bietet die Verschnittoptimierung an.
  static const hoechsteVerschnittvariante = 3;

  /// Häufigkeit der bearbeiteten Fläche.
  int get haeufigkeit => flaechen[aktiv].haeufigkeit;

  /// Ersetzt den Stand der bearbeiteten Fläche.
  Planung mitStand(Planungsstand stand) =>
      _mit(Terrassenflaeche(stand, haeufigkeit: haeufigkeit));

  Planung mitHaeufigkeit(int haeufigkeit) =>
      _mit(Terrassenflaeche(aktuell, haeufigkeit: haeufigkeit));

  /// „Fläche hinzufügen“: neue Fläche mit der Startkonfiguration, die gleich
  /// bearbeitet wird.
  Planung mitNeuerFlaeche() => Planung(
    [...flaechen, Terrassenflaeche.start],
    aktiv: flaechen.length,
    mengen: mengen,
    verschnittvariante: verschnittvariante,
  );

  /// Wechselt zu Reiter [index].
  Planung gewaehlt(int index) => Planung(
    flaechen,
    aktiv: index,
    mengen: mengen,
    verschnittvariante: verschnittvariante,
  );

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
      mengen: mengen,
      verschnittvariante: verschnittvariante,
    );
  }

  /// Setzt die Menge der Position [schluessel] (Mitarbeiter-Ansicht); mit
  /// `null` gilt wieder die berechnete.
  Planung mitMenge(Positionsschluessel schluessel, int? anzahl) => Planung(
    flaechen,
    aktiv: aktiv,
    mengen: {
      for (final MapEntry(:key, :value) in mengen.entries)
        if (key != schluessel) key: value,
      schluessel: ?anzahl,
    },
    verschnittvariante: verschnittvariante,
  );

  /// „Optimierung erstellen“ (1), Variante wählen (1–3) oder „zurücksetzen“
  /// (0) – M9-01.
  Planung mitVerschnittvariante(int variante) => Planung(
    flaechen,
    aktiv: aktiv,
    mengen: mengen,
    verschnittvariante: variante,
  );

  Planung _mit(Terrassenflaeche flaeche) => Planung(
    [...flaechen]..[aktiv] = flaeche,
    aktiv: aktiv,
    mengen: mengen,
    verschnittvariante: verschnittvariante,
  );

  /// `{ 0: schema (uint16), 1: flaechen ([{ 0: stand ([uint8], Planungsstand
  /// als eigener FlatBuffer), 1: haeufigkeit (uint16) }]), 2: aktiv (uint16),
  /// 70: mengen ([{ 0: nummer (string), 1: laenge (int32 mm, fehlt ohne
  /// Länge), 2: zusatz (uint8), 3: anzahl (uint32) }], M9-03),
  /// 160: verschnittvariante (uint8, fehlt = 0, M9-01) }`. Neue Felder
  /// nur anhängen (docs/architektur/datenmodell.md); die Plätze 70–79 sind
  /// für die Ergebnisse (M9) vorgesehen.
  Uint8List zuBytes() {
    final fbb = fb.Builder();
    final flaechenOrt = fbb.writeList([
      for (final f in flaechen) _flaeche(fbb, f),
    ]);
    final mengenOrt = mengen.isEmpty
        ? null
        : fbb.writeList([
            for (final MapEntry(:key, :value) in mengen.entries)
              _menge(fbb, key, value),
          ]);
    fbb
      ..startTable(_verschnittvariantePlatz + 1)
      ..addUint16(_schemaPlatz, schema)
      ..addOffset(_flaechenPlatz, flaechenOrt)
      ..addUint16(_aktivPlatz, aktiv)
      ..addOffset(_mengenPlatz, mengenOrt)
      ..addUint8(
        _verschnittvariantePlatz,
        verschnittvariante == 0 ? null : verschnittvariante,
      );
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

  static int _menge(fb.Builder fbb, Positionsschluessel s, int anzahl) {
    final nummerOrt = fbb.writeString(s.nummer.wert);
    fbb
      ..startTable(4)
      ..addOffset(0, nummerOrt)
      ..addInt32(1, s.laenge?.mm)
      ..addUint8(2, s.zusatz?.nummer)
      ..addUint32(3, anzahl);
    return fbb.endTable();
  }

  /// Version des Transportformats.
  static const schema = 1;

  static const _schemaPlatz = 0;
  static const _flaechenPlatz = 1;
  static const _aktivPlatz = 2;
  static const _mengenPlatz = 70;
  static const _verschnittvariantePlatz = 160;

  @override
  bool operator ==(Object other) {
    if (other is! Planung ||
        other.aktiv != aktiv ||
        other.verschnittvariante != verschnittvariante ||
        other.flaechen.length != flaechen.length ||
        other.mengen.length != mengen.length) {
      return false;
    }
    for (final MapEntry(:key, :value) in mengen.entries) {
      if (other.mengen[key] != value) return false;
    }
    for (var i = 0; i < flaechen.length; i++) {
      if (other.flaechen[i] != flaechen[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    aktiv,
    verschnittvariante,
    Object.hashAll(flaechen),
    Object.hashAllUnordered([
      for (final MapEntry(:key, :value) in mengen.entries) (key, value),
    ]),
  );
}

/// Liest nur den Ort einer Tabelle – die Felder liest der Aufrufer.
final class _Tabellenort extends fb.TableReader<int> {
  const _Tabellenort();

  @override
  int createObject(fb.BufferContext puffer, int ort) => ort;
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
