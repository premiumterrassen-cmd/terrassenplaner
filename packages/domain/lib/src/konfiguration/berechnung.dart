import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;

import '../artikel/artikel.dart';
import '../artikel/einheiten.dart';
import '../ergebnisse/materialliste.dart';
import '../ergebnisse/stueckliste.dart';
import '../geometrie/punkt.dart';
import '../regeln/befestigungsbedarf.dart';
import '../regeln/belagmeldungen.dart';
import '../regeln/hoehenpunkte.dart';
import '../regeln/uk_zusatz.dart';
import 'befestigungsart.dart';
import 'unterbau.dart';

/// Was der Server aus einem Planungsstand berechnet und die App nur anzeigt
/// (M4-02): Umriss, Ausschnitte (M4-06) und Dielenstücke (M5-05) für die
/// Zeichnung und Kennzahlen, seit M5-07 Ausgangspunkt, Verschiebungsgrenzen
/// und Warnung vor kurzen Zuschnitten, seit M5-09 die Befestigung, seit
/// M5-08 Dielennummern, Dielenliste und Verschnitt der ganzen Planung,
/// seit M5-10 die Meldungen zum Belag, seit M6-02 die geprüften
/// Höhenpunkte, seit M9-03 die Materialliste der ganzen Planung, seit M9-04
/// Stückliste und Farbe je Dielenstück, seit M6-08 die Unterkonstruktion
/// ([unterbau]). Das Volumen folgt mit M6.
final class Berechnung {
  Berechnung({
    required List<Punkt> umriss,
    required this.flaeche,
    List<List<Punkt>> ausschnitte = const [],
    List<Punkt>? ecken,
    this.geschlossen = true,
    double? gesamtflaeche,
    List<List<Punkt>> dielen = const [],
    this.ausgangspunkt,
    this.grenzeLinksRechts = const Millimeter(0),
    this.grenzeObenUnten = const Millimeter(0),
    this.kurzeZuschnitte = false,
    List<int> nummern = const [],
    this.verschnitt,
    List<Lieferposition> dielenliste = const [],
    Befestigungsbedarf? befestigung,
    List<Belagmeldung> belagmeldungen = const [],
    Hoehenpunkte? hoehenpunkte,
    Materialliste? materialliste,
    Stueckliste? stueckliste,
    List<Stueckfarbe> stueckfarben = const [],
    List<Strebe> querstreben = const [],
    this.querstrebenReihen,
    List<Stellfuss> stellfuesse = const [],
    Unterbau? unterbau,
  }) : unterbau = unterbau ?? Unterbau.leer,
       querstreben = List.unmodifiable(querstreben),
       stellfuesse = List.unmodifiable(stellfuesse),
       materialliste = materialliste ?? Materialliste.leer,
       stueckliste = stueckliste ?? Stueckliste.leer,
       stueckfarben = List.unmodifiable(stueckfarben),
       belagmeldungen = List.unmodifiable(belagmeldungen),
       befestigung = befestigung ?? Befestigungsbedarf.keiner,
       hoehenpunkte = hoehenpunkte ?? Hoehenpunkte.keine,
       nummern = List.unmodifiable(nummern),
       dielenliste = List.unmodifiable(dielenliste),
       gesamtflaeche = gesamtflaeche ?? flaeche,
       dielen = List.unmodifiable([
         for (final d in dielen) List<Punkt>.unmodifiable(d),
       ]),
       umriss = List.unmodifiable(umriss),
       ecken = List.unmodifiable(ecken ?? umriss),
       ausschnitte = List.unmodifiable([
         for (final a in ausschnitte) List<Punkt>.unmodifiable(a),
       ]);

