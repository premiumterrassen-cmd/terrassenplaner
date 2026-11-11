import 'package:flat_buffers/flat_buffers.dart' as fb;

import '../artikel/einheiten.dart';
import '../ergebnisse/stueckliste.dart';
import '../geometrie/punkt.dart';
import '../regeln/auflager.dart';
import '../regeln/auflagerbedarf.dart';
import '../regeln/uk_verlegung.dart';

/// Was der Server zur Unterkonstruktion der bearbeiteten Fläche rechnet
/// und die App nur anzeigt (M6-08 bis M6-11) – als eigene Tabelle in der
/// Berechnung (Platz 110), damit die UK ihre Felder an einer Stelle hat.
///
/// Seit M6-08: Abstand der Auflager, ihre Höhenbereiche und Höhengrenzen
/// samt Meldungen; seit M6-09 die wählbaren und die wirksame Feldbreite;
/// seit M6-10 die UK-Hölzer mit Farbe und Breite für die Zeichnung; seit
/// M6-11 die Auflager mit Spalt und die Tabelle der Höhenzuordnung.
final class Unterbau {
  Unterbau({
    this.auflagerabstand,
    List<Auflagerangabe> auflager = const [],
    this.hoeheVon,
    this.hoeheBis,
    List<Auflagermeldung> meldungen = const [],
    List<Millimeter> feldbreiten = const [],
    this.feldbreite,
    this.feldbreiteBegrenzt = false,
    List<UkHolz> hoelzer = const [],
    this.holzbreite,
    List<Auflagerpunkt> auflagerpunkte = const [],
    List<Auflagerzeile> zuordnung = const [],
    List<Millimeter> randErgaenzt = const [],
  }) : randErgaenzt = List.unmodifiable(randErgaenzt),
       auflagerpunkte = List.unmodifiable(auflagerpunkte),
       zuordnung = List.unmodifiable(zuordnung),
       hoelzer = List.unmodifiable(hoelzer),
       feldbreiten = List.unmodifiable(feldbreiten),
       auflager = List.unmodifiable(auflager),
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
      feldbreiten: [
        for (final mm in const fb.ListReader<int>(
          fb.Int32Reader(),
        ).vTableGet(puffer, ort, _versatz(_feldbreitenPlatz), const []))
          Millimeter(mm),
      ],
      feldbreite: mm(_feldbreitePlatz),
      feldbreiteBegrenzt: const fb.BoolReader().vTableGet(
        puffer,
        ort,
        _versatz(_begrenztPlatz),
        false,
      ),
      hoelzer: _hoelzer(puffer, ort),
      randErgaenzt: [
        for (final mm in const fb.ListReader<int>(
          fb.Int32Reader(),
        ).vTableGet(puffer, ort, _versatz(_randPlatz), const []))
          Millimeter(mm),
      ],
      holzbreite: mm(_holzbreitePlatz),
      auflagerpunkte: _auflagerpunkte(puffer, ort),
      zuordnung: [
        for (final z in const fb.ListReader<int>(
          _Tabellenort(),
        ).vTableGet(puffer, ort, _versatz(_zuordnungPlatz), const []))
          (
            titel: const fb.StringReader().vTableGet(
              puffer,
              z,
              _versatz(0),
              '',
            ),
            anzahl: const fb.Uint32Reader().vTableGet(
              puffer,
              z,
              _versatz(1),
              0,
            ),
            von: Millimeter(
              const fb.Int32Reader().vTableGet(puffer, z, _versatz(2), 0),
            ),
            bis: Millimeter(
              const fb.Int32Reader().vTableGet(puffer, z, _versatz(3), 0),
            ),
          ),
      ],
    );
  }

  static List<Auflagerpunkt> _auflagerpunkte(fb.BufferContext puffer, int ort) {
    final k = const fb.ListReader<double>(fb.Float64Reader())
        .vTableGet(puffer, ort, _versatz(_auflagerortePlatz), const []);
    final spalte = const fb.ListReader<int>(fb.Int32Reader())
        .vTableGet(puffer, ort, _versatz(_spaltePlatz), const []);
    final zeilen = const fb.ListReader<int>(fb.Int32Reader())
        .vTableGet(puffer, ort, _versatz(_zeilenPlatz), const []);
    // Zählschleife mit i++ (docs/erkenntnisse/mutation-tests.md)
    return [
      for (var i = 0; i < k.length ~/ 2; i++)
        (
          ort: Punkt(k[2 * i], k[2 * i + 1]),
          spalt: Millimeter(spalte[i]),
          zeile: zeilen[i] < 0 ? null : zeilen[i],
        ),
    ];
  }

  static List<UkHolz> _hoelzer(fb.BufferContext puffer, int ort) {
    final k = const fb.ListReader<double>(fb.Float64Reader())
        .vTableGet(puffer, ort, _versatz(_hoelzerPlatz), const []);
    final farben = const fb.ListReader<int>(fb.Uint8Reader())
        .vTableGet(puffer, ort, _versatz(_holzfarbenPlatz), const []);
    // Zählschleife mit i++: ein Mutant „i += 4 → i = 4“ liefe endlos
    // (docs/erkenntnisse/mutation-tests.md)
    return [
      for (var i = 0; i < k.length ~/ 4; i++)
        (
          von: Punkt(k[4 * i], k[4 * i + 1]),
          bis: Punkt(k[4 * i + 2], k[4 * i + 3]),
          farbe: Stueckfarbe.ausNummer(farben[i]),
        ),
    ];
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

  /// Wählbare Feldbreiten (`feldbreiten`, R-C01); leer ohne Belag aus Holz.
  final List<Millimeter> feldbreiten;

  /// Feldbreite, mit der gerechnet wird (`wirksameFeldbreite`); `null`
  /// ohne Belag aus Holz.
  final Millimeter? feldbreite;

  /// Ob die gewählte Feldbreite über der Firmenregel lag und begrenzt wurde.
  final bool feldbreiteBegrenzt;

  /// UK-Hölzer der Verlegung (M6-10) mit ihrer Farbe aus der Stückliste.
  final List<UkHolz> hoelzer;

  /// Breite der UK-Hölzer in der Draufsicht; `null` ohne Hölzer.
  final Millimeter? holzbreite;

  /// Auflager (M6-11) mit Ort, Spalt unter der UK und Zeile der
  /// [zuordnung] (`null`: kein passendes Auflager).
  final List<Auflagerpunkt> auflagerpunkte;

  /// Tabelle der Höhenzuordnung (M6-11): je Auflager-Art Anzahl und Spalte.
  final List<Auflagerzeile> zuordnung;

  /// Längen der Rand-UK, die die Selbstkontrolle ergänzt hat (Planungsregeln
  /// Alexander (Planungskern v6, 11.11.2026), Regel 3.4) – für die Hinweise.
  final List<Millimeter> randErgaenzt;

  /// Schreibt `{ 0: auflagerabstand (int32 mm; fehlt ohne UK),
  /// 1: auflager ([{ 0: titel (string), 1: von (int32 mm), 2: bis (int32
  /// mm), 3: pad (bool) }]), 2: hoeheVon, 3: hoeheBis (int32 mm; fehlen
  /// ohne Auflager), 4: meldungen ([uint8]) (M6-08), 5: feldbreiten ([int32]
  /// mm), 6: feldbreite (int32 mm; fehlt ohne Belag), 7: feldbreiteBegrenzt
  /// (bool) (M6-09), 8: hoelzer ([float64] x, y von und bis je Holz),
  /// 9: holzfarben ([uint8] je Holz), 10: holzbreite (int32 mm) (M6-10),
  /// 11: auflagerorte ([float64] x, y je Auflager), 12: spalte ([int32] mm),
  /// 13: zeilen ([int32]; −1 = kein Auflager), 14: zuordnung ([{ 0: titel
  /// (string), 1: anzahl (uint32), 2: von, 3: bis (int32 mm) }]) (M6-11),
  /// 15: randErgaenzt ([int32] mm, Planungsregeln 3.4) }`.
  int schreibe(fb.Builder fbb) {
    final auflagerOrt = fbb.writeList([
      for (final a in auflager) _auflager(fbb, a),
    ]);
    final meldungenOrt = fbb.writeListUint8([
      for (final m in meldungen) m.nummer,
    ]);
    final feldbreitenOrt = fbb.writeListInt32([
      for (final f in feldbreiten) f.mm,
    ]);
    final hoelzerOrt = fbb.writeListFloat64([
      for (final h in hoelzer) ...[h.von.x, h.von.y, h.bis.x, h.bis.y],
    ]);
    final farbenOrt = fbb.writeListUint8([
      for (final h in hoelzer) h.farbe.nummer,
    ]);
    final orteOrt = fbb.writeListFloat64([
      for (final p in auflagerpunkte) ...[p.ort.x, p.ort.y],
    ]);
    final spalteOrt = fbb.writeListInt32([
      for (final p in auflagerpunkte) p.spalt.mm,
    ]);
    final zeilenOrt = fbb.writeListInt32([
      for (final p in auflagerpunkte) p.zeile ?? -1,
    ]);
    final zuordnungOrt = fbb.writeList([
      for (final z in zuordnung) _zeile(fbb, z),
    ]);
    final randOrt = fbb.writeListInt32([for (final r in randErgaenzt) r.mm]);
    fbb
      ..startTable(_randPlatz + 1)
      ..addInt32(_abstandPlatz, auflagerabstand?.mm)
      ..addOffset(_auflagerPlatz, auflagerOrt)
      ..addInt32(_hoeheVonPlatz, hoeheVon?.mm)
      ..addInt32(_hoeheBisPlatz, hoeheBis?.mm)
      ..addOffset(_meldungenPlatz, meldungenOrt)
      ..addOffset(_feldbreitenPlatz, feldbreitenOrt)
      ..addInt32(_feldbreitePlatz, feldbreite?.mm)
      ..addBool(_begrenztPlatz, feldbreiteBegrenzt)
      ..addOffset(_hoelzerPlatz, hoelzerOrt)
      ..addOffset(_holzfarbenPlatz, farbenOrt)
      ..addInt32(_holzbreitePlatz, holzbreite?.mm)
      ..addOffset(_auflagerortePlatz, orteOrt)
      ..addOffset(_spaltePlatz, spalteOrt)
      ..addOffset(_zeilenPlatz, zeilenOrt)
      ..addOffset(_zuordnungPlatz, zuordnungOrt)
      ..addOffset(_randPlatz, randOrt);
    return fbb.endTable();
  }

  static int _zeile(fb.Builder fbb, Auflagerzeile z) {
    final titelOrt = fbb.writeString(z.titel);
    fbb
      ..startTable(4)
      ..addOffset(0, titelOrt)
      ..addUint32(1, z.anzahl)
      ..addInt32(2, z.von.mm)
      ..addInt32(3, z.bis.mm);
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
  static const _feldbreitenPlatz = 5;
  static const _feldbreitePlatz = 6;
  static const _begrenztPlatz = 7;
  static const _hoelzerPlatz = 8;
  static const _holzfarbenPlatz = 9;
  static const _holzbreitePlatz = 10;
  static const _auflagerortePlatz = 11;
  static const _spaltePlatz = 12;
  static const _zeilenPlatz = 13;
  static const _zuordnungPlatz = 14;
  static const _randPlatz = 15;

  static int _versatz(int platz) => 4 + 2 * platz;
}

/// Liest nur den Ort einer Tabelle – die Felder liest der Aufrufer.
final class _Tabellenort extends fb.TableReader<int> {
  const _Tabellenort();

  @override
  int createObject(fb.BufferContext puffer, int ort) => ort;
}
