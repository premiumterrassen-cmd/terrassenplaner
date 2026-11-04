import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;

import '../artikel/artikel.dart';
import '../artikel/einheiten.dart';
import '../geometrie/kontur.dart';
import '../geometrie/punkt.dart';
import 'ausschnitt.dart';
import 'befestigungsart.dart';
import 'grundriss.dart';
import 'rundungen.dart';
import 'terrassenart.dart';
import 'verlegeart.dart';
import 'verlegerichtung.dart';

/// Eingaben einer Planung zu einem Zeitpunkt (M3-03) – unveränderlich, damit
/// Rückgängig exakt auf einen früheren Stand springen kann. Seit M4-02 mit
/// Grundriss, seit M4-06 mit Ausschnitten, seit M5-01 mit Belag, seit M5-02
/// mit Dielenlänge, seit M5-03 mit „kurze Stücke verbinden“, seit M5-04 mit
/// Verlegeart, seit M5-05 mit Verlegerichtung, seit M5-07 mit
/// Ausgangspunkt, seit M5-09 mit Befestigungsart, seit M6-01 mit Art der
/// Terrasse und Spannweite, seit M6-02 mit Höhenpunkten;
/// Unterkonstruktion usw. folgen als weitere Felder. Berechnet wird daraus
/// auf dem Server.
final class Planungsstand {
  const Planungsstand({
    this.grundriss = RechteckGrundriss.start,
    this.ausschnitte = const [],
    this.rundungen = Rundungen.keine,
    this.belag,
    this.dielenlaenge,
    this.kurzeStueckeVerbinden = false,
    this.verlegeart = Verlegeart.fugenschnitt,
    this.verlegerichtung = Verlegerichtung.waagrecht,
    this.verlegewinkel = Verlegerichtung.vorgabeWinkel,
    this.ausgangsecke = 0,
    this.verschiebungX = const Millimeter(0),
    this.verschiebungY = const Millimeter(0),
    this.befestigungsart = Befestigungsart.clips,
    this.terrassenart = Terrassenart.normal,
    this.spannweite = Terrassenart.vorgabeSpannweite,
    this.gefaelle = false,
    this.hoehe,
    this.eckhoehen = const [],
  });