  /// Liest eine Berechnung aus dem Transportformat ([zuBytes]).
  factory Berechnung.ausBytes(Uint8List bytes) {
    final puffer = fb.BufferContext.fromBytes(bytes);
    final wurzel = puffer.derefObject(0);
    return Berechnung(
      umriss: _punkte(puffer, wurzel, _umrissPlatz),
      ecken: _punkte(puffer, wurzel, _eckenPlatz),
      geschlossen: const fb.BoolReader().vTableGet(
        puffer,
        wurzel,
        _versatz(_geschlossenPlatz),
        true,
      ),
      ausschnitte: _umrisse(puffer, wurzel, _ausschnittePlatz),
      flaeche: const fb.Float64Reader().vTableGet(
        puffer,
        wurzel,
        _versatz(_flaechePlatz),
        0,
      ),
      gesamtflaeche: const fb.Float64Reader().vTableGetNullable(
        puffer,
        wurzel,
        _versatz(_gesamtflaechePlatz),
      ),
      dielen: _umrisse(puffer, wurzel, _dielenPlatz),
      ausgangspunkt: switch (_punkte(puffer, wurzel, _ausgangspunktPlatz)) {
        [final p] => p,
        _ => null,
      },
      grenzeLinksRechts: _mm(puffer, wurzel, _grenzeLinksRechtsPlatz),
      grenzeObenUnten: _mm(puffer, wurzel, _grenzeObenUntenPlatz),
      kurzeZuschnitte: const fb.BoolReader().vTableGet(
        puffer,
        wurzel,
        _versatz(_kurzeZuschnittePlatz),
        false,
      ),
      nummern: const fb.ListReader<int>(fb.Int32Reader())
          .vTableGet(puffer, wurzel, _versatz(_nummernPlatz), const []),
      verschnitt: const fb.Float64Reader().vTableGetNullable(
        puffer,
        wurzel,
        _versatz(_verschnittPlatz),
      ),
      dielenliste: [
        for (final ort in const fb.ListReader<int>(
          _Tabellenort(),
        ).vTableGet(puffer, wurzel, _versatz(_dielenlistePlatz), const []))
          (
            belag: Artikelnummer(
              const fb.StringReader().vTableGet(puffer, ort, _versatz(0), ''),
            ),
            laenge: _mm(puffer, ort, 1),
            anzahl: const fb.Int32Reader().vTableGet(
              puffer,
              ort,
              _versatz(2),
              0,
            ),
          ),
      ],
      befestigung: _befestigung(puffer, wurzel),
      belagmeldungen: [
        for (final n in const fb.ListReader<int>(
          fb.Uint8Reader(),
        ).vTableGet(puffer, wurzel, _versatz(_belagmeldungenPlatz), const []))
          Belagmeldung.ausNummer(n),
      ],
      materialliste: switch (const _Tabellenort().vTableGetNullable(
        puffer,
        wurzel,
        _versatz(_materiallistePlatz),
      )) {
        final ort? => Materialliste.lies(puffer, ort),
        null => null,
      },
      stueckliste: switch (const _Tabellenort().vTableGetNullable(
        puffer,
        wurzel,
        _versatz(_stuecklistePlatz),
      )) {
        final ort? => Stueckliste.lies(puffer, ort),
        null => null,
      },
      stueckfarben: [
        for (final n in const fb.ListReader<int>(
          fb.Uint8Reader(),
        ).vTableGet(puffer, wurzel, _versatz(_stueckfarbenPlatz), const []))
          Stueckfarbe.ausNummer(n),
      ],
      hoehenpunkte: _hoehenpunkte(puffer, wurzel),
      querstreben: [
        for (final [von, bis] in _paare(
          _punkte(puffer, wurzel, _querstrebenPlatz),
        ))
          (von: von, bis: bis),
      ],
      querstrebenReihen: const fb.Uint16Reader().vTableGetNullable(
        puffer,
        wurzel,
        _versatz(_querstrebenReihenPlatz),
      ),
      stellfuesse: [
        for (final ort in const fb.ListReader<int>(
          _Tabellenort(),
        ).vTableGet(puffer, wurzel, _versatz(_stellfuessePlatz), const []))
          (
            nummer: Artikelnummer(
              const fb.StringReader().vTableGet(puffer, ort, _versatz(0), ''),
            ),
            titel: const fb.StringReader().vTableGet(
              puffer,
              ort,
              _versatz(1),
              '',
            ),
          ),
      ],
      unterbau: switch (const _Tabellenort().vTableGetNullable(
        puffer,
        wurzel,
        _versatz(_unterbauPlatz),
      )) {
        final ort? => Unterbau.lies(puffer, ort),
        null => null,
      },
    );
  }

