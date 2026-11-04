import 'dart:typed_data';

import 'package:connectanum_router/connectanum_router.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../router/planer_router.dart';

/// Belag zur Artikelnummer des Planungsstands; `null` = Vorgabe (M5-05).
typedef Belagsuche = Artikel? Function(Artikelnummer? nummer);

/// Regelwerk der aktuellen Artikeldaten (M5-09); `null` = keins.
typedef Regelwerksuche = Regelwerk? Function();

/// Unterkonstruktion zum Planungsstand (M6-02); `null` = keine bekannt.
typedef Unterkonstruktionssuche = Artikel? Function(Planungsstand stand);

/// Planungsdienst (M4-02): berechnet aus der Planung der App Umriss und
/// Kennzahlen der bearbeiteten Fläche, die Gesamtfläche (M4-14), die
/// Dielenstücke (M5-05), den Ausgangspunkt der Verlegung (M5-07) und die
/// Befestigung (M5-09) und die geprüften Höhenpunkte (M6-02) – die App
/// rechnet nichts selbst (Frontend bleibt
/// „doof“). Hin- und Rückweg als typisierte FlatBuffers (Packed PPT, #110).
class PlanungsDienst {
  PlanungsDienst._(this._sitzung);

  /// [belag] liefert den Belag aus den aktuellen Artikeldaten; ohne ihn
  /// (oder ohne Artikeldatei) rechnet der Dienst ohne Dielen. [regelwerk]
  /// liefert die Befestigungsartikel; ohne es keine Befestigung.
  /// [unterkonstruktion] liefert die UK für die Prüfung der Höhenpunkte;
  /// ohne sie bleiben die Höhen ungeprüft.
  static Future<PlanungsDienst> starte(
    PlanerRouter router, {
    Belagsuche belag = _ohneBelag,
    Regelwerksuche regelwerk = _ohneRegelwerk,
    Unterkonstruktionssuche unterkonstruktion = _ohneUnterkonstruktion,
  }) async {
    final sitzung = await router.dienstSitzung(sitzungId);
    (await sitzung.register(WampNamen.planungBerechnen)).onLazyInvokePayload(
      (aufruf) => _berechne(aufruf, belag, regelwerk, unterkonstruktion),
    );
    return PlanungsDienst._(sitzung);
  }

  static Artikel? _ohneBelag(Artikelnummer? nummer) => null;

  static Regelwerk? _ohneRegelwerk() => null;

  static Artikel? _ohneUnterkonstruktion(Planungsstand stand) => null;

  /// authid der internen Dienst-Sitzung.
  static const sitzungId = 'planungs-dienst';

  /// Kennung typisierter Nutzlasten des Planers.
  static final ppt = YieldOptions(
    pptScheme: WampNamen.pptSchema,
    pptSerializer: WampNamen.pptSerializer,
  );

  /// Umriss, Ausschnitte und Fläche des Grundrisses; wie im alten Planer
  /// ist die Fläche die Außenfläche (Fachkonzept 1.4). Mit einem [belag]
  /// aus Dielen auch die Dielenstücke in Verlegerichtung (M5-05) ab dem
  /// verschobenen Ausgangspunkt, die Grenzen der Verschiebung und ob kurze
  /// Zuschnitte entstehen (M5-07). Mit dem [regelwerk] auch die Befestigung
  /// der Dielen (M5-09). Die Höhenpunkte prüft der Dienst gegen Belag und
  /// [unterkonstruktion] (M6-02, `pruefeHoehen`).
  static Berechnung berechne(
    Planungsstand stand, [
    Artikel? belag,
    Regelwerk? regelwerk,
    Artikel? unterkonstruktion,
  ]) {
    // offene Freiform (M4-08): nur der gezeichnete Linienzug
    if (stand.grundriss case FreiformGrundriss(
      :final punkte,
      geschlossen: false,
    )) {
      return Berechnung(umriss: punkte, flaeche: 0, geschlossen: false);
    }
    final kontur = stand.kontur;
    final flaeche = Berechnung(
      // Bögen (Kreis) als Sehnenzug für die Zeichnung, Ecken für die Namen
      umriss: kontur.vieleck(),
      ecken: stand.grundriss.ecken,
      flaeche: kontur.flaeche,
      ausschnitte: [for (final a in stand.ausschnitte) a.kontur.punkte],
      hoehenpunkte: pruefeHoehen(
        stand.hoehen,
        art: stand.terrassenart,
        dielenstaerke: belag?.abmessungen.staerke,
        uk: ukMasse(unterkonstruktion),
      ),
    );
    final masse = belag?.abmessungen;
    if (belag?.art != Artikelart.diele) return flaeche;
    final breite = masse!.breite;
    final laengste = masse.laengste;
    // Holzfliesen und unvollständige Artikel bleiben ohne (M5-08)
    if (breite == null || laengste == null) return flaeche;
    final fest = stand.dielenlaenge;
    return _verlegt(
      flaeche,
      stand,
      belag!,
      regelwerk,
      dielenbreite: breite,
      // erzwungene Länge nur, solange der Belag sie liefert (M5-02)
      laengste: fest != null && masse.laengen.contains(fest) ? fest : laengste,
    );
  }