  /// Liest einen Planungsstand aus dem Transportformat ([zuBytes]).
  factory Planungsstand.ausBytes(Uint8List bytes) {
    final puffer = fb.BufferContext.fromBytes(bytes);
    final wurzel = puffer.derefObject(0);
    final grundriss = const _GrundrissLeser().vTableGetNullable(
      puffer,
      wurzel,
      _versatz(_grundrissPlatz),
    );
    if (grundriss == null) {
      throw const FormatException('Planungsstand ohne Grundriss');
    }
    final ecke = const fb.Uint16Reader().vTableGet(
      puffer,
      wurzel,
      _versatz(_ausgangseckePlatz),
      0,
    );
    if (ecke >= _eckenzahl(grundriss)) {
      throw FormatException('unbekannte Ausgangsecke $ecke');
    }
    return Planungsstand(
      grundriss: grundriss,
      ausschnitte: [
        ...const fb.ListReader<Ausschnitt>(_AusschnittLeser())
            .vTableGet(puffer, wurzel, _versatz(_ausschnittePlatz), const []),
      ],
      rundungen: Rundungen.aus(
        const fb.ListReader<int>(fb.Int32Reader())
            .vTableGet(puffer, wurzel, _versatz(_rundungenPlatz), const []),
      ),
      belag: switch (const fb.StringReader().vTableGetNullable(
        puffer,
        wurzel,
        _versatz(_belagPlatz),
      )) {
        final nummer? => Artikelnummer(nummer),
        null => null,
      },
      dielenlaenge: switch (const fb.Int32Reader().vTableGetNullable(
        puffer,
        wurzel,
        _versatz(_dielenlaengePlatz),
      )) {
        final mm? => Millimeter(mm),
        null => null,
      },
      kurzeStueckeVerbinden: const fb.BoolReader().vTableGet(
        puffer,
        wurzel,
        _versatz(_kurzeStueckeVerbindenPlatz),
        false,
      ),
      verlegeart: _wert(
        Verlegeart.values,
        (v) => v.nummer,
        puffer,
        wurzel,
        _verlegeartPlatz,
      ),
      verlegerichtung: _wert(
        Verlegerichtung.values,
        (r) => r.nummer,
        puffer,
        wurzel,
        _verlegerichtungPlatz,
      ),
      verlegewinkel: const fb.Uint8Reader().vTableGet(
        puffer,
        wurzel,
        _versatz(_verlegewinkelPlatz),
        Verlegerichtung.vorgabeWinkel,
      ),
      ausgangsecke: ecke,
      verschiebungX: _mm(puffer, wurzel, _verschiebungXPlatz),
      verschiebungY: _mm(puffer, wurzel, _verschiebungYPlatz),
      befestigungsart: Befestigungsart.ausNummer(
        const fb.Uint8Reader().vTableGet(
          puffer,
          wurzel,
          _versatz(_befestigungsartPlatz),
          0,
        ),
      ),
      terrassenart: Terrassenart.ausNummer(
        const fb.Uint8Reader().vTableGet(
          puffer,
          wurzel,
          _versatz(_terrassenartPlatz),
          0,
        ),
      ),
      spannweite: Millimeter(
        const fb.Int32Reader().vTableGet(
          puffer,
          wurzel,
          _versatz(_spannweitePlatz),
          Terrassenart.vorgabeSpannweite.mm,
        ),
      ),
      gefaelle: const fb.BoolReader().vTableGet(
        puffer,
        wurzel,
        _versatz(_gefaellePlatz),
        false,
      ),
      hoehe: switch (const fb.Int32Reader().vTableGetNullable(
        puffer,
        wurzel,
        _versatz(_hoehePlatz),
      )) {
        final mm? => Millimeter(mm),
        null => null,
      },
      eckhoehen: List.unmodifiable([
        for (final mm in const fb.ListReader<int>(
          fb.Int32Reader(),
        ).vTableGet(puffer, wurzel, _versatz(_eckhoehenPlatz), const []))
          Millimeter(mm),
      ]),
    );
  }

  static Millimeter _mm(fb.BufferContext puffer, int wurzel, int platz) =>
      Millimeter(
        const fb.Int32Reader().vTableGet(puffer, wurzel, _versatz(platz), 0),
      );

  /// Startkonfiguration des alten Planers (F01) – auch nach „Zurücksetzen“.
  static const start = Planungsstand();

  final Grundriss grundriss;

  /// Ausschnitte im Grundriss (Fachkonzept 1.4), in der Reihenfolge A1, A2 …
  final List<Ausschnitt> ausschnitte;

  /// Rundungen an Ecken und Seiten (Fachkonzept 1.3, M4-11).
  final Rundungen rundungen;

  /// Gewählter Belag (M5-01); `null` = Vorgabe, der erste Belag der
  /// Artikeldaten.
  final Artikelnummer? belag;

  /// Erzwungene Lieferlänge (M5-02, R-B10); `null` = automatisch. Gilt nur,
  /// solange der Belag sie liefert (`lieferlaengenFuer`).
  final Millimeter? dielenlaenge;

  /// „Sollen kurze Dielenstücke miteinander verbunden werden?“ (M5-03,
  /// R-B12); Vorgabe Nein. Wirkung: `reihenstuecke`.
  final bool kurzeStueckeVerbinden;

  /// Verlegeart (M5-04, Fachkonzept 2.3); Vorgabe Fugenschnitt. Wirkung:
  /// `Verlegeart.stoesse`.
  final Verlegeart verlegeart;

  /// Verlegerichtung (M5-05, Fachkonzept 2.4); Vorgabe waagrecht.
  final Verlegerichtung verlegerichtung;