  /// [punkte] je zwei zusammen.
  static Iterable<List<Punkt>> _paare(List<Punkt> punkte) sync* {
    for (var i = 1; i < punkte.length; i += 2) {
      yield [punkte[i - 1], punkte[i]];
    }
  }

  static Hoehenpunkte _hoehenpunkte(fb.BufferContext puffer, int wurzel) {
    Millimeter? mm(int platz) => switch (const fb.Int32Reader()
        .vTableGetNullable(puffer, wurzel, _versatz(platz))) {
      final wert? => Millimeter(wert),
      null => null,
    };
    bool ja(int platz) =>
        const fb.BoolReader().vTableGet(puffer, wurzel, _versatz(platz), false);
    return Hoehenpunkte(
      hoehen: [
        for (final h in const fb.ListReader<int>(
          fb.Int32Reader(),
        ).vTableGet(puffer, wurzel, _versatz(_hoehenPlatz), const []))
          Millimeter(h),
      ],
      aufbauhoehe: mm(_aufbauhoehePlatz),
      mindesthoehe: mm(_mindesthoehePlatz),
      korrigiert: ja(_hoehenKorrigiertPlatz),
      gedreht: ja(_ukGedrehtPlatz),
    );
  }

  static Befestigungsbedarf _befestigung(fb.BufferContext puffer, int wurzel) {
    final art = const fb.Uint8Reader().vTableGetNullable(
      puffer,
      wurzel,
      _versatz(_befestigungsartPlatz),
    );
    return Befestigungsbedarf(
      arten: [
        for (final n in const fb.ListReader<int>(fb.Uint8Reader()).vTableGet(
          puffer,
          wurzel,
          _versatz(_befestigungsartenPlatz),
          const [],
        ))
          Befestigungsart.ausNummer(n),
      ],
      art: art == null ? null : Befestigungsart.ausNummer(art),
      punkte: const fb.Uint32Reader().vTableGet(
        puffer,
        wurzel,
        _versatz(_befestigungspunktePlatz),
        0,
      ),
      mittel: [
        for (final ort in const fb.ListReader<int>(_Tabellenort()).vTableGet(
          puffer,
          wurzel,
          _versatz(_befestigungsmittelPlatz),
          const [],
        ))
          Befestigungsposition(
            Artikelnummer(
              const fb.StringReader().vTableGet(puffer, ort, _versatz(0), ''),
            ),
            const fb.StringReader().vTableGet(puffer, ort, _versatz(1), ''),
            const fb.Uint32Reader().vTableGet(puffer, ort, _versatz(2), 0),
          ),
      ],
    );
  }

  static Millimeter _mm(fb.BufferContext puffer, int wurzel, int platz) =>
      Millimeter(
        const fb.Int32Reader().vTableGet(puffer, wurzel, _versatz(platz), 0),
      );

  /// Rand des Grundrisses in mm als Linienzug ab A; Bögen als Sehnenzug
  /// (Kreis, M4-07).
  final List<Punkt> umriss;

  /// Benannte Eckpunkte A, B … für Beschriftungen; ohne Bögen gleich dem
  /// [umriss], beim Kreis leer.
  final List<Punkt> ecken;

  /// Ob der Umriss eine Fläche umschließt; eine offene Freiform (M4-08) hat
  /// keine Fläche.
  final bool geschlossen;

  /// Ausschnitte (Eckpunkte in mm), in der Reihenfolge des Planungsstands.
  final List<List<Punkt>> ausschnitte;

  /// Terrassenfläche in mm² – wie im alten Planer die Außenfläche, leere
  /// Ausschnitte zählen mit (Fachkonzept 1.4).
  final double flaeche;

  /// Terrassenfläche in m² für die Anzeige.
  double get flaecheQuadratmeter => flaeche / 1e6;

  /// Summe aller Flächen der Planung in mm², jede mal ihrer Häufigkeit
  /// (M4-14); bei nur einer Fläche gleich [flaeche].
  final double gesamtflaeche;

  /// Gesamtfläche in m² für die Anzeige.
  double get gesamtflaecheQuadratmeter => gesamtflaeche / 1e6;

