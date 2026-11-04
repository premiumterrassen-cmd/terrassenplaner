import 'dart:typed_data';

import 'package:connectanum_router/connectanum_router.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../router/planer_router.dart';

/// Belag zur Artikelnummer des Planungsstands; `null` = Vorgabe (M5-05).
typedef Belagsuche = Artikel? Function(Artikelnummer? nummer);

/// Planungsdienst (M4-02): berechnet aus der Planung der App Umriss und
/// Kennzahlen der bearbeiteten Fläche, die Gesamtfläche (M4-14), die
/// Dielenstücke (M5-05) mit Nummern, Dielenliste und Verschnitt (M5-08) und
/// den Ausgangspunkt der Verlegung (M5-07) – die App rechnet nichts selbst
/// (Frontend bleibt „doof“). Hin- und Rückweg als typisierte FlatBuffers (Packed PPT, #110).
class PlanungsDienst {
  PlanungsDienst._(this._sitzung);

  /// [belag] liefert den Belag aus den aktuellen Artikeldaten; ohne ihn
  /// (oder ohne Artikeldatei) rechnet der Dienst ohne Dielen.
  static Future<PlanungsDienst> starte(
    PlanerRouter router, {
    Belagsuche belag = _ohneBelag,
  }) async {
    final sitzung = await router.dienstSitzung(sitzungId);
    (await sitzung.register(WampNamen.planungBerechnen))
        .onLazyInvokePayload((aufruf) => _berechne(aufruf, belag));
    return PlanungsDienst._(sitzung);
  }

  static Artikel? _ohneBelag(Artikelnummer? nummer) => null;

  /// authid der internen Dienst-Sitzung.
  static const sitzungId = 'planungs-dienst';

  /// Kennung typisierter Nutzlasten des Planers.
  static final ppt = YieldOptions(
    pptScheme: WampNamen.pptSchema,
    pptSerializer: WampNamen.pptSerializer,
  );

  /// Umriss, Ausschnitte und Fläche des Grundrisses; wie im alten Planer
  /// ist die Fläche die Außenfläche (Fachkonzept 1.4). Mit einem [belag]
  /// aus Dielen oder Holzfliesen auch die nummerierten Stücke aller
  /// Teilflächen (`verlegeBelag`, M5-05, M5-08) ab dem verschobenen
  /// Ausgangspunkt, die Grenzen der Verschiebung und ob kurze Zuschnitte
  /// entstehen (M5-07).
  static Berechnung berechne(Planungsstand stand, [Artikel? belag]) =>
      _mitVerlegung(_grundflaeche(stand), verlegeBelag(stand, belag));

  static Berechnung _grundflaeche(Planungsstand stand) {
    // offene Freiform (M4-08): nur der gezeichnete Linienzug
    if (stand.grundriss case FreiformGrundriss(
      :final punkte,
      geschlossen: false,
    )) {
      return Berechnung(umriss: punkte, flaeche: 0, geschlossen: false);
    }
    final kontur = stand.kontur;
    return Berechnung(
      // Bögen (Kreis) als Sehnenzug für die Zeichnung, Ecken für die Namen
      umriss: kontur.vieleck(),
      ecken: stand.grundriss.ecken,
      flaeche: kontur.flaeche,
      ausschnitte: [for (final a in stand.ausschnitte) a.kontur.punkte],
    );
  }

  static Berechnung _mitVerlegung(Berechnung flaeche, Belagverlegung? v) {
    if (v == null) return flaeche;
    return Berechnung(
      umriss: flaeche.umriss,
      ecken: flaeche.ecken,
      flaeche: flaeche.flaeche,
      ausschnitte: flaeche.ausschnitte,
      dielen: [
        for (final t in v.teile)
          for (final s in t.stuecke) s.umriss,
      ],
      nummern: [for (final t in v.teile) ...t.nummern],
      ausgangspunkt: v.ausgangspunkt,
      grenzeLinksRechts: v.grenzen.x,
      grenzeObenUnten: v.grenzen.y,
      kurzeZuschnitte: v.kurzeZuschnitte,
    );
  }

  /// Berechnung der bearbeiteten Fläche mit den Werten der ganzen Planung
  /// (M4-14): Gesamtfläche = Summe Fläche × Häufigkeit; Dielenliste je Belag
  /// und Verschnitt über alle Flächen (M5-08) – jede Fläche wird für sich
  /// zugeschnitten und mal ihrer Häufigkeit gezählt.
  static Berechnung berechnePlanung(
    Planung planung, [
    Belagsuche belag = _ohneBelag,
  ]) {
    var gesamt = 0.0;
    final listen = <Artikelnummer, Dielenliste>{};
    late Berechnung aktuell;
    for (final (i, f) in planung.flaechen.indexed) {
      final artikel = belag(f.stand.belag);
      final verlegung = verlegeBelag(f.stand, artikel);
      final berechnung = _mitVerlegung(_grundflaeche(f.stand), verlegung);
      gesamt += berechnung.flaeche * f.haeufigkeit;
      if (verlegung != null) {
        final liste = verlegung.dielenliste * f.haeufigkeit;
        listen.update(artikel!.nummer, (l) => l + liste, ifAbsent: () => liste);
      }
      if (i == planung.aktiv) aktuell = berechnung;
    }
    final summe = listen.values.fold(Dielenliste.leer, (a, b) => a + b);
    return aktuell.mitPlanung(
      gesamt,
      verschnitt: listen.isEmpty ? null : summe.verschnitt,
      dielenliste: [
        for (final MapEntry(key: nummer, value: liste) in listen.entries)
          for (final MapEntry(key: laenge, value: anzahl)
              in liste.anzahl.entries)
            (belag: nummer, laenge: laenge, anzahl: anzahl),
      ],
    );
  }

  static void _berechne(LazyInvocationPayload aufruf, Belagsuche belag) {
    try {
      final planung = Planung.ausBytes(_bytes(aufruf));
      aufruf.respondWith(
        lazyPayload: verpacke(berechnePlanung(planung, belag).zuBytes()),
        options: ppt,
      );
    } on Object catch (fehler) {
      aufruf.respondWith(
        isError: true,
        errorUri: WampNamen.planungUngueltig,
        arguments: ['$fehler'],
      );
    }
  }

  static Uint8List _bytes(LazyInvocationPayload aufruf) {
    if (aufruf.pptScheme != WampNamen.pptSchema) {
      throw const FormatException('keine typisierte Planung');
    }
    return aufruf.payload.packedPayloadBytes!;
  }

  /// FlatBuffer als Packed-PPT-Nutzlast.
  static LazyMessagePayload verpacke(Uint8List bytes) =>
      LazyMessagePayload.packed(
        encoding: LazyPayloadEncoding.flatbuffers,
        packedPayloadBytes: bytes,
        packedPayloadDecoder: (b) => (arguments: [b], argumentsKeywords: null),
      );

  final RouterSession _sitzung;

  Future<void> stoppe() => _sitzung.close();
}