  /// Feld „Winkel“ in Grad für [Verlegerichtung.individuell]; bleibt beim
  /// Wechsel auf eine feste Richtung erhalten.
  final int verlegewinkel;

  /// „Welcher Punkt soll der Ausgangspunkt des Terrassenbelages sein?“
  /// (M5-07, Fachkonzept 2.5): Nummer der Ecke, 0 = A (Vorgabe). Gezählt
  /// wird wie in der Beschriftung der Zeichnung (`Grundriss.ecken`); der
  /// Kreis hat nur A, den Anfang seiner Kontur.
  final int ausgangsecke;

  /// Verschiebung der ersten ganzen Diele nach rechts (negativ: links) in
  /// Bildschirmkoordinaten (M5-07); die Grenze rechnet der Server
  /// (`verschiebungsgrenzen`).
  final Millimeter verschiebungX;

  /// Verschiebung der ersten ganzen Diele nach unten (negativ: oben).
  final Millimeter verschiebungY;

  /// Gewählte Befestigungsart (M5-09, Fachkonzept 2.6); Vorgabe Clips wie
  /// im alten Planer. Was gilt, hängt vom Profil des Belags ab
  /// (`Befestigungsart.wirksam`: glattkant wird verschraubt, B-090); die
  /// Wahl bleibt bei einem Belagwechsel erhalten.
  final Befestigungsart befestigungsart;

  /// Art der Terrasse (M6-01, Fachkonzept 3.1); Vorgabe normale Terrasse.
  final Terrassenart terrassenart;

  /// „Spannweite der Unterkonstruktion“ (M6-01): Abstand der vorhandenen
  /// Träger, gefragt nur bei [Terrassenart.vorhandeneUk]; bleibt beim
  /// Wechsel der Art erhalten.
  final Millimeter spannweite;

  /// Höhenpunkte „mit Gefälle“ (M6-02, Fachkonzept 3.2): je Eckpunkt eine
  /// eigene Höhe ([eckhoehen]); sonst gilt [alleHoehe] für alle.
  final bool gefaelle;

  /// Feld „Alle“ ohne Gefälle in mm von Oberkante Belag bis Boden; `null` =
  /// die Vorgabehöhe der [terrassenart].
  final Millimeter? hoehe;

  /// Höhen je Eckpunkt A, B … mit Gefälle; fehlt ein Eckpunkt, gilt
  /// [alleHoehe]. Bleiben beim Ausschalten des Gefälles erhalten.
  final List<Millimeter> eckhoehen;

  /// Höhe ohne Gefälle: die eingegebene oder die Vorgabehöhe der Art.
  Millimeter get alleHoehe => hoehe ?? terrassenart.vorgabehoehe;

  /// Eingegebene Höhe je Höhenpunkt – ein Punkt je Ecke wie beim
  /// Ausgangspunkt ([ausgangsecken], der Kreis hat nur A). Geprüft und
  /// korrigiert rechnet sie der Server (`pruefeHoehen`).
  List<Millimeter> get hoehen => [
    for (var i = 0; i < ausgangsecken; i++)
      gefaelle && i < eckhoehen.length ? eckhoehen[i] : alleHoehe,
  ];

  /// Ob [hoehe] als Höhenpunkt gilt: über 0 bis 300 cm.
  static bool hoeheGueltig(Millimeter hoehe) =>
      hoehe > const Millimeter(0) && hoehe <= const Millimeter(3000);

  /// Wie viele Ecken als Ausgangspunkt wählbar sind (A, B …).
  int get ausgangsecken => _eckenzahl(grundriss);

  static int _eckenzahl(Grundriss g) => math.max(1, g.ecken.length);