  /// Umrisse der Dielenstücke (M5-05) in mm für die Zeichnung; leer, solange
  /// kein Belag bekannt ist.
  final List<List<Punkt>> dielen;

  /// Ausgangspunkt der Verlegung in mm (M5-07): gewählte Ecke plus
  /// Verschiebung – dort liegt der Griff der ersten ganzen Diele. `null`
  /// ohne Dielen.
  final Punkt? ausgangspunkt;

  /// Größte Verschiebung nach links oder rechts in mm (M5-07,
  /// `verschiebungsgrenzen`); 0 ohne Dielen.
  final Millimeter grenzeLinksRechts;

  /// Größte Verschiebung nach oben oder unten in mm; 0 ohne Dielen.
  final Millimeter grenzeObenUnten;

  /// Ob ein Dielenstück kürzer oder eine Randreihe schmaler als 5 cm ist
  /// (`Dielenstueck.kurzerZuschnitt`, M5-07).
  final bool kurzeZuschnitte;

  /// Befestigung des Belags (M5-09): wählbare und wirksame Art,
  /// Befestigungspunkte und Artikel mit Anzahl; ohne Dielen keine.
  final Befestigungsbedarf befestigung;

  /// Geprüfte Höhenpunkte (M6-02) mit Aufbauhöhe und Hinweisen; bei der
  /// offenen Freiform keine.
  final Hoehenpunkte hoehenpunkte;

  /// Nummer je Dielenstück (parallel zu [dielen], M5-08) wie in „Dielen
  /// nach Nummer“; jede Teilfläche zählt ab 1. Leer ohne Dielen.
  final List<int> nummern;

  /// Verschnitt der ganzen Planung (M5-08, R-B11) als Anteil
  /// (0,04 = 4 %); `null`, solange keine Fläche verlegt ist.
  final double? verschnitt;

  /// Dielenliste der ganzen Planung (M5-08): Anzahl je Belag und
  /// Lieferlänge, jede Fläche mal ihrer Häufigkeit (M4-14).
  final List<Lieferposition> dielenliste;

  /// Meldungen zum Belag der bearbeiteten Fläche (M5-10,
  /// `belagmeldungen`); die App zeigt sie unter dem Unterpunkt der Eingabe.
  final List<Belagmeldung> belagmeldungen;

  /// Materialliste der ganzen Planung (M9-03): Belag und Befestigung aller
  /// Flächen mal ihrer Häufigkeit; Preise nur Anzeige (B-055).
  final Materialliste materialliste;

  /// Stückliste der bearbeiteten Fläche (M9-04): Artikel, Länge, Stück und
  /// Farbe wie im Plan; ohne Häufigkeit, weil sie die Zeichnung erklärt.
  final Stueckliste stueckliste;

  /// Farbe je Dielenstück (parallel zu [dielen], M9-04) – dieselbe wie in
  /// der Stückliste; leer ohne Dielen.
  final List<Stueckfarbe> stueckfarben;

  /// Querstreben der bearbeiteten Fläche für die Zeichnung (M6-05
  /// Versteifung, M6-06 zusätzliche Querstreben); leer ohne.
  final List<Strebe> querstreben;

  /// Wirksame Anzahl der Quertraversen (Reihen der Querstreben) der
  /// bearbeiteten Fläche (M6-06); `null` ohne Querstreben.
  final int? querstrebenReihen;

  /// Stellfüße zur UK der bearbeiteten Fläche für die gewählte Nutzung
  /// (M6-07, `Regelwerk.stellfuesse`) in Datenreihenfolge; leer ohne UK,
  /// Regelwerk oder Verweise.
  final List<Stellfuss> stellfuesse;

  /// Unterkonstruktion der bearbeiteten Fläche (M6-08 bis M6-11): Auflager
  /// mit Abstand, Höhenbereichen und Meldungen.
  final Unterbau unterbau;

