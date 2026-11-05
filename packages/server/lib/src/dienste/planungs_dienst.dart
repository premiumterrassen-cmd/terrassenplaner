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
/// Dielenstücke (M5-05) mit Nummern, Dielenliste und Verschnitt (M5-08),
/// den Ausgangspunkt der Verlegung (M5-07), die Befestigung (M5-09), die
/// geprüften Höhenpunkte (M6-02), die Meldungen zum Belag (M5-10), die
/// Mengen im Zubehör (M8-02, M8-03), die
/// Materialliste (M9-03) und die Stückliste mit den Farben im Plan (M9-04)
/// – die App rechnet nichts selbst (Frontend bleibt „doof“). Hin- und
/// Rückweg als typisierte FlatBuffers (Packed PPT, #110).
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
  /// aus Dielen oder Holzfliesen auch die nummerierten Stücke aller
  /// Teilflächen (`verlegeBelag`, M5-05, M5-08) ab dem verschobenen
  /// Ausgangspunkt, die Grenzen der Verschiebung und ob kurze Zuschnitte
  /// entstehen (M5-07). Mit dem [regelwerk] auch die Befestigung (M5-09).
  /// Die Höhenpunkte prüft der Dienst gegen Belag und [unterkonstruktion]
  /// (M6-02, `pruefeHoehen`).
  static Berechnung berechne(
    Planungsstand stand, [
    Artikel? belag,
    Regelwerk? regelwerk,
    Artikel? unterkonstruktion,
  ]) {
    final verlegung = verlegeBelag(stand, belag);
    final befestigung = _befestigung(stand, belag, regelwerk, verlegung);
    return _mitVerlegung(
      _grundflaeche(stand, belag, unterkonstruktion),
      stand,
      belag,
      regelwerk,
      verlegung,
      befestigung,
      _zubehoer(stand, belag, regelwerk, verlegung, befestigung),
    );
  }

  /// Befestigung der Verlegung [v] (M5-09); ohne Verlegung, ohne Regelwerk
  /// oder mit einem, das den Belag (nach einem Wechsel der Artikeldaten)
  /// nicht mehr kennt: keine.
  static Befestigungsbedarf? _befestigung(
    Planungsstand stand,
    Artikel? belag,
    Regelwerk? regelwerk,
    Belagverlegung? v,
  ) {
    if (v == null) return null;
    // verlegt wird nur mit Belag
    final artikel = belag!;
    if (regelwerk?.datei[artikel.nummer] == null) return null;
    return befestigungsbedarf(regelwerk!, artikel, stand.befestigungsart, [
      for (final t in v.teile) ...t.stuecke,
    ], winkel: stand.dielenwinkel.toDouble());
  }

  static Berechnung _grundflaeche(
    Planungsstand stand, [
    Artikel? belag,
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
    return Berechnung(
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
  }

  /// Breite und Stärke einer UK; `null`, wenn eins fehlt (z. B. Alu-UK
  /// ohne Maße in den Artikeldaten).
  static UkMasse? ukMasse(Artikel? uk) =>
      switch ((uk?.abmessungen.breite, uk?.abmessungen.staerke)) {
        (final a?, final b?) => (a: a, b: b),
        _ => null,
      };

  /// [flaeche] mit den Stücken der Verlegung [v] und den Meldungen zum
  /// Belag (M5-10, auch ohne Verlegung); die Befestigung zählt die Punkte
  /// über alle Teilflächen.
  static Berechnung _mitVerlegung(
    Berechnung flaeche,
    Planungsstand stand,
    Artikel? belag,
    Regelwerk? regelwerk,
    Belagverlegung? v,
    Befestigungsbedarf? befestigung,
    List<Zubehoerposition> zubehoer,
  ) {
    final meldungen = belagmeldungen(stand, belag, v, regelwerk: regelwerk);
    if (v == null) {
      return Berechnung(
        umriss: flaeche.umriss,
        ecken: flaeche.ecken,
        geschlossen: flaeche.geschlossen,
        flaeche: flaeche.flaeche,
        ausschnitte: flaeche.ausschnitte,
        belagmeldungen: meldungen,
        hoehenpunkte: flaeche.hoehenpunkte,
        zubehoer: zubehoer,
      );
    }
    final stuecke = [for (final t in v.teile) ...t.stuecke];
    // verlegt wird nur mit Belag; Stückliste und Farben im Plan (M9-04)
    final artikel = belag!;
    final planstuecke = [
      for (final s in stuecke)
        Planstueck(
          artikel.nummer,
          artikel.titel,
          s.laenge,
          ganzeLaenge: v.laengste,
        ),
    ];
    return Berechnung(
      umriss: flaeche.umriss,
      ecken: flaeche.ecken,
      flaeche: flaeche.flaeche,
      ausschnitte: flaeche.ausschnitte,
      belagmeldungen: meldungen,
      dielen: [for (final s in stuecke) s.umriss],
      nummern: [for (final t in v.teile) ...t.nummern],
      ausgangspunkt: v.ausgangspunkt,
      grenzeLinksRechts: v.grenzen.x,
      grenzeObenUnten: v.grenzen.y,
      kurzeZuschnitte: v.kurzeZuschnitte,
      hoehenpunkte: flaeche.hoehenpunkte,
      befestigung: befestigung,
      stueckliste: Stueckliste.aus(planstuecke),
      stueckfarben: [for (final p in planstuecke) p.farbe],
      zubehoer: zubehoer,
    );
  }

  /// Zeilen im Zubehör der Fläche [stand] (M8-02) samt Pflichtzubehör
  /// (M8-03): was der Belag (je Diele), die Befestigung, das berechnete und
  /// das eingegebene Zubehör laut Artikeldaten benötigen. Ohne Verlegung
  /// oder Befestigung nur die Eingaben und deren Pflichtzubehör.
  static List<Zubehoerposition> _zubehoer(
    Planungsstand stand,
    Artikel? belag,
    Regelwerk? regelwerk,
    Belagverlegung? v,
    Befestigungsbedarf? befestigung,
  ) {
    final berechnet = befestigung == null
        ? const <Artikelnummer, int>{}
        : berechnetesZubehoer(regelwerk!, belag!, befestigung, [
            for (final t in v!.teile) ...t.stuecke,
          ], winkel: stand.dielenwinkel.toDouble());
    final verwendet = <Artikelnummer, int>{
      if ((belag, v) case (final b?, final verlegung?))
        b.nummer: verlegung.dielenliste.anzahl.values.fold(0, (a, n) => a + n),
      ...berechnet,
      ...stand.zubehoer,
    };
    return zubehoerpositionen(
      berechnet,
      stand.zubehoer,
      pflicht: regelwerk == null
          ? const {}
          : pflichtzubehoer(regelwerk, verwendet),
    );
  }

  /// Bedarf der Materialliste (M9-03) aus Befestigung und Zubehör einer
  /// Fläche: Die Befestigung geht in Stück ein (verpackt wird die Summe der
  /// Planung), das übrige Zubehör mit seiner Menge „Tatsächlich“ in
  /// Verkaufseinheiten – Werkzeug einmal je Planung. Hat der Kunde im
  /// Zubehör eine Menge der Befestigung geändert, gelten für die Fläche die
  /// Zubehörmengen auch für die Befestigung.
  static List<Materialbedarf> _bedarf(
    Planungsstand stand,
    Regelwerk? regelwerk,
    Befestigungsbedarf? befestigung,
    List<Zubehoerposition> zubehoer,
  ) {
    final mittel = {
      for (final m in befestigung?.mittel ?? const <Befestigungsposition>[])
        m.nummer,
    };
    final geaendert = mittel.any(stand.zubehoer.containsKey);
    return [
      if (!geaendert) ...?befestigung?.bedarf,
      for (final z in zubehoer)
        if (regelwerk?.datei[z.nummer]?.artikel case final a?
            when z.menge > 0 && (geaendert || !mittel.contains(z.nummer)))
          Materialbedarf(
            [a],
            z.menge * a.einheit.inhalt.ceil(),
            jePlanung: a.art == Artikelart.werkzeug,
          ),
    ];
  }

  /// Berechnung der bearbeiteten Fläche mit den Werten der ganzen Planung
  /// (M4-14): Gesamtfläche = Summe Fläche × Häufigkeit; Dielenliste je Belag
  /// und Verschnitt über alle Flächen (M5-08) – jede Fläche wird für sich
  /// zugeschnitten und mal ihrer Häufigkeit gezählt.
  ///
  /// Die Materialliste (M9-03) sammelt den Bedarf aller Flächen mal ihrer
  /// Häufigkeit: Dielen je Lieferlänge, die Befestigung in Stück (erst
  /// die Summe wird verpackt) und das Zubehör (M8-02, M8-03); dazu die
  /// Freidielen der ganzen Planung (M8-04). Geänderte Mengen der Planung gelten nur
  /// [mitMengen] – vom Server nur für Mitarbeiter gesetzt
  /// ([darfMengenAendern]).
  static Berechnung berechnePlanung(
    Planung planung, [
    Belagsuche belag = _ohneBelag,
    Regelwerk? regelwerk,
    bool mitMengen = false,
    Unterkonstruktionssuche unterkonstruktion = _ohneUnterkonstruktion,
  ]) {
    var gesamt = 0.0;
    final listen = <Artikelnummer, Dielenliste>{};
    final belaege = <Artikelnummer, Artikel>{};
    final bedarfe = <Materialbedarf>[];
    late Berechnung aktuell;
    for (final (i, f) in planung.flaechen.indexed) {
      final artikel = belag(f.stand.belag);
      final verlegung = verlegeBelag(f.stand, artikel);
      final befestigung = _befestigung(f.stand, artikel, regelwerk, verlegung);
      final zubehoer = _zubehoer(
        f.stand,
        artikel,
        regelwerk,
        verlegung,
        befestigung,
      );
      final bearbeitet = i == planung.aktiv;
      // Höhenpunkte nur für die bearbeitete Fläche (M6-02)
      final grund = bearbeitet
          ? _grundflaeche(f.stand, artikel, unterkonstruktion(f.stand))
          : _grundflaeche(f.stand);
      gesamt += grund.flaeche * f.haeufigkeit;
      if (verlegung != null) {
        final liste = verlegung.dielenliste * f.haeufigkeit;
        listen.update(artikel!.nummer, (l) => l + liste, ifAbsent: () => liste);
        belaege[artikel.nummer] = artikel;
        bedarfe.addAll([
          for (final MapEntry(key: laenge, value: anzahl)
              in liste.anzahl.entries)
            Materialbedarf([artikel], anzahl, laenge: laenge),
        ]);
      }
      bedarfe.addAll([
        for (final b in _bedarf(f.stand, regelwerk, befestigung, zubehoer))
          b * f.haeufigkeit,
      ]);
      if (bearbeitet) {
        aktuell = _mitVerlegung(
          grund,
          f.stand,
          artikel,
          regelwerk,
          verlegung,
          befestigung,
          zubehoer,
        );
      }
    }
    final summe = listen.values.fold(Dielenliste.leer, (a, b) => a + b);
    final dielenliste = [
      for (final MapEntry(key: nummer, value: liste) in listen.entries)
        for (final MapEntry(key: laenge, value: anzahl) in liste.anzahl.entries)
          (belag: nummer, laenge: laenge, anzahl: anzahl),
    ];
    // Freidielen der ganzen Planung (M8-04, R-B09, B-228): eigene Position
    // mit Preis 0, einmal je Planung
    final frei = freidielenposition(
      dielenliste,
      istDiele: (n) => belaege[n]!.art == Artikelart.diele,
    );
    return aktuell.mitPlanung(
      gesamt,
      verschnitt: listen.isEmpty ? null : summe.verschnitt,
      dielenliste: dielenliste,
      materialliste: Materialliste.aus([
        ...bedarfe,
        if (frei != null)
          Materialbedarf(
            [belaege[frei.belag]!],
            frei.anzahl,
            laenge: frei.laenge,
            zusatz: Materialzusatz.freidiele,
          ),
      ], mengen: mitMengen ? planung.mengen : const {}),
    );
  }

  /// **Stelle für die Mitarbeiter-Anmeldung (M9-10):** Geänderte Mengen der
  /// Materialliste (Mitarbeiter-Ansicht, Fachkonzept 08) übernimmt der
  /// Server nur von angemeldeten Mitarbeitern (Rolle `mitarbeiter` aus den
  /// Aufrufdetails). Bis es die Anmeldung gibt, rechnet er für jeden
  /// Aufrufer mit den berechneten Mengen.
  static bool darfMengenAendern(LazyInvocationPayload aufruf) => false;

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
            darfMengenAendern(aufruf),
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