  /// Gewählte Ecke in mm, ohne Verschiebung: beim Kreis (ohne benannte
  /// Ecken) der Anfang der Kontur, sonst die Ecke des Grundrisses – bei
  /// einer gerundeten Ecke der Schnittpunkt ihrer Kanten.
  Punkt get ausgangspunkt => switch (grundriss.ecken) {
    [] => kontur.punkte.first,
    final ecken => ecken[ausgangsecke],
  };

  /// Winkel der Dielen in Grad (`verlegeDielen`).
  int get dielenwinkel => verlegerichtung.winkel ?? verlegewinkel;

  /// Kontur des Grundrisses samt Rundungen.
  Kontur get kontur => rundungen.kontur(grundriss);

  /// Kopie, in der nur die angegebenen Felder anders sind – die eine Stelle,
  /// an der neue Felder ergänzt werden. [dielenlaenge] als Eintrag, weil
  /// `null` (automatisch) ein gültiger Wert ist.
  Planungsstand _mit({
    Grundriss? grundriss,
    List<Ausschnitt>? ausschnitte,
    Rundungen? rundungen,
    Artikelnummer? belag,
    ({Millimeter? wert})? dielenlaenge,
    bool? kurzeStueckeVerbinden,
    Verlegeart? verlegeart,
    Verlegerichtung? verlegerichtung,
    int? verlegewinkel,
    int? ausgangsecke,
    Millimeter? verschiebungX,
    Millimeter? verschiebungY,
    Befestigungsart? befestigungsart,
    Terrassenart? terrassenart,
    Millimeter? spannweite,
    bool? gefaelle,
    ({Millimeter? wert})? hoehe,
    List<Millimeter>? eckhoehen,
  }) {
    final neu = grundriss ?? this.grundriss;
    final ecke = ausgangsecke ?? this.ausgangsecke;
    return Planungsstand(
      grundriss: neu,
      ausschnitte: ausschnitte ?? this.ausschnitte,
      rundungen: rundungen ?? this.rundungen,
      belag: belag ?? this.belag,
      dielenlaenge: dielenlaenge == null
          ? this.dielenlaenge
          : dielenlaenge.wert,
      kurzeStueckeVerbinden:
          kurzeStueckeVerbinden ?? this.kurzeStueckeVerbinden,
      verlegeart: verlegeart ?? this.verlegeart,
      verlegerichtung: verlegerichtung ?? this.verlegerichtung,
      verlegewinkel: verlegewinkel ?? this.verlegewinkel,
      // weniger Ecken nach einem Formwechsel: zurück auf A
      ausgangsecke: ecke < _eckenzahl(neu) ? ecke : 0,
      verschiebungX: verschiebungX ?? this.verschiebungX,
      verschiebungY: verschiebungY ?? this.verschiebungY,
      befestigungsart: befestigungsart ?? this.befestigungsart,
      terrassenart: terrassenart ?? this.terrassenart,
      spannweite: spannweite ?? this.spannweite,
      gefaelle: gefaelle ?? this.gefaelle,
      hoehe: hoehe == null ? this.hoehe : hoehe.wert,
      eckhoehen: eckhoehen ?? this.eckhoehen,
    );
  }

  /// Kopie mit geändertem Grundriss; die Rundungen bleiben, solange es
  /// gleich viele Ecken sind und sie weiter passen.
  Planungsstand mitGrundriss(Grundriss grundriss) => _mit(
    grundriss: grundriss,
    rundungen: _passend(grundriss) ? rundungen : Rundungen.keine,
  );

  bool _passend(Grundriss neu) {
    if (rundungen.leer) return true;
    if (neu.ecken.length != grundriss.ecken.length) return false;
    try {
      rundungen.kontur(neu);
      return true;
    } on ArgumentError {
      return false;
    }
  }

  /// Kopie mit anderen Rundungen (die App prüft sie vorher über [kontur]).
  Planungsstand mitRundungen(Rundungen rundungen) => _mit(rundungen: rundungen);