  /// Kopie mit den Werten der ganzen Planung (M4-14, M5-08).
  Berechnung mitPlanung(
    double gesamtflaeche, {
    double? verschnitt,
    List<Lieferposition> dielenliste = const [],
    Materialliste? materialliste,
  }) => Berechnung(
    umriss: umriss,
    ecken: ecken,
    geschlossen: geschlossen,
    flaeche: flaeche,
    ausschnitte: ausschnitte,
    gesamtflaeche: gesamtflaeche,
    dielen: dielen,
    ausgangspunkt: ausgangspunkt,
    grenzeLinksRechts: grenzeLinksRechts,
    grenzeObenUnten: grenzeObenUnten,
    kurzeZuschnitte: kurzeZuschnitte,
    befestigung: befestigung,
    hoehenpunkte: hoehenpunkte,
    nummern: nummern,
    verschnitt: verschnitt,
    dielenliste: dielenliste,
    belagmeldungen: belagmeldungen,
    materialliste: materialliste,
    stueckliste: stueckliste,
    stueckfarben: stueckfarben,
    querstreben: querstreben,
    querstrebenReihen: querstrebenReihen,
    stellfuesse: stellfuesse,
    unterbau: unterbau,
  );

  /// FlatBuffer für den Weg zur App (#110):
  /// `{ 0: umriss ([float64] x, y je Punkt), 1: flaeche (float64 mm²),
  /// 2: ausschnitte ([{ 0: punkte ([float64]) }]), 3: ecken ([float64]),
  /// 4: geschlossen (bool), 5: gesamtflaeche (float64 mm², M4-14),
  /// 6: dielen ([{ 0: punkte ([float64]) }], M5-05),
  /// 7: ausgangspunkt ([float64] x, y; fehlt ohne Dielen),
  /// 8: grenzeLinksRechts (int32 mm), 9: grenzeObenUnten (int32 mm),
  /// 10: kurzeZuschnitte (bool) (M5-07), 11: befestigungsarten ([uint8]),
  /// 12: befestigungsart (uint8; fehlt ohne Art), 13: befestigungspunkte
  /// (uint32), 14: befestigungsmittel ([{ 0: nummer (string), 1: titel
  /// (string), 2: anzahl (uint32) }]) (M5-09), 15: nummern ([int32]),
  /// 16: verschnitt (float64, fehlt ohne Dielen), 17: dielenliste
  /// ([{ 0: belag (string), 1: laenge (int32 mm), 2: anzahl (int32) }])
  /// (M5-08), 25: hoehen ([int32] mm je Eckpunkt), 26: hoehenKorrigiert
  /// (bool), 27: ukGedreht (bool), 28: aufbauhoehe (int32 mm),
  /// 29: mindesthoehe (int32 mm; beide fehlen ungeprüft) (M6-02),
  /// 35: belagmeldungen ([uint8], M5-10), 60: materialliste
  /// (Tabelle, `Materialliste.schreibe`, M9-03), 61: stueckliste (Tabelle,
  /// `Stueckliste.schreibe`), 62: stueckfarben ([uint8] je Dielenstück)
  /// (M9-04), 90: querstreben ([float64] x, y von und bis je Strebe),
  /// 91: querstrebenReihen (uint16; fehlt ohne) (M6-06), 92: stellfuesse
  /// ([{ 0: nummer (string), 1: titel (string) }]) (M6-07), 110: unterbau
  /// (Tabelle, `Unterbau.schreibe`, M6-08 bis M6-11) }`. Die Plätze 18–34 sind für die Unterkonstruktion (M6)
  /// frei gehalten, 60–69 für die Ergebnisse (M9).
  Uint8List zuBytes() {
    final fbb = fb.Builder();
    final umrissOrt = _schreibe(fbb, umriss);
    final ausschnitteOrt = fbb.writeList([
      for (final a in ausschnitte) _ausschnitt(fbb, a),
    ]);
    final eckenOrt = _schreibe(fbb, ecken);
    final dielenOrt = fbb.writeList([
      for (final d in dielen) _ausschnitt(fbb, d),
    ]);
    final nummernOrt = fbb.writeListInt32(nummern);
    final listeOrt = fbb.writeList([
      for (final p in dielenliste) _lieferposition(fbb, p),
    ]);
    final ausgangOrt = switch (ausgangspunkt) {
      final p? => _schreibe(fbb, [p]),
      null => null,
    };
    final artenOrt = fbb.writeListUint8([
      for (final a in befestigung.arten) a.nummer,
    ]);
    final mittelOrt = fbb.writeList([
      for (final m in befestigung.mittel) _position(fbb, m),
    ]);
    final hoehenOrt = fbb.writeListInt32([
      for (final h in hoehenpunkte.hoehen) h.mm,
    ]);
    final meldungenOrt = fbb.writeListUint8([
      for (final m in belagmeldungen) m.nummer,
    ]);
    final materialOrt = materialliste.schreibe(fbb);
    final stueckOrt = stueckliste.schreibe(fbb);
    final farbenOrt = fbb.writeListUint8([
      for (final f in stueckfarben) f.nummer,
    ]);
    final strebenOrt = _schreibe(fbb, [
      for (final s in querstreben) ...[s.von, s.bis],
    ]);
    final fuesseOrt = fbb.writeList([
      for (final f in stellfuesse) _stellfuss(fbb, f),
    ]);
    final unterbauOrt = unterbau.schreibe(fbb);
    fbb
      ..startTable(_unterbauPlatz + 1)
      ..addOffset(_umrissPlatz, umrissOrt)
      ..addFloat64(_flaechePlatz, flaeche)
      ..addOffset(_ausschnittePlatz, ausschnitteOrt)
      ..addOffset(_eckenPlatz, eckenOrt)
      ..addBool(_geschlossenPlatz, geschlossen)
      ..addFloat64(_gesamtflaechePlatz, gesamtflaeche)
      ..addOffset(_dielenPlatz, dielenOrt)
      ..addOffset(_ausgangspunktPlatz, ausgangOrt)
      ..addInt32(_grenzeLinksRechtsPlatz, grenzeLinksRechts.mm)
      ..addInt32(_grenzeObenUntenPlatz, grenzeObenUnten.mm)
      ..addBool(_kurzeZuschnittePlatz, kurzeZuschnitte)
      ..addOffset(_befestigungsartenPlatz, artenOrt)
      ..addUint8(_befestigungsartPlatz, befestigung.art?.nummer)
      ..addUint32(_befestigungspunktePlatz, befestigung.punkte)
      ..addOffset(_befestigungsmittelPlatz, mittelOrt)
      ..addOffset(_nummernPlatz, nummernOrt)
      ..addOffset(_dielenlistePlatz, listeOrt)
      ..addOffset(_hoehenPlatz, hoehenOrt)
      ..addBool(_hoehenKorrigiertPlatz, hoehenpunkte.korrigiert)
      ..addBool(_ukGedrehtPlatz, hoehenpunkte.gedreht)
      ..addInt32(_aufbauhoehePlatz, hoehenpunkte.aufbauhoehe?.mm)
      ..addInt32(_mindesthoehePlatz, hoehenpunkte.mindesthoehe?.mm)
      ..addOffset(_belagmeldungenPlatz, meldungenOrt)
      ..addOffset(_materiallistePlatz, materialOrt)
      ..addOffset(_stuecklistePlatz, stueckOrt)
      ..addOffset(_stueckfarbenPlatz, farbenOrt)
      ..addOffset(_querstrebenPlatz, strebenOrt)
      ..addUint16(_querstrebenReihenPlatz, querstrebenReihen)
      ..addOffset(_stellfuessePlatz, fuesseOrt)
      ..addOffset(_unterbauPlatz, unterbauOrt);
    if (verschnitt case final v?) fbb.addFloat64(_verschnittPlatz, v);
    fbb.finish(fbb.endTable());
    return fbb.buffer;
  }