  /// [flaeche] mit den Dielenstücken ab der gewählten Ecke plus
  /// Verschiebung; eine Verschiebung über die Grenze hinaus (etwa nach einem
  /// Wechsel auf einen schmaleren Belag) wird auf die Grenze begrenzt.
  static Berechnung _verlegt(
    Berechnung flaeche,
    Planungsstand stand,
    Artikel belag,
    Regelwerk? regelwerk, {
    required Millimeter dielenbreite,
    required Millimeter laengste,
  }) {
    final kontur = stand.kontur;
    final winkel = stand.dielenwinkel.toDouble();
    final grenzen = verschiebungsgrenzen(
      kontur,
      winkel: winkel,
      dielenbreite: dielenbreite,
      laengste: laengste,
    );
    final ausgangspunkt =
        stand.ausgangspunkt +
        Punkt(
          _begrenzt(stand.verschiebungX, grenzen.x),
          _begrenzt(stand.verschiebungY, grenzen.y),
        );
    final stuecke = verlegeDielen(
      kontur,
      winkel: winkel,
      ausgangspunkt: ausgangspunkt,
      dielenbreite: dielenbreite,
      verlegeart: stand.verlegeart,
      laengste: laengste,
      verbinden: stand.kurzeStueckeVerbinden,
    );
    return Berechnung(
      umriss: flaeche.umriss,
      ecken: flaeche.ecken,
      flaeche: flaeche.flaeche,
      ausschnitte: flaeche.ausschnitte,
      dielen: [for (final d in stuecke) d.umriss],
      ausgangspunkt: ausgangspunkt,
      grenzeLinksRechts: grenzen.x,
      grenzeObenUnten: grenzen.y,
      kurzeZuschnitte: stuecke.any((d) => d.kurzerZuschnitt),
      hoehenpunkte: flaeche.hoehenpunkte,
      // ohne Regelwerk oder mit einem, das den Belag (nach einem Wechsel der
      // Artikeldaten) nicht mehr kennt: keine Befestigung
      befestigung: regelwerk?.datei[belag.nummer] == null
          ? null
          : befestigungsbedarf(
              regelwerk!,
              belag,
              stand.befestigungsart,
              stuecke,
              winkel: winkel,
            ),
    );
  }

  /// Breite und Stärke einer UK; `null`, wenn eins fehlt (z. B. Alu-UK
  /// ohne Maße in den Artikeldaten).
  static UkMasse? ukMasse(Artikel? uk) =>
      switch ((uk?.abmessungen.breite, uk?.abmessungen.staerke)) {
        (final a?, final b?) => (a: a, b: b),
        _ => null,
      };

  static double _begrenzt(Millimeter wert, Millimeter grenze) =>
      wert.mm.clamp(-grenze.mm, grenze.mm).toDouble();

  /// Berechnung der bearbeiteten Fläche mit der Gesamtfläche aller Flächen,
  /// jede mal ihrer Häufigkeit (M4-14).
  static Berechnung berechnePlanung(
    Planung planung, [
    Belagsuche belag = _ohneBelag,
    Regelwerk? regelwerk,
    Unterkonstruktionssuche unterkonstruktion = _ohneUnterkonstruktion,
  ]) {
    var gesamt = 0.0;
    for (final f in planung.flaechen) {
      gesamt += berechne(f.stand).flaeche * f.haeufigkeit;
    }
    final aktuell = planung.aktuell;
    return berechne(
      aktuell,
      belag(aktuell.belag),
      regelwerk,
      unterkonstruktion(aktuell),
    ).mitGesamtflaeche(gesamt);
  }

  static void _berechne(
    LazyInvocationPayload aufruf,
    Belagsuche belag,
    Regelwerksuche regelwerk,
    Unterkonstruktionssuche unterkonstruktion,
  ) {
    try {
      final planung = Planung.ausBytes(_bytes(aufruf));
      aufruf.respondWith(
        lazyPayload: verpacke(
          berechnePlanung(
            planung,
            belag,
            regelwerk(),
            unterkonstruktion,
          ).zuBytes(),
        ),
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