  /// Neue Form mit ihren Vorgabemaßen; die O-Form bringt ihren Ausschnitt
  /// mit, alle anderen beginnen ohne (Fachkonzept 1.1).
  Planungsstand mitForm(Terrassenform form) => _mit(
    grundriss: form.vorgabe,
    ausschnitte: [if (form == Terrassenform.oForm) Ausschnitt.oForm],
    rundungen: Rundungen.keine,
  );

  /// Grundriss um [grad] gedreht (M4-10); die Ausschnitte werden dabei
  /// zurückgesetzt – die App fragt vorher nach.
  Planungsstand gedreht(double grad) => _mit(
    grundriss: grundriss.gedreht(grad),
    ausschnitte: const [],
    rundungen: Rundungen.keine,
  );

  /// Mit einer weiteren Fläche (180 × 120 cm, Bezeichnung A1, A2 …) mitten
  /// im Grundriss („Weitere Flächen hinzufügen“, Fachkonzept 1.4).
  Planungsstand mitNeuemAusschnitt() {
    final namen = {for (final a in ausschnitte) a.bezeichnung};
    var nummer = 1;
    while (namen.contains('A$nummer')) {
      nummer++;
    }
    final mitte = kontur.huellrechteck.mitte;
    return _mit(
      ausschnitte: [
        ...ausschnitte,
        Ausschnitt(
          bezeichnung: 'A$nummer',
          x: Millimeter((mitte.x - Ausschnitt.vorgabeLaenge.mm / 2).round()),
          y: Millimeter((mitte.y - Ausschnitt.vorgabeBreite.mm / 2).round()),
          laenge: Ausschnitt.vorgabeLaenge,
          breite: Ausschnitt.vorgabeBreite,
        ),
      ],
    );
  }

  /// Ohne den Ausschnitt [index].
  Planungsstand ohneAusschnitt(int index) =>
      _mit(ausschnitte: [...ausschnitte]..removeAt(index));

  /// Kopie, in der der Ausschnitt [index] durch [ausschnitt] ersetzt ist.
  Planungsstand mitAusschnitt(int index, Ausschnitt ausschnitt) =>
      _mit(ausschnitte: [...ausschnitte]..[index] = ausschnitt);

  /// Kopie mit anderem Belag; die übrigen Eingaben bleiben.
  Planungsstand mitBelag(Artikelnummer belag) => _mit(belag: belag);

  /// Kopie mit erzwungener Lieferlänge; `null` = automatisch.
  Planungsstand mitDielenlaenge(Millimeter? dielenlaenge) =>
      _mit(dielenlaenge: (wert: dielenlaenge));

  /// Kopie mit der Antwort auf „kurze Stücke verbinden“.
  Planungsstand mitKurzeStueckeVerbinden(bool verbinden) =>
      _mit(kurzeStueckeVerbinden: verbinden);

  /// Kopie mit anderer Verlegeart.
  Planungsstand mitVerlegeart(Verlegeart verlegeart) =>
      _mit(verlegeart: verlegeart);

  /// Kopie mit anderer Verlegerichtung; [winkel] setzt das Feld „Winkel“
  /// (nur ganze Grad von 0 bis 179, `Verlegerichtung.winkelGueltig`).
  Planungsstand mitVerlegerichtung(Verlegerichtung richtung, {int? winkel}) {
    if (winkel != null && !Verlegerichtung.winkelGueltig(winkel)) {
      throw ArgumentError.value(winkel, 'winkel', 'muss 0 bis 179 Grad sein');
    }
    return _mit(verlegerichtung: richtung, verlegewinkel: winkel);
  }

  /// Kopie mit anderem Ausgangspunkt (M5-07): [ecke] wie [ausgangsecke]
  /// (0 bis [ausgangsecken] − 1), [x] und [y] wie [verschiebungX] und
  /// [verschiebungY]; nicht angegebene Werte bleiben.
  Planungsstand mitAusgangspunkt({int? ecke, Millimeter? x, Millimeter? y}) {
    if (ecke != null && (ecke < 0 || ecke >= ausgangsecken)) {
      throw RangeError.range(ecke, 0, ausgangsecken - 1, 'ecke');
    }
    return _mit(ausgangsecke: ecke, verschiebungX: x, verschiebungY: y);
  }