  static int _schreibe(fb.Builder fbb, List<Punkt> punkte) =>
      fbb.writeListFloat64([
        for (final p in punkte) ...[p.x, p.y],
      ]);

  static int _lieferposition(fb.Builder fbb, Lieferposition p) {
    final belagOrt = fbb.writeString(p.belag.wert);
    fbb
      ..startTable(3)
      ..addOffset(0, belagOrt)
      ..addInt32(1, p.laenge.mm)
      ..addInt32(2, p.anzahl);
    return fbb.endTable();
  }

  /// Linienzug als Tabelle `{ 0: punkte }` (Ausschnitte, Dielen).
  static int _ausschnitt(fb.Builder fbb, List<Punkt> punkte) {
    final ort = _schreibe(fbb, punkte);
    fbb
      ..startTable(1)
      ..addOffset(0, ort);
    return fbb.endTable();
  }

  static int _stellfuss(fb.Builder fbb, Stellfuss f) {
    final nummerOrt = fbb.writeString(f.nummer.wert);
    final titelOrt = fbb.writeString(f.titel);
    fbb
      ..startTable(2)
      ..addOffset(0, nummerOrt)
      ..addOffset(1, titelOrt);
    return fbb.endTable();
  }

  static int _position(fb.Builder fbb, Befestigungsposition m) {
    final nummerOrt = fbb.writeString(m.nummer.wert);
    final titelOrt = fbb.writeString(m.titel);
    fbb
      ..startTable(3)
      ..addOffset(0, nummerOrt)
      ..addOffset(1, titelOrt)
      ..addUint32(2, m.anzahl);
    return fbb.endTable();
  }

