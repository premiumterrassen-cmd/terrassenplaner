import 'dart:typed_data';

import 'package:connectanum_router/connectanum_router.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../router/planer_router.dart';

/// Belag zur Artikelnummer des Planungsstands; `null` = Vorgabe (M5-05).
typedef Belagsuche = Artikel? Function(Artikelnummer? nummer);

/// Planungsdienst (M4-02): berechnet aus der Planung der App Umriss und
/// Kennzahlen der bearbeiteten Fläche, die Gesamtfläche (M4-14) und die
/// Dielenstücke (M5-05) – die App rechnet nichts selbst (Frontend bleibt
/// „doof“). Hin- und Rückweg als typisierte FlatBuffers (Packed PPT, #110).
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
  /// aus Dielen auch die Dielenstücke in Verlegerichtung (M5-05).
  static Berechnung berechne(Planungsstand stand, [Artikel? belag]) {
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
      dielen: [for (final d in _dielen(stand, kontur, belag)) d.umriss],
    );
  }

  /// Dielenstücke für Dielen mit Breite und Lieferlängen; Holzfliesen und
  /// unvollständige Artikel bleiben ohne (Verlegung, M5-08).
  static List<Dielenstueck> _dielen(
    Planungsstand stand,
    Kontur kontur,
    Artikel? belag,
  ) {
    final masse = belag?.abmessungen;
    if (belag?.art != Artikelart.diele) return const [];
    final breite = masse!.breite;
    final laengste = masse.laengste;
    if (breite == null || laengste == null) return const [];
    final fest = stand.dielenlaenge;
    return verlegeDielen(
      kontur,
      winkel: stand.dielenwinkel.toDouble(),
      ausgangspunkt: kontur.punkte.first,
      dielenbreite: breite,
      verlegeart: stand.verlegeart,
      // erzwungene Länge nur, solange der Belag sie liefert (M5-02)
      laengste: fest != null && masse.laengen.contains(fest) ? fest : laengste,
      verbinden: stand.kurzeStueckeVerbinden,
    );
  }

  /// Berechnung der bearbeiteten Fläche mit der Gesamtfläche aller Flächen,
  /// jede mal ihrer Häufigkeit (M4-14).
  static Berechnung berechnePlanung(
    Planung planung, [
    Belagsuche belag = _ohneBelag,
  ]) {
    var gesamt = 0.0;
    for (final f in planung.flaechen) {
      gesamt += berechne(f.stand).flaeche * f.haeufigkeit;
    }
    final aktuell = planung.aktuell;
    final b = berechne(aktuell, belag(aktuell.belag));
    return Berechnung(
      umriss: b.umriss,
      ecken: b.ecken,
      geschlossen: b.geschlossen,
      flaeche: b.flaeche,
      ausschnitte: b.ausschnitte,
      gesamtflaeche: gesamt,
      dielen: b.dielen,
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