  /// Kopie mit anderer Befestigungsart (M5-09).
  Planungsstand mitBefestigungsart(Befestigungsart art) =>
      _mit(befestigungsart: art);

  /// Kopie mit anderer Art der Terrasse (M6-01); die Höhenpunkte springen
  /// wie im alten Planer auf die Vorgabehöhe der Art (M6-02).
  Planungsstand mitTerrassenart(Terrassenart art) =>
      _mit(terrassenart: art, hoehe: (wert: null), eckhoehen: const []);

  /// Kopie mit anderer Spannweite (M6-01); nur 10 bis 300 cm
  /// (`Terrassenart.spannweiteGueltig`).
  Planungsstand mitSpannweite(Millimeter spannweite) {
    if (!Terrassenart.spannweiteGueltig(spannweite)) {
      throw ArgumentError.value(
        spannweite.mm,
        'spannweite',
        'muss 100 bis 3000 mm sein',
      );
    }
    return _mit(spannweite: spannweite);
  }

  /// Kopie mit oder ohne Gefälle (M6-02).
  Planungsstand mitGefaelle(bool gefaelle) => _mit(gefaelle: gefaelle);

  /// Kopie mit der Höhe „Alle“ (M6-02, `hoeheGueltig`).
  Planungsstand mitHoehe(Millimeter hoehe) {
    _pruefeHoehe(hoehe);
    return _mit(hoehe: (wert: hoehe));
  }

  /// Kopie mit der Höhe des Eckpunkts [ecke] (0 = A); die übrigen Punkte
  /// behalten ihre Höhe.
  Planungsstand mitEckhoehe(int ecke, Millimeter hoehe) {
    if (ecke < 0 || ecke >= ausgangsecken) {
      throw RangeError.range(ecke, 0, ausgangsecken - 1, 'ecke');
    }
    _pruefeHoehe(hoehe);
    return _mit(
      eckhoehen: List.unmodifiable(
        [..._mit(gefaelle: true).hoehen]..[ecke] = hoehe,
      ),
    );
  }

  static void _pruefeHoehe(Millimeter hoehe) {
    if (!hoeheGueltig(hoehe)) {
      throw ArgumentError.value(hoehe.mm, 'hoehe', 'muss 1 bis 3000 mm sein');
    }
  }