  static List<List<Punkt>> _umrisse(
    fb.BufferContext puffer,
    int wurzel,
    int platz,
  ) => [
    for (final ort in const fb.ListReader<int>(
      _Tabellenort(),
    ).vTableGet(puffer, wurzel, _versatz(platz), const []))
      _punkte(puffer, ort, 0),
  ];

  static List<Punkt> _punkte(fb.BufferContext puffer, int ort, int platz) {
    final k = const fb.ListReader<double>(fb.Float64Reader())
        .vTableGet(puffer, ort, _versatz(platz), const []);
    // Zählschleife mit i++: ein Mutant „i += 2 → i = 2“ liefe endlos und
    // sprengte den Speicher des Runners (docs/erkenntnisse/mutation-tests.md)
    return [
      for (var i = 0; i < k.length ~/ 2; i++) Punkt(k[2 * i], k[2 * i + 1]),
    ];
  }

  static const _umrissPlatz = 0;
  static const _flaechePlatz = 1;
  static const _ausschnittePlatz = 2;
  static const _eckenPlatz = 3;
  static const _geschlossenPlatz = 4;
  static const _gesamtflaechePlatz = 5;
  static const _dielenPlatz = 6;
  static const _ausgangspunktPlatz = 7;
  static const _grenzeLinksRechtsPlatz = 8;
  static const _grenzeObenUntenPlatz = 9;
  static const _kurzeZuschnittePlatz = 10;
  static const _befestigungsartenPlatz = 11;
  static const _befestigungsartPlatz = 12;
  static const _befestigungspunktePlatz = 13;
  static const _befestigungsmittelPlatz = 14;
  static const _nummernPlatz = 15;
  static const _verschnittPlatz = 16;
  static const _dielenlistePlatz = 17;
  static const _hoehenPlatz = 25;
  static const _hoehenKorrigiertPlatz = 26;
  static const _ukGedrehtPlatz = 27;
  static const _aufbauhoehePlatz = 28;
  static const _mindesthoehePlatz = 29;
  static const _belagmeldungenPlatz = 35;
  static const _materiallistePlatz = 60;
  static const _stuecklistePlatz = 61;
  static const _stueckfarbenPlatz = 62;
  static const _querstrebenPlatz = 90;
  static const _querstrebenReihenPlatz = 91;
  static const _stellfuessePlatz = 92;
  static const _unterbauPlatz = 110;

  static int _versatz(int platz) => 4 + 2 * platz;
}

/// Stellfuß zur Auswahl (M6-07): Artikelnummer und Titel.
typedef Stellfuss = ({Artikelnummer nummer, String titel});

/// Zeile der Dielenliste (M5-08): so viele Dielen des Belags in dieser
/// Lieferlänge.
typedef Lieferposition = ({Artikelnummer belag, Millimeter laenge, int anzahl});

/// Liest nur den Ort einer Tabelle – die Felder liest der Aufrufer.
final class _Tabellenort extends fb.TableReader<int> {
  const _Tabellenort();

  @override
  int createObject(fb.BufferContext puffer, int ort) => ort;
}
