import 'dart:math' as math;
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
/// geprüften Höhenpunkte (M6-02), die Meldungen zum Belag (M5-10), das
/// zusätzliche UK-Holz der Nutzungsart (M6-05) samt Querstreben für die
/// Zeichnung (M6-06), die Stellfüße zur Nutzung (M6-07), die Auflager mit
/// Abstand, Höhenbereichen und Meldungen (M6-08), die Feldbreite (M6-09),
/// die UK-Verlegung mit Hölzern, Stücken und Holzvolumen (M6-10), die
/// Auflager mit Höhenzuordnung und Mengen (M6-11), die
/// Materialliste
/// (M9-03)
/// und die Stückliste mit den Farben im Plan (M9-04)
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
    final hoehen = _hoehen(stand, belag, unterkonstruktion);
    final uk = _ukVerlegung(
      stand,
      belag,
      regelwerk,
      unterkonstruktion,
      verlegung,
      hoehen,
    );
    return _mitVerlegung(
      _grundflaeche(stand, belag, unterkonstruktion, null, hoehen, uk),
      stand,
      belag,
      regelwerk,
      verlegung,
      _befestigung(stand, belag, regelwerk, verlegung, uk),
      null,
      uk,
    );
  }

  /// Befestigung der Verlegung [v] (M5-09); ohne Verlegung, ohne Regelwerk
  /// oder mit einem, das den Belag (nach einem Wechsel der Artikeldaten)
  /// nicht mehr kennt: keine.
  static Befestigungsbedarf? _befestigung(
    Planungsstand stand,
    Artikel? belag,
    Regelwerk? regelwerk,
    Belagverlegung? v, [
    UkVerlegung? uk,
  ]) {
    if (v == null) return null;
    // verlegt wird nur mit Belag
    final artikel = belag!;
    if (regelwerk?.datei[artikel.nummer] == null) return null;
    return befestigungsbedarf(
      regelwerk!,
      artikel,
      stand.befestigungsart,
      [for (final t in v.teile) ...t.stuecke],
      winkel: stand.dielenwinkel.toDouble(),
      feldbreite: stand.feldbreite,
      uk: uk,
    );
  }

  /// Geprüfte Höhenpunkte (M6-02) mit Belag und UK.
  static Hoehenpunkte _hoehen(
    Planungsstand stand,
    Artikel? belag,
    Artikel? unterkonstruktion,
  ) => pruefeHoehen(
    stand.hoehen,
    art: stand.terrassenart,
    doppelteUk: stand.doppelteUk,
    dielenstaerke: belag?.abmessungen.staerke,
    uk: ukMasse(unterkonstruktion),
  );

  /// UK-Verlegung (M6-10) – nur mit verlegtem Belag aus Holz und bekannter
  /// [uk]; Abstand ist die wirksame Feldbreite (M6-09), die Lage folgt der
  /// Drehung der UK aus den Höhenpunkten (M6-02, B-034).
  static UkVerlegung? _ukVerlegung(
    Planungsstand stand,
    Artikel? belag,
    Regelwerk? regelwerk,
    Artikel? uk,
    Belagverlegung? v,
    Hoehenpunkte hoehen,
  ) {
    final hoechste = belagFeldbreite(belag, regelwerk);
    if (v == null || uk == null || hoechste == null) return null;
    return ukVerlegung(
      stand,
      uk,
      abstand: wirksameFeldbreite(stand.feldbreite, hoechste),
      dielen: [for (final t in v.teile) ...t.stuecke],
      gedreht: hoehen.gedreht,
      regelwerk: regelwerk,
    );
  }

  static Berechnung _grundflaeche(
    Planungsstand stand, [
    Artikel? belag,
    Artikel? unterkonstruktion,
    Regelwerk? regelwerk,
    Hoehenpunkte? hoehenpunkte,
    UkVerlegung? uk,
    Auflagerbedarf? auflager,
  ]) {
    // offene Freiform (M4-08): nur der gezeichnete Linienzug
    if (stand.grundriss case FreiformGrundriss(
      :final punkte,
      geschlossen: false,
    )) {
      return Berechnung(umriss: punkte, flaeche: 0, geschlossen: false);
    }
    final kontur = stand.kontur;
    final hoehen = hoehenpunkte ?? _hoehen(stand, belag, unterkonstruktion);
    return Berechnung(
      // Bögen (Kreis) als Sehnenzug für die Zeichnung, Ecken für die Namen
      umriss: kontur.vieleck(),
      ecken: stand.grundriss.ecken,
      flaeche: kontur.flaeche,
      ausschnitte: [for (final a in stand.ausschnitte) a.kontur.punkte],
      hoehenpunkte: hoehen,
      stellfuesse: _stellfuesse(stand, regelwerk, unterkonstruktion),
      unterbau: unterbauFuer(
        stand,
        hoehen: hoehen,
        regelwerk: regelwerk,
        belag: belag,
        uk: unterkonstruktion,
        verlegung: uk,
        auflager: auflager,
      ),
    );
  }

  /// Stellfüße der [uk] für die Nutzung privat oder gewerblich (M6-07) aus
  /// dem Regelwerk; ohne UK oder wenn das Regelwerk sie nicht kennt: keine.
  static List<Stellfuss> _stellfuesse(
    Planungsstand stand,
    Regelwerk? regelwerk,
    Artikel? uk,
  ) {
    if (uk == null || regelwerk?.datei[uk.nummer] == null) return const [];
    return [
      for (final f in regelwerk!.stellfuesse(
        uk.nummer,
        gewerblich: stand.gewerblich,
      ))
        (nummer: f.nummer, titel: f.titel),
    ];
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
    Befestigungsbedarf? befestigung, [
    Ukzusatz? zusatz,
    UkVerlegung? uk,
    Auflagerbedarf? auflager,
  ]) {
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
        stellfuesse: flaeche.stellfuesse,
        unterbau: flaeche.unterbau,
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
    final ukStuecke = [
      ...?uk?.stuecke,
      ...?zusatz?.stuecke,
      ...?auflager?.stuecke,
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
      stellfuesse: flaeche.stellfuesse,
      unterbau: flaeche.unterbau,
      befestigung: befestigung,
      stueckliste: Stueckliste.aus([...planstuecke, ...ukStuecke]),
      stueckfarben: [for (final p in planstuecke) p.farbe],
      querstreben: zusatz?.streben ?? const [],
      querstrebenReihen: switch (zusatz?.reihen) {
        final reihen? when reihen > 0 => reihen,
        _ => null,
      },
    );
  }

  /// Berechnung der bearbeiteten Fläche mit den Werten der ganzen Planung
  /// (M4-14): Gesamtfläche = Summe Fläche × Häufigkeit; Dielenliste je Belag
  /// und Verschnitt über alle Flächen (M5-08) – ohne Optimierung wird jede
  /// Fläche für sich zugeschnitten und mal ihrer Häufigkeit gezählt. Ist
  /// eine Verschnittvariante gewählt (M9-01), schneidet der Server alle
  /// Stücke eines Belags über alle Flächen gemeinsam zu
  /// (`verschnittvarianten`), liefert die Varianten mit und rechnet Dielen-
  /// und Materialliste mit der gewählten.
  ///
  /// Die Materialliste (M9-03) sammelt den Bedarf aller Flächen mal ihrer
  /// Häufigkeit: Dielen je Lieferlänge, die Befestigung in Stück (erst
  /// die Summe wird verpackt) und das zusätzliche UK-Holz der Nutzungsart
  /// (M6-05, `ukZusatz`) mit der UK der Fläche. Geänderte Mengen der Planung gelten nur
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
    final bedarfe = <Materialbedarf>[];
    final optimieren = planung.verschnittvariante > 0;
    final artikelJe = <Artikelnummer, Artikel>{};
    final gruppen = <(Artikelnummer, String), Belagstuecke>{};
    late Berechnung aktuell;
    for (final (i, f) in planung.flaechen.indexed) {
      final artikel = belag(f.stand.belag);
      final verlegung = verlegeBelag(f.stand, artikel);
      final uk = unterkonstruktion(f.stand);
      final hoehen = _hoehen(f.stand, artikel, uk);
      final ukv = _ukVerlegung(
        f.stand,
        artikel,
        regelwerk,
        uk,
        verlegung,
        hoehen,
      );
      final befestigung = _befestigung(
        f.stand,
        artikel,
        regelwerk,
        verlegung,
        ukv,
      );
      final zusatz = _ukZusatz(f.stand, artikel, regelwerk, uk, verlegung, ukv);
      final auflager = _auflager(f.stand, regelwerk, uk, ukv, hoehen);
      final bearbeitet = i == planung.aktiv;
      // Höhenpunkte nur für die bearbeitete Fläche (M6-02)
      final grund = bearbeitet
          ? _grundflaeche(
              f.stand,
              artikel,
              uk,
              regelwerk,
              hoehen,
              ukv,
              auflager,
            )
          : _grundflaeche(f.stand);
      gesamt += grund.flaeche * f.haeufigkeit;
      if (verlegung != null) {
        // verlegt wird nur mit Belag
        final nummer = artikel!.nummer;
        artikelJe[nummer] = artikel;
        if (optimieren) {
          final gruppe = gruppen.putIfAbsent(
            (nummer, verlegung.lieferlaengen.join(',')),
            () => (
              belag: nummer,
              laengen: verlegung.lieferlaengen,
              stuecke: <Millimeter>[],
            ),
          );
          for (var k = 0; k < f.haeufigkeit; k++) {
            for (final t in verlegung.teile) {
              gruppe.stuecke.addAll([for (final s in t.stuecke) s.laenge]);
            }
          }
        } else {
          final liste = verlegung.dielenliste * f.haeufigkeit;
          listen.update(nummer, (l) => l + liste, ifAbsent: () => liste);
        }
        bedarfe.addAll([
          for (final b in [
            ...?befestigung?.bedarf,
            ...?ukv?.bedarf,
            ...zusatz.bedarf,
            ...?auflager?.bedarf,
          ])
            b * f.haeufigkeit,
        ]);
      }
      if (bearbeitet) {
        aktuell = _mitVerlegung(
          grund,
          f.stand,
          artikel,
          regelwerk,
          verlegung,
          befestigung,
          zusatz,
          ukv,
          auflager,
        );
      }
    }
    final varianten = verschnittvarianten(gruppen.values.toList());
    final gewaehlt = varianten.isEmpty
        ? null
        : math.min(planung.verschnittvariante, varianten.length);
    if (gewaehlt != null) listen.addAll(varianten[gewaehlt - 1].dielenlisten);
    for (final MapEntry(key: nummer, value: liste) in listen.entries) {
      bedarfe.addAll([
        for (final MapEntry(key: laenge, value: anzahl) in liste.anzahl.entries)
          Materialbedarf([artikelJe[nummer]!], anzahl, laenge: laenge),
      ]);
    }
    final summe = listen.values.fold(Dielenliste.leer, (a, b) => a + b);
    return aktuell.mitPlanung(
      gesamt,
      verschnitt: listen.isEmpty ? null : summe.verschnitt,
      dielenliste: _positionen(listen),
      materialliste: Materialliste.aus(
        bedarfe,
        mengen: mitMengen ? planung.mengen : const {},
      ),
      volumen: holzvolumen(bedarfe),
      verschnittvarianten: [
        for (final v in varianten)
          (verschnitt: v.summe.verschnitt, dielen: _positionen(v.dielenlisten)),
      ],
      verschnittvariante: gewaehlt,
    );
  }

  /// Zeilen der Dielenliste je Belag und Lieferlänge.
  static List<Lieferposition> _positionen(
    Map<Artikelnummer, Dielenliste> listen,
  ) => [
    for (final MapEntry(key: nummer, value: liste) in listen.entries)
      for (final MapEntry(key: laenge, value: anzahl) in liste.anzahl.entries)
        (belag: nummer, laenge: laenge, anzahl: anzahl),
  ];

  /// Zusätzliches UK-Holz der Nutzungsart (M6-05) – nur mit verlegtem Belag
  /// aus Holz und bekannter [uk]; der UK-Achsabstand kommt wie bei der
  /// Befestigung aus Belag und Holzart (R-C01), höchstens die gewählte
  /// Feldbreite (M6-09).
  static Ukzusatz _ukZusatz(
    Planungsstand stand,
    Artikel? belag,
    Regelwerk? regelwerk,
    Artikel? uk,
    Belagverlegung? v,
    UkVerlegung? verlegung,
  ) {
    final hoechste = belagFeldbreite(belag, regelwerk);
    if (v == null || uk == null || hoechste == null) return Ukzusatz.keiner;
    return ukZusatz(
      stand,
      uk,
      ukAbstand: wirksameFeldbreite(stand.feldbreite, hoechste),
      linien: verlegung?.lagen,
    );
  }

  /// Auflager der UK-Verlegung [v] (M6-11, `auflagerbedarf`): Abstand aus
  /// dem Regelwerk der UK (M6-08), Höhe aus den geprüften Höhenpunkten,
  /// Bereiche der Stelzfüße und Pads; ohne Verlegung oder Aufbauhöhe keine.
  static Auflagerbedarf? _auflager(
    Planungsstand stand,
    Regelwerk? regelwerk,
    Artikel? uk,
    UkVerlegung? v,
    Hoehenpunkte hoehen,
  ) {
    final aufbau = hoehen.aufbauhoehe;
    if (v == null || aufbau == null) return null;
    // mit Verlegung gibt es immer eine UK
    final artikel = uk!;
    final daten = regelwerk?.datei[artikel.nummer] == null ? null : regelwerk;
    return auflagerbedarf(
      stand,
      v,
      uk: artikel,
      abstand: auflagerabstand(
        stand,
        daten?.abstaende(artikel.nummer).stelzfuesse,
      ),
      flaeche: Hoehenflaeche(stand.grundriss.ecken, hoehen.hoehen),
      aufbauhoehe: aufbau,
      bereiche: daten == null
          ? const []
          : auflagerbereiche(
              daten,
              artikel,
              gewerblich: stand.gewerblich,
              auflagen: stand.auflagen,
            ),
      regelwerk: daten,
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
