import 'package:flat_buffers/flat_buffers.dart' as fb;

import '../artikel/einheiten.dart';
import '../regeln/auflager.dart';

/// Was der Server zur Unterkonstruktion der bearbeiteten Fläche rechnet
/// und die App nur anzeigt (M6-08 bis M6-11) – als eigene Tabelle in der
/// Berechnung (Platz 110), damit die UK ihre Felder an einer Stelle hat.
///
/// Seit M6-08: Abstand der Auflager, ihre Höhenbereiche und Höhengrenzen
/// samt Meldungen.
final class Unterbau {
  Unterbau({
    this.auflagerabstand,
    List<Auflagerangabe> auflager = const [],
    this.hoeheVon,
    this.hoeheBis,
    List<Auflagermeldung> meldungen = const [],
  }) : auflager = List.unmodifiable(auflager),
       meldungen = List.unmodifiable(meldungen);

  /// Liest die Tabelle am Ort [ort] ([schreibe]).
  factory Unterbau.lies(fb.BufferContext puffer, int ort) {
    Millimeter? mm(int platz) => switch (const fb.Int32Reader()
        .vTableGetNullable(puffer, ort, _versatz(platz))) {
      final wert? => Millimeter(wert),
      null => null,
    };
    return Unterbau(
      auflagerabstand: mm(_abstandPlatz),
      auflager: [
        for (final z in const fb.ListReader<int>(
          _Tabellenort(),
        ).vTableGet(puffer, ort, _versatz(_auflagerPlatz), const []))
          (
            titel: const fb.StringReader().vTableGet(
              puffer,
              z,
              _versatz(0),
              '',
            ),
            von: Millimeter(
              const fb.Int32Reader().vTableGet(puffer, z, _versatz(1), 0),
            ),
            bis: Millimeter(
              const fb.Int32Reader().vTableGet(puffer, z, _versatz(2), 0),
            ),
            pad: const fb.BoolReader().vTableGet(puffer, z, _versatz(3), false),
          ),
      ],
      hoeheVon: mm(_hoeheVonPlatz),
      hoeheBis: mm(_hoeheBisPlatz),
      meldungen: [
        for (final n in const fb.ListReader<int>(
          fb.Uint8Reader(),
        ).vTableGet(puffer, ort, _versatz(_meldungenPlatz), const []))
          Auflagermeldung.ausNummer(n),
      ],
    );
  }

  /// Ohne Unterkonstruktion.
  static final leer = Unterbau();

  /// Höchster Abstand der Auflager längs der UK (`auflagerabstand`);
  /// `null` ohne UK.
  final Millimeter? auflagerabstand;

  /// Höhenbereiche der Auflager in Datenreihenfolge (`auflagerbereiche`):
  /// Pads, dann Stelzfüße; leer ohne Regelwerk oder bei Hochterrasse und
  /// vorhandener UK (dort Stützen bzw. Bodenanker).
  final List<Auflagerangabe> auflager;

  /// Niedrigste und höchste Höhe von Oberkante Belag bis Boden, die die
  /// [auflager] tragen (`auflagergrenzen`); `null` ohne sie.
  final Millimeter? hoeheVon;
  final Millimeter? hoeheBis;

  /// Meldungen zu den Höhengrenzen (`auflagermeldungen`).
  final List<Auflagermeldung> meldungen;

  /// Schreibt `{ 0: auflagerabstand (int32 mm; fehlt ohne UK),
  /// 1: auflager ([{ 0: titel (string), 1: von (int32 mm), 2: bis (int32
  /// mm), 3: pad (bool) }]), 2: hoeheVon, 3: hoeheBis (int32 mm; fehlen
  /// ohne Auflager), 4: meldungen ([uint8]) (M6-08) }`.
  int schreibe(fb.Builder fbb) {
    final auflagerOrt = fbb.writeList([
      for (final a in auflager) _auflager(fbb, a),
    ]);
    final meldungenOrt = fbb.writeListUint8([
      for (final m in meldungen) m.nummer,
    ]);
    fbb
      ..startTable(_meldungenPlatz + 1)
      ..addInt32(_abstandPlatz, auflagerabstand?.mm)
      ..addOffset(_auflagerPlatz, auflagerOrt)
      ..addInt32(_hoeheVonPlatz, hoeheVon?.mm)
      ..addInt32(_hoeheBisPlatz, hoeheBis?.mm)
      ..addOffset(_meldungenPlatz, meldungenOrt);
    return fbb.endTable();
  }

  static int _auflager(fb.Builder fbb, Auflagerangabe a) {
    final titelOrt = fbb.writeString(a.titel);
    fbb
      ..startTable(4)
      ..addOffset(0, titelOrt)
      ..addInt32(1, a.von.mm)
      ..addInt32(2, a.bis.mm)
      ..addBool(3, a.pad);
    return fbb.endTable();
  }

  static const _abstandPlatz = 0;
  static const _auflagerPlatz = 1;
  static const _hoeheVonPlatz = 2;
  static const _hoeheBisPlatz = 3;
  static const _meldungenPlatz = 4;

  static int _versatz(int platz) => 4 + 2 * platz;
}

/// Liest nur den Ort einer Tabelle – die Felder liest der Aufrufer.
final class _Tabellenort extends fb.TableReader<int> {
  const _Tabellenort();

  @override
  int createObject(fb.BufferContext puffer, int ort) => ort;
}
