import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;

import '../artikel/artikel.dart';
import '../artikel/einheiten.dart';
import '../geometrie/kontur.dart';
import '../geometrie/punkt.dart';
import 'anschluss.dart';
import 'auflagen.dart';
import 'ausschnitt.dart';
import 'befestigungsart.dart';
import 'grundriss.dart';
import 'nutzungsart.dart';
import 'rundungen.dart';
import 'terrassenart.dart';
import 'treppe.dart';
import 'untergrund.dart';
import 'verlegeart.dart';
import 'verlegerichtung.dart';

/// Weiterer Höhenreferenzpunkt (M7-04, Fachkonzept 3.2), z. B. ein Ablauf:
/// Lage ab Punkt A waagerecht ([x], nach rechts) und senkrecht ([y], nach
/// unten wie in der Zeichnung) – negative Werte erlaubt – und die Höhe dort
/// von Oberkante Belag bis Boden.
typedef Hoehenreferenzpunkt = ({Millimeter x, Millimeter y, Millimeter hoehe});

/// Eingaben einer Planung zu einem Zeitpunkt (M3-03) – unveränderlich, damit
/// Rückgängig exakt auf einen früheren Stand springen kann. Seit M4-02 mit
/// Grundriss, seit M4-06 mit Ausschnitten, seit M5-01 mit Belag, seit M5-02
/// mit Dielenlänge, seit M5-03 mit „kurze Stücke verbinden“, seit M5-04 mit
/// Verlegeart, seit M5-05 mit Verlegerichtung, seit M5-07 mit
/// Ausgangspunkt, seit M5-09 mit Befestigungsart, seit M6-01 mit Art der
/// Terrasse und Spannweite, seit M6-02 mit Höhenpunkten, seit M6-03 mit
/// Unterkonstruktion und UK-Länge, seit M6-04 mit Untergrund, seit M6-05
/// mit Art der Terrassennutzung, seit M6-06 mit Querstreben, seit M6-07
/// mit privater oder gewerblicher Nutzung, seit M6-08 mit Auflagen, seit
/// M6-09 mit maximaler Feldbreite, seit M7-01 mit dem Terrassenanschluss,
/// seit M7-04 mit weiteren Höhenreferenzpunkten, seit M7-05 mit Treppen;
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
    this.unterkonstruktion,
    this.ukLaenge,
    this.untergrund = Untergrund.schotter,
    this.nutzungsart = Nutzungsart.schwimmend,
    this.querstreben = false,
    this.querstrebenReihen,
    this.gewerblich = false,
    this.auflagen = Auflagen.stelzfuesseUndPads,
    this.feldbreite,
    this.anschluss = Anschluss.keiner,
    this.hoehenpunkte = const [],
    this.treppen = const [],
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
      unterkonstruktion: switch (const fb.StringReader().vTableGetNullable(
        puffer,
        wurzel,
        _versatz(_unterkonstruktionPlatz),
      )) {
        final nummer? => Artikelnummer(nummer),
        null => null,
      },
      ukLaenge: switch (const fb.Int32Reader().vTableGetNullable(
        puffer,
        wurzel,
        _versatz(_ukLaengePlatz),
      )) {
        final mm? => Millimeter(mm),
        null => null,
      },
      untergrund: Untergrund.ausNummer(
        const fb.Uint8Reader().vTableGet(
          puffer,
          wurzel,
          _versatz(_untergrundPlatz),
          0,
        ),
      ),
      nutzungsart: Nutzungsart.ausNummer(
        const fb.Uint8Reader().vTableGet(
          puffer,
          wurzel,
          _versatz(_nutzungsartPlatz),
          0,
        ),
      ),
      querstreben: const fb.BoolReader().vTableGet(
        puffer,
        wurzel,
        _versatz(_querstrebenPlatz),
        false,
      ),
      querstrebenReihen: const fb.Uint16Reader().vTableGetNullable(
        puffer,
        wurzel,
        _versatz(_querstrebenReihenPlatz),
      ),
      gewerblich: const fb.BoolReader().vTableGet(
        puffer,
        wurzel,
        _versatz(_gewerblichPlatz),
        false,
      ),
      auflagen: Auflagen.ausNummer(
        const fb.Uint8Reader().vTableGet(
          puffer,
          wurzel,
          _versatz(_auflagenPlatz),
          Auflagen.stelzfuesseUndPads.nummer,
        ),
      ),
      feldbreite: switch (const fb.Int32Reader().vTableGetNullable(
        puffer,
        wurzel,
        _versatz(_feldbreitePlatz),
      )) {
        final mm? => Millimeter(mm),
        null => null,
      },
      anschluss: switch (const _Tabellenort().vTableGetNullable(
        puffer,
        wurzel,
        _versatz(_anschlussPlatz),
      )) {
        final ort? => Anschluss.lies(puffer, ort),
        null => Anschluss.keiner,
      },
      treppen: List.unmodifiable(
        const fb.ListReader<Treppe>(_TreppenLeser())
            .vTableGet(puffer, wurzel, _versatz(_treppenPlatz), const []),
      ),
      hoehenpunkte: _liesHoehenpunkte(
        const fb.ListReader<int>(fb.Int32Reader())
            .vTableGet(puffer, wurzel, _versatz(_hoehenpunktePlatz), const []),
      ),
    );
  }

  static List<Hoehenreferenzpunkt> _liesHoehenpunkte(List<int> werte) =>
      List.unmodifiable([
        for (var i = 0; i < werte.length ~/ 3; i++)
          (
            x: Millimeter(werte[3 * i]),
            y: Millimeter(werte[3 * i + 1]),
            hoehe: Millimeter(werte[3 * i + 2]),
          ),
      ]);

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

  /// Gewählte Unterkonstruktion (M6-03, Fachkonzept 3.3); `null` = Vorgabe,
  /// die erste zum Belag passende UK der Artikeldaten. Passt sie nach einem
  /// Belagwechsel nicht mehr, gilt die Vorgabe (`Ukauswahl.gewaehlt`).
  final Artikelnummer? unterkonstruktion;

  /// Erzwungene Länge der UK (M6-03, Fachkonzept 3.4); `null` = automatisch
  /// wie bei den Dielen (R-B10). Gilt nur, solange die UK sie liefert
  /// (`ukLieferlaengen`).
  final Millimeter? ukLaenge;

  /// Untergrund (M6-04, Fachkonzept 3.5); Vorgabe Schotter. Nur Information
  /// für die Planer, ohne Wirkung auf die Berechnung (R-C07).
  final Untergrund untergrund;

  /// Art der Terrassennutzung (M6-05, Fachkonzept 3.6); Vorgabe schwimmende
  /// Verlegung. Gilt nur bei der normalen Terrasse ([wirksameNutzungsart]);
  /// die Wahl bleibt beim Wechsel der Art erhalten.
  final Nutzungsart nutzungsart;

  /// „Möchten Sie zusätzliche Querstreben hinzufügen?“ (M6-06,
  /// Fachkonzept 3.7); Vorgabe Nein.
  final bool querstreben;

  /// „Anzahl der Quertraversen“: Reihen der Querstreben, wenn [querstreben]
  /// gewählt ist; `null` = automatisch mit 60 cm Abstand (R-C03). Bleibt
  /// beim Abwählen der Querstreben für später erhalten.
  final int? querstrebenReihen;

  /// „Nutzung privat oder gewerblich“ (M6-07, Fachkonzept 3.8): `true` =
  /// gewerbliche Nutzung; Vorgabe privat (F01). Wählt die Stellfüße aus dem
  /// Regelwerk (`Regelwerk.stellfuesse`).
  final bool gewerblich;

  /// „Auflagen“ (M6-08, Fachkonzept 3.9): nur Stelzfüße oder Stelzfüße und
  /// Pads (Vorgabe wie F01). Welche Artikel in welcher Höhe gelten, sagt
  /// das Regelwerk der UK (`auflagerbereiche`).
  final Auflagen auflagen;

  /// „Maximale Feldbreite“ (M6-09, Fachkonzept 3.10): höchster Abstand der
  /// UK-Hölzer; `null` = automatisch, die höchste erlaubte (R-C01). Darüber
  /// rechnet der Server mit der höchsten (`wirksameFeldbreite`).
  final Millimeter? feldbreite;

  /// Terrassenanschluss (M7, Fachkonzept 04): Rollen der Seiten. Bei einem
  /// Grundriss mit anderer Eckenzahl beginnt er neu.
  final Anschluss anschluss;

  /// Weitere Höhenreferenzpunkte (M7-04, Fachkonzept 3.2 „Weiteren
  /// Höhenreferenzpunkt einplanen“), z. B. Abläufe. Sie wirken nur mit
  /// Gefälle ([wirksameHoehenpunkte]) und bleiben beim Ausschalten und bei
  /// neuen Maßen erhalten – ihre Lage zählt ab Punkt A.
  final List<Hoehenreferenzpunkt> hoehenpunkte;

  /// Höhenreferenzpunkte, die gelten: nur mit Gefälle.
  List<Hoehenreferenzpunkt> get wirksameHoehenpunkte =>
      gefaelle ? hoehenpunkte : const [];

  /// Bezugspunkt der Höhenreferenzpunkte: Punkt A, beim Kreis der Anfang
  /// der Kontur.
  Punkt get punktA => switch (grundriss.ecken) {
    [] => kontur.punkte.first,
    final ecken => ecken.first,
  };

  /// Ort des Höhenreferenzpunkts [p] in Planungskoordinaten.
  Punkt ortVon(Hoehenreferenzpunkt p) =>
      punktA + Punkt(p.x.mm.toDouble(), p.y.mm.toDouble());

  /// Ob [lage] als Lage ab Punkt A gilt: −300 bis 300 m nach jeder Seite.
  static bool hoehenpunktLageGueltig(Millimeter lage) =>
      lage.mm.abs() <= 300000;

  /// Mit einem weiteren Höhenreferenzpunkt in der Mitte der Fläche, so hoch
  /// wie Punkt A (M7-04); schaltet das Gefälle ein.
  Planungsstand mitNeuemHoehenpunkt() {
    final mitte = kontur.huellrechteck.mitte - punktA;
    return _mit(
      gefaelle: true,
      hoehenpunkte: List.unmodifiable([
        ...hoehenpunkte,
        (
          x: Millimeter(mitte.x.round()),
          y: Millimeter(mitte.y.round()),
          hoehe: hoehen.first,
        ),
      ]),
    );
  }

  /// Kopie, in der der Höhenreferenzpunkt [index] durch [punkt] ersetzt ist
  /// (`hoehenpunktLageGueltig`, `hoeheGueltig`).
  Planungsstand mitHoehenpunkt(int index, Hoehenreferenzpunkt punkt) {
    RangeError.checkValidIndex(index, hoehenpunkte, 'index');
    for (final lage in [punkt.x, punkt.y]) {
      if (!hoehenpunktLageGueltig(lage)) {
        throw ArgumentError.value(lage.mm, 'punkt', 'Lage außerhalb ±300 m');
      }
    }
    _pruefeHoehe(punkt.hoehe);
    return _mit(
      hoehenpunkte: List.unmodifiable([...hoehenpunkte]..[index] = punkt),
    );
  }

  /// Ohne den Höhenreferenzpunkt [index].
  Planungsstand ohneHoehenpunkt(int index) =>
      _mit(hoehenpunkte: List.unmodifiable([...hoehenpunkte]..removeAt(index)));

  /// Treppen an den Seiten (M7-05, Fachkonzept 5.1) in der Reihenfolge
  /// „Treppe 1“, „Treppe 2“ …; bei einem Grundriss mit anderer Eckenzahl
  /// beginnen sie neu wie der Anschluss.
  final List<Treppe> treppen;

  /// Mit einer neuen Treppe in den Vorgaben an der ersten freien Seite
  /// (nicht am Bauelement, ohne Rinne; sonst A — B).
  Planungsstand mitNeuerTreppe() {
    var seite = 0;
    while (seite < seitenzahl - 1 &&
        (anschluss.grenztAn(seite) || anschluss.rinneAn(seite) != null)) {
      seite++;
    }
    return _mit(treppen: List.unmodifiable([...treppen, Treppe(seite: seite)]));
  }

  /// Kopie, in der die Treppe [index] durch [treppe] ersetzt ist; ihre
  /// Seite muss es geben.
  Planungsstand mitTreppe(int index, Treppe treppe) {
    RangeError.checkValidIndex(index, treppen, 'index');
    _pruefeSeite(treppe.seite);
    return _mit(treppen: List.unmodifiable([...treppen]..[index] = treppe));
  }

  /// Ohne die Treppe [index].
  Planungsstand ohneTreppe(int index) =>
      _mit(treppen: List.unmodifiable([...treppen]..removeAt(index)));

  /// Seiten des Grundrisses für den Terrassenanschluss: Seite `i` läuft von
  /// Ecke `i` zur nächsten. Der Kreis hat keine Seiten, die offene Freiform
  /// auch nicht.
  int get seitenzahl => _seitenzahl(grundriss);

  static int _seitenzahl(Grundriss g) => switch (g) {
    FreiformGrundriss(geschlossen: false) => 0,
    _ => g.ecken.length,
  };

  /// Kopie, in der die Seite [seite] an ein Bauelement grenzt ([an]) oder
  /// nicht (M7-01, Fachkonzept 4.1).
  Planungsstand mitAngrenzend(int seite, {required bool an}) {
    _pruefeSeite(seite);
    return _mit(anschluss: anschluss.mitAngrenzend(seite, an: an));
  }

  /// Kopie, in der die Seite [seite] verblendet ist ([an]) oder nicht
  /// (M7-02, Fachkonzept 4.2); beim Kreis steht Seite 0 für „Fläche
  /// verblenden“. Eine angrenzende Seite verliert diese Rolle.
  Planungsstand mitVerblendet(int seite, {required bool an}) {
    if (grundriss is! KreisGrundriss || seite != 0) _pruefeSeite(seite);
    return _mit(anschluss: anschluss.mitVerblendet(seite, an: an));
  }

  /// Kopie mit einer Entwässerungsrinne in der Lage [lage] an der Seite
  /// [seite] (`null` = ohne, M7-03, Fachkonzept 4.3); die Seite ist dann
  /// nicht mehr verblendet, an einem Bauelement darf sie liegen.
  Planungsstand mitRinne(int seite, Rinnenlage? lage) {
    _pruefeSeite(seite);
    return _mit(anschluss: anschluss.mitRinne(seite, lage));
  }

  void _pruefeSeite(int seite) {
    if (seite < 0 || seite >= seitenzahl) {
      throw RangeError.range(seite, 0, seitenzahl - 1, 'seite');
    }
  }

  /// Ob [feldbreite] als Eingabe gilt: 10 bis 100 cm.
  static bool feldbreiteGueltig(Millimeter feldbreite) =>
      feldbreite >= const Millimeter(100) &&
      feldbreite <= const Millimeter(1000);

  /// Ob [reihen] als Anzahl der Quertraversen gilt: 1 bis 99.
  static bool querstrebenReihenGueltig(int reihen) =>
      reihen >= 1 && reihen <= 99;

  /// Die Nutzungsart, die gilt: bei Hochterrasse und vorhandener UK keine –
  /// dort entfällt 3.6 (M6-01, F28, F29).
  Nutzungsart? get wirksameNutzungsart =>
      terrassenart.mitNutzungsart ? nutzungsart : null;

  /// Ob die UK zwei Lagen hat (Lattenkreuz): bei der Hochterrasse immer,
  /// sonst mit der Nutzungsart doppelte UK (M6-05).
  bool get doppelteUk =>
      terrassenart.ukLagen == 2 ||
      wirksameNutzungsart == Nutzungsart.doppelteUk;

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
    Artikelnummer? unterkonstruktion,
    ({Millimeter? wert})? ukLaenge,
    Untergrund? untergrund,
    Nutzungsart? nutzungsart,
    bool? querstreben,
    ({int? wert})? querstrebenReihen,
    bool? gewerblich,
    Auflagen? auflagen,
    ({Millimeter? wert})? feldbreite,
    Anschluss? anschluss,
    List<Hoehenreferenzpunkt>? hoehenpunkte,
    List<Treppe>? treppen,
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
      unterkonstruktion: unterkonstruktion ?? this.unterkonstruktion,
      ukLaenge: ukLaenge == null ? this.ukLaenge : ukLaenge.wert,
      untergrund: untergrund ?? this.untergrund,
      nutzungsart: nutzungsart ?? this.nutzungsart,
      querstreben: querstreben ?? this.querstreben,
      querstrebenReihen: querstrebenReihen == null
          ? this.querstrebenReihen
          : querstrebenReihen.wert,
      gewerblich: gewerblich ?? this.gewerblich,
      auflagen: auflagen ?? this.auflagen,
      feldbreite: feldbreite == null ? this.feldbreite : feldbreite.wert,
      // andere Seiten: der Anschluss beginnt neu
      anschluss: _seitenzahl(neu) == seitenzahl
          ? anschluss ?? this.anschluss
          : Anschluss.keiner,
      hoehenpunkte: hoehenpunkte ?? this.hoehenpunkte,
      treppen: _seitenzahl(neu) == seitenzahl
          ? treppen ?? this.treppen
          : const [],
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
    anschluss: Anschluss.keiner,
    treppen: const [],
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

  /// Kopie mit anderer Unterkonstruktion (M6-03); die UK-Länge bleibt.
  Planungsstand mitUnterkonstruktion(Artikelnummer uk) =>
      _mit(unterkonstruktion: uk);

  /// Kopie mit erzwungener UK-Länge; `null` = automatisch (M6-03).
  Planungsstand mitUkLaenge(Millimeter? laenge) =>
      _mit(ukLaenge: (wert: laenge));

  /// Kopie mit anderem Untergrund (M6-04).
  Planungsstand mitUntergrund(Untergrund untergrund) =>
      _mit(untergrund: untergrund);

  /// Kopie mit anderer Art der Terrassennutzung (M6-05).
  Planungsstand mitNutzungsart(Nutzungsart art) => _mit(nutzungsart: art);

  /// Kopie mit oder ohne zusätzliche Querstreben (M6-06).
  Planungsstand mitQuerstreben(bool querstreben) =>
      _mit(querstreben: querstreben);

  /// Kopie mit fester Anzahl der Quertraversen (`querstrebenReihenGueltig`);
  /// `null` = automatisch (M6-06).
  Planungsstand mitQuerstrebenReihen(int? reihen) {
    if (reihen != null && !querstrebenReihenGueltig(reihen)) {
      throw ArgumentError.value(reihen, 'reihen', 'muss 1 bis 99 sein');
    }
    return _mit(querstrebenReihen: (wert: reihen));
  }

  /// Kopie mit privater oder gewerblicher Nutzung (M6-07).
  Planungsstand mitGewerblich(bool gewerblich) => _mit(gewerblich: gewerblich);

  /// Kopie mit anderen Auflagen (M6-08).
  Planungsstand mitAuflagen(Auflagen auflagen) => _mit(auflagen: auflagen);

  /// Kopie mit maximaler Feldbreite (`feldbreiteGueltig`); `null` =
  /// automatisch (M6-09).
  Planungsstand mitFeldbreite(Millimeter? feldbreite) {
    if (feldbreite != null && !feldbreiteGueltig(feldbreite)) {
      throw ArgumentError.value(
        feldbreite.mm,
        'feldbreite',
        'muss 100 bis 1000 mm sein',
      );
    }
    return _mit(feldbreite: (wert: feldbreite));
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
  /// (int32 mm; fehlt = Vorgabehöhe), 24: eckhoehen ([int32] mm) (M6-02),
  /// 25: unterkonstruktion (string), 26: ukLaenge (int32 mm; fehlt =
  /// automatisch) (M6-03), 80: untergrund (uint8) (M6-04), 81: nutzungsart (uint8) (M6-05), 82: querstreben (bool),
  /// 83: querstrebenReihen (uint16; fehlt = automatisch) (M6-06),
  /// 84: gewerblich (bool) (M6-07), 100: auflagen (uint8; fehlt =
  /// Stelzfüße und Pads) (M6-08), 101: feldbreite (int32 mm; fehlt =
  /// automatisch) (M6-09), 140: anschluss (Tabelle, `Anschluss.schreibe`;
  /// fehlt ohne Rollen) (M7), 141: hoehenpunkte ([int32] x, y, Höhe in mm je
  /// Punkt, M7-04), 142: treppen ([Tabelle], `Treppe.schreibe`, M7-05) }`.
  /// Plätze
  /// 14–19 gehören der Dielenverlegung (M5-08), 40–49 dem Zubehör (M8),
  /// 80–89 der Unterkonstruktion ab M6-04, 100–109 Auflagen, Feldbreite und
  /// UK-Verlegung (M6-08 bis M6-11), 140–149 dem Anschluss, den
  /// Höhenreferenzpunkten und den Treppen (M7).
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
    final ukOrt = switch (unterkonstruktion) {
      final nummer? => fbb.writeString(nummer.wert),
      null => null,
    };
    final belagOrt = switch (belag) {
      final nummer? => fbb.writeString(nummer.wert),
      null => null,
    };
    final anschlussOrt = anschluss.leer ? null : anschluss.schreibe(fbb);
    final treppenOrt = fbb.writeList([
      for (final t in treppen) t.schreibe(fbb),
    ]);
    final hoehenpunkteOrt = fbb.writeListInt32([
      for (final p in hoehenpunkte) ...[p.x.mm, p.y.mm, p.hoehe.mm],
    ]);
    fbb
      ..startTable(_treppenPlatz + 1)
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
      ..addOffset(_eckhoehenPlatz, eckhoehenOrt)
      ..addOffset(_unterkonstruktionPlatz, ukOrt)
      ..addInt32(_ukLaengePlatz, ukLaenge?.mm)
      ..addUint8(_untergrundPlatz, untergrund.nummer)
      ..addUint8(_nutzungsartPlatz, nutzungsart.nummer)
      ..addBool(_querstrebenPlatz, querstreben)
      ..addUint16(_querstrebenReihenPlatz, querstrebenReihen)
      ..addBool(_gewerblichPlatz, gewerblich)
      ..addUint8(_auflagenPlatz, auflagen.nummer)
      ..addInt32(_feldbreitePlatz, feldbreite?.mm)
      ..addOffset(_anschlussPlatz, anschlussOrt)
      ..addOffset(_hoehenpunktePlatz, hoehenpunkteOrt)
      ..addOffset(_treppenPlatz, treppenOrt);
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
  static const _unterkonstruktionPlatz = 25;
  static const _ukLaengePlatz = 26;
  static const _untergrundPlatz = 80;
  static const _nutzungsartPlatz = 81;
  static const _querstrebenPlatz = 82;
  static const _querstrebenReihenPlatz = 83;
  static const _gewerblichPlatz = 84;
  static const _auflagenPlatz = 100;
  static const _feldbreitePlatz = 101;
  static const _anschlussPlatz = 140;
  static const _hoehenpunktePlatz = 141;
  static const _treppenPlatz = 142;

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
        other.unterkonstruktion != unterkonstruktion ||
        other.ukLaenge != ukLaenge ||
        other.untergrund != untergrund ||
        other.nutzungsart != nutzungsart ||
        other.querstreben != querstreben ||
        other.querstrebenReihen != querstrebenReihen ||
        other.gewerblich != gewerblich ||
        other.auflagen != auflagen ||
        other.feldbreite != feldbreite ||
        other.anschluss != anschluss ||
        other.hoehenpunkte.length != hoehenpunkte.length ||
        other.treppen.length != treppen.length ||
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
    for (var i = 0; i < hoehenpunkte.length; i++) {
      if (other.hoehenpunkte[i] != hoehenpunkte[i]) return false;
    }
    for (var i = 0; i < treppen.length; i++) {
      if (other.treppen[i] != treppen[i]) return false;
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
      unterkonstruktion,
      ukLaenge,
      untergrund,
      nutzungsart,
      querstreben,
      querstrebenReihen,
      gewerblich,
      auflagen,
      feldbreite,
      anschluss,
      Object.hashAll(hoehenpunkte),
      Object.hashAll(treppen),
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

final class _TreppenLeser extends fb.TableReader<Treppe> {
  const _TreppenLeser();

  @override
  Treppe createObject(fb.BufferContext puffer, int ort) =>
      Treppe.lies(puffer, ort);
}

/// Liest nur den Ort einer Tabelle – die Felder liest der Aufrufer.
final class _Tabellenort extends fb.TableReader<int> {
  const _Tabellenort();

  @override
  int createObject(fb.BufferContext puffer, int ort) => ort;
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