  /// FlatBuffer für den Weg zum Server (#110):
  /// `{ 0: schema (uint16), 1: grundriss { 0: form (uint8), 1: masse ([int32] mm) },
  /// 2: ausschnitte ([{ 0: bezeichnung (string), 1: masse ([int32] mm) }]),
  /// 3: rundungen ([int32] je Art, Nummer, mm), 4: belag (string),
  /// 5: dielenlaenge (int32 mm), 6: kurze Stücke verbinden (bool),
  /// 7: verlegeart (uint8), 8: verlegerichtung (uint8),
  /// 9: verlegewinkel (uint8 Grad), 10: ausgangsecke (uint16),
  /// 11: verschiebungX (int32 mm), 12: verschiebungY (int32 mm),
  /// 13: befestigungsart (uint8, M5-09), 20: terrassenart (uint8),
  /// 21: spannweite (int32 mm) (M6-01), 22: gefaelle (bool), 23: hoehe
  /// (int32 mm; fehlt = Vorgabehöhe), 24: eckhoehen ([int32] mm) (M6-02) }`. Plätze 14–19 gehören der
  /// Dielenverlegung (M5-08).
  /// Neue Felder nur anhängen (docs/architektur/datenmodell.md).
  Uint8List zuBytes() {
    final fbb = fb.Builder();
    final masseOrt = fbb.writeListInt32([
      for (final m in grundriss.masse) m.mm,
    ]);
    fbb
      ..startTable(2)
      ..addUint8(0, grundriss.form.nummer)
      ..addOffset(1, masseOrt);
    final grundrissOrt = fbb.endTable();
    final ausschnitteOrt = fbb.writeList([
      for (final a in ausschnitte) _ausschnitt(fbb, a),
    ]);
    final rundungenOrt = fbb.writeListInt32(rundungen.masse);
    final eckhoehenOrt = fbb.writeListInt32([for (final h in eckhoehen) h.mm]);
    final belagOrt = switch (belag) {
      final nummer? => fbb.writeString(nummer.wert),
      null => null,
    };
    fbb
      ..startTable(25)
      ..addUint16(_schemaPlatz, schema)
      ..addOffset(_grundrissPlatz, grundrissOrt)
      ..addOffset(_ausschnittePlatz, ausschnitteOrt)
      ..addOffset(_rundungenPlatz, rundungenOrt)
      ..addOffset(_belagPlatz, belagOrt)
      ..addInt32(_dielenlaengePlatz, dielenlaenge?.mm)
      ..addBool(_kurzeStueckeVerbindenPlatz, kurzeStueckeVerbinden)
      ..addUint8(_verlegeartPlatz, verlegeart.nummer)
      ..addUint8(_verlegerichtungPlatz, verlegerichtung.nummer)
      ..addUint8(_verlegewinkelPlatz, verlegewinkel)
      ..addUint16(_ausgangseckePlatz, ausgangsecke)
      ..addInt32(_verschiebungXPlatz, verschiebungX.mm)
      ..addInt32(_verschiebungYPlatz, verschiebungY.mm)
      ..addUint8(_befestigungsartPlatz, befestigungsart.nummer)
      ..addUint8(_terrassenartPlatz, terrassenart.nummer)
      ..addInt32(_spannweitePlatz, spannweite.mm)
      ..addBool(_gefaellePlatz, gefaelle)
      ..addInt32(_hoehePlatz, hoehe?.mm)
      ..addOffset(_eckhoehenPlatz, eckhoehenOrt);
    fbb.finish(fbb.endTable());
    return fbb.buffer;
  }

  static int _ausschnitt(fb.Builder fbb, Ausschnitt a) {
    final bezeichnungOrt = fbb.writeString(a.bezeichnung);
    final masseOrt = fbb.writeListInt32([for (final m in a.masse) m.mm]);
    fbb
      ..startTable(5)
      ..addOffset(0, bezeichnungOrt)
      ..addOffset(1, masseOrt)
      ..addUint8(2, a.form.nummer)
      ..addUint8(3, a.funktion.nummer)
      ..addUint8(4, a.inhalt.nummer);
    return fbb.endTable();
  }

  /// Version des Transportformats.
  static const schema = 1;

  static const _schemaPlatz = 0;
  static const _grundrissPlatz = 1;
  static const _ausschnittePlatz = 2;
  static const _rundungenPlatz = 3;
  static const _belagPlatz = 4;
  static const _dielenlaengePlatz = 5;
  static const _kurzeStueckeVerbindenPlatz = 6;
  static const _verlegeartPlatz = 7;
  static const _verlegerichtungPlatz = 8;
  static const _verlegewinkelPlatz = 9;
  static const _ausgangseckePlatz = 10;
  static const _verschiebungXPlatz = 11;
  static const _verschiebungYPlatz = 12;
  static const _befestigungsartPlatz = 13;
  static const _terrassenartPlatz = 20;
  static const _spannweitePlatz = 21;
  static const _gefaellePlatz = 22;
  static const _hoehePlatz = 23;
  static const _eckhoehenPlatz = 24;

  @override
  bool operator ==(Object other) {
    if (other is! Planungsstand ||
        other.grundriss != grundriss ||
        other.rundungen != rundungen ||
        other.belag != belag ||
        other.dielenlaenge != dielenlaenge ||
        other.kurzeStueckeVerbinden != kurzeStueckeVerbinden ||
        other.verlegeart != verlegeart ||
        other.verlegerichtung != verlegerichtung ||
        other.verlegewinkel != verlegewinkel ||
        other.ausgangsecke != ausgangsecke ||
        other.verschiebungX != verschiebungX ||
        other.verschiebungY != verschiebungY ||
        other.befestigungsart != befestigungsart ||
        other.terrassenart != terrassenart ||
        other.spannweite != spannweite ||
        other.gefaelle != gefaelle ||
        other.hoehe != hoehe ||
        other.eckhoehen.length != eckhoehen.length ||
        other.ausschnitte.length != ausschnitte.length) {
      return false;
    }
    for (var i = 0; i < ausschnitte.length; i++) {
      if (other.ausschnitte[i] != ausschnitte[i]) return false;
    }
    for (var i = 0; i < eckhoehen.length; i++) {
      if (other.eckhoehen[i] != eckhoehen[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    grundriss,
    Object.hashAll(ausschnitte),
    rundungen,
    belag,
    dielenlaenge,
    kurzeStueckeVerbinden,
    verlegeart,
    verlegerichtung,
    verlegewinkel,
    ausgangsecke,
    verschiebungX,
    verschiebungY,
    befestigungsart,
    Object.hash(
      terrassenart,
      spannweite,
      gefaelle,
      hoehe,
      Object.hashAll(eckhoehen),
    ),
  );
}

/// vtable-Versatz eines Feldplatzes.
int _versatz(int platz) => 4 + 2 * platz;

List<Millimeter> _masse(fb.BufferContext puffer, int ort) => [
  for (final mm in const fb.ListReader<int>(
    fb.Int32Reader(),
  ).vTableGet(puffer, ort, _versatz(1), const []))
    Millimeter(mm),
];

final class _GrundrissLeser extends fb.TableReader<Grundriss> {
  const _GrundrissLeser();

  @override
  Grundriss createObject(fb.BufferContext puffer, int ort) {
    final nummer = const fb.Uint8Reader().vTableGet(
      puffer,
      ort,
      _versatz(0),
      0,
    );
    final form = Terrassenform.values.firstWhere(
      (f) => f.nummer == nummer,
      orElse: () => throw FormatException('unbekannte Terrassenform $nummer'),
    );
    return Grundriss.aus(form, _masse(puffer, ort));
  }
}

final class _AusschnittLeser extends fb.TableReader<Ausschnitt> {
  const _AusschnittLeser();

  @override
  Ausschnitt createObject(fb.BufferContext puffer, int ort) {
    final masse = _masse(puffer, ort);
    if (masse.length != 4) {
      throw FormatException('Ausschnitt braucht 4 Maße, nicht ${masse.length}');
    }
    return Ausschnitt(
      bezeichnung: const fb.StringReader().vTableGet(
        puffer,
        ort,
        _versatz(0),
        '',
      ),
      x: masse[0],
      y: masse[1],
      laenge: masse[2],
      breite: masse[3],
      form: _wert(Ausschnittform.values, (f) => f.nummer, puffer, ort, 2),
      funktion: _wert(
        Ausschnittfunktion.values,
        (f) => f.nummer,
        puffer,
        ort,
        3,
      ),
      inhalt: _wert(Ausschnittinhalt.values, (i) => i.nummer, puffer, ort, 4),
    );
  }
}

/// Eintrag aus [werte] zur Nummer im Feldplatz [platz] (fehlt er: 0).
T _wert<T>(
  List<T> werte,
  int Function(T) nummer,
  fb.BufferContext puffer,
  int ort,
  int platz,
) {
  final n = const fb.Uint8Reader().vTableGet(puffer, ort, _versatz(platz), 0);
  return werte.firstWhere(
    (w) => nummer(w) == n,
    orElse: () => throw FormatException('unbekannte Nummer $n'),
  );
}
