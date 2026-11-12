import 'dart:math' as math;
import 'dart:typed_data';

import 'package:connectanum_router/connectanum_router.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../router/planer_router.dart';
import '../zugriff/rollen.dart';
import 'rechenwerk.dart';

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
/// Auflager mit Höhenzuordnung und Mengen (M6-11), die Mengen im Zubehör
/// (M8-02, M8-03) samt Freidielen (M8-04) und optionalem Bohrsenker
/// (Planungskern v6 Regel 4.5), den Terrassenanschluss (M7),
/// die Materialliste (M9-03) mit der gewählten Verschnittvariante (M9-01)
/// und die Stückliste mit den Farben im Plan (M9-04)
/// – die App rechnet nichts selbst (Frontend bleibt „doof“). Hin- und
/// Rückweg als typisierte FlatBuffers (Packed PPT, #110).
class PlanungsDienst {
  PlanungsDienst._(this._sitzung);

  /// [belag] liefert den Belag aus den aktuellen Artikeldaten; ohne ihn
  /// (oder ohne Artikeldatei) rechnet der Dienst ohne Dielen. [regelwerk]
  /// liefert die Befestigungsartikel; ohne es keine Befestigung.
  /// [unterkonstruktion] liefert die UK für die Prüfung der Höhenpunkte;
  /// ohne sie bleiben die Höhen ungeprüft. Gerechnet wird im [rechenwerk]
  /// (M10-02), nicht im Router-Isolate.
  static Future<PlanungsDienst> starte(
    PlanerRouter router, {
    Belagsuche belag = _ohneBelag,
    Regelwerksuche regelwerk = _ohneRegelwerk,
    Unterkonstruktionssuche unterkonstruktion = _ohneUnterkonstruktion,
    Rechenwerk? rechenwerk,
  }) async {
    final werk = rechenwerk ?? Rechenwerk();
    final sitzung = await router.dienstSitzung(sitzungId);
    (await sitzung.register(
      WampNamen.planungBerechnen,
      // Die Rolle des Aufrufers entscheidet über geänderte Mengen (M9-10).
      options: RegisterOptions(discloseCaller: true),
    )).onLazyInvokePayload(
      (aufruf) => _berechne(aufruf, werk, belag, regelwerk, unterkonstruktion),
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
    final befestigung = _befestigung(stand, belag, regelwerk, verlegung, uk);
    return _mitVerlegung(
      _grundflaeche(stand, belag, unterkonstruktion, null, hoehen, uk),
      stand,
      belag,
      regelwerk,
      verlegung,
      befestigung,
      _zubehoer(stand, belag, regelwerk, verlegung, befestigung, uk),
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

  /// Geprüfte Höhenpunkte (M6-02) mit Belag und UK: die Ecken, dann die
  /// weiteren Höhenreferenzpunkte (M7-04, nur mit Gefälle).
  static Hoehenpunkte _hoehen(
    Planungsstand stand,
    Artikel? belag,
    Artikel? unterkonstruktion,
  ) => pruefeHoehen(
    [...stand.hoehen, for (final p in stand.wirksameHoehenpunkte) p.hoehe],
    art: stand.terrassenart,
    doppelteUk: stand.doppelteUk,
    dielenstaerke: belag?.abmessungen.staerke,
    uk: ukMasse(unterkonstruktion),
  );

  /// UK-Verlegung (M6-10) – nur mit verlegtem Belag aus Holz und bekannter
  /// [uk]; Abstand ist die wirksame Feldbreite (M6-09), die Lage folgt der
  /// Drehung der UK aus den Höhenpunkten (M6-02, B-034); auf Stellfüßen
  /// gilt der Wandabstand an der Hauswand (Planungskern v6, Regel 3.11,
  /// `mitStellfuessen`).
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
      stellfuesse: mitStellfuessen(stand, hoehen),
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
    Anschlussbedarf? anschluss,
    Planungsstand? belagstand,
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
      // eine Rinne verkleinert die Fläche (F38, M7-03)
      flaeche: (belagstand ?? stand).kontur.flaeche,
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
      anschluss: anschlussergebnis(
        stand,
        meldungen: anschluss?.meldungen ?? const [],
        hoehen: hoehen.hoehen,
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
    Befestigungsbedarf? befestigung,
    List<Zubehoerposition> zubehoer, [
    Ukzusatz? zusatz,
    UkVerlegung? uk,
    Auflagerbedarf? auflager,
    Anschlussbedarf? anschluss,
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
        anschluss: flaeche.anschluss,
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
    final ukStuecke = [
      ...?uk?.stuecke,
      ...?zusatz?.stuecke,
      ...?auflager?.stuecke,
      ...?anschluss?.stuecke,
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
      anschluss: flaeche.anschluss,
      befestigung: befestigung,
      stueckliste: Stueckliste.aus([...planstuecke, ...ukStuecke]),
      stueckfarben: [for (final p in planstuecke) p.farbe],
      zubehoer: zubehoer,
      querstreben: zusatz?.streben ?? const [],
      querstrebenReihen: switch (zusatz?.reihen) {
        final reihen? when reihen > 0 => reihen,
        _ => null,
      },
    );
  }

  /// Zeilen im Zubehör der Fläche [stand] (M8-02) samt Pflichtzubehör
  /// (M8-03): was der Belag (je Diele), die Befestigung, das berechnete und
  /// das eingegebene Zubehör laut Artikeldaten benötigen. Das Gummiband
  /// liegt auf der UK-Verlegung [uk] (M6-10), ohne sie auf der Übergangs-UK
  /// im Abstand der Feldbreite (M6-09). Ohne Verlegung oder Befestigung nur
  /// die Eingaben und deren Pflichtzubehör.
  static List<Zubehoerposition> _zubehoer(
    Planungsstand stand,
    Artikel? belag,
    Regelwerk? regelwerk,
    Belagverlegung? v,
    Befestigungsbedarf? befestigung,
    UkVerlegung? uk,
  ) {
    final berechnet = befestigung == null
        ? const <Artikelnummer, int>{}
        : berechnetesZubehoer(
            regelwerk!,
            belag!,
            befestigung,
            [for (final t in v!.teile) ...t.stuecke],
            winkel: stand.dielenwinkel.toDouble(),
            feldbreite: stand.feldbreite,
            uk: uk,
          );
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
  /// Verkaufseinheiten – Werkzeug einmal je Planung. Clips und Schrauben
  /// stehen nur einmal darin: aus der Befestigung oder – hat der Kunde im
  /// Zubehör eine Menge der Befestigung geändert – mit den Zubehörmengen.
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
  /// und Verschnitt über alle Flächen (M5-08) – ohne Optimierung wird jede
  /// Fläche für sich zugeschnitten und mal ihrer Häufigkeit gezählt. Ist
  /// eine Verschnittvariante gewählt (M9-01), schneidet der Server alle
  /// Stücke eines Belags über alle Flächen gemeinsam zu
  /// (`verschnittvarianten`), liefert die Varianten mit und rechnet Dielen-
  /// und Materialliste mit der gewählten.
  /// Die Zuschnittpläne (M9-02) fassen
  /// die Lieferstücke von Belag und UK aller Flächen mal Häufigkeit
  /// zusammen.
  ///
  /// Die Materialliste (M9-03) sammelt den Bedarf aller Flächen mal ihrer
  /// Häufigkeit: Dielen je Lieferlänge, die Befestigung in Stück (erst
  /// die Summe wird verpackt) und das zusätzliche UK-Holz der Nutzungsart
  /// (M6-05, `ukZusatz`), die UK-Verlegung (M6-10) und die Auflager (M6-11)
  /// mit der UK der Fläche, das Zubehör (M8-02, M8-03) und die Freidielen der
  /// ganzen Planung (M8-04). Geänderte Mengen der Planung gelten nur
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
    final optimieren = planung.verschnittvariante > 0;
    final gruppen = <(Artikelnummer, String), Belagstuecke>{};
    final zuschnittBelag = <Lieferzuschnitt>[];
    final zuschnittUk = <Lieferzuschnitt>[];
    late Berechnung aktuell;
    for (final (i, f) in planung.flaechen.indexed) {
      final artikel = belag(f.stand.belag);
      // Rinnen sparen den Belag an ihrer Seite aus (M7-03, R-C08)
      final belagstand = rinnenstand(f.stand, artikel, regelwerk);
      final verlegung = verlegeBelag(belagstand, artikel);
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
      final zubehoer = _zubehoer(
        f.stand,
        artikel,
        regelwerk,
        verlegung,
        befestigung,
        ukv,
      );
      final zusatz = _ukZusatz(f.stand, artikel, regelwerk, uk, verlegung, ukv);
      final auflager = _auflager(f.stand, regelwerk, uk, ukv, hoehen);
      final anschluss = _anschluss(
        f.stand,
        artikel,
        regelwerk,
        uk,
        ukv,
        hoehen,
      );
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
              anschluss,
              belagstand,
            )
          : _grundflaeche(
              f.stand,
              null,
              null,
              null,
              null,
              null,
              null,
              null,
              belagstand,
            );
      gesamt += grund.flaeche * f.haeufigkeit;
      if (verlegung != null) {
        // verlegt wird nur mit Belag
        final nummer = artikel!.nummer;
        belaege[nummer] = artikel;
        if (optimieren) {
          final gruppe = gruppen.putIfAbsent(
            (nummer, verlegung.lieferlaengen.join(',')),
            () => (
              belag: nummer,
              laengen: verlegung.lieferlaengen,
              stuecke: <Millimeter>[],
              ueberlaenge: verlegung.ueberlaenge,
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
          zuschnittBelag.addAll([
            for (final t in verlegung.teile)
              for (final d in t.zuschnitt)
                (artikel: artikel, stueck: d, anzahl: f.haeufigkeit),
          ]);
        }
        final hoelzer = _ukHoelzer(
          f.stand,
          uk,
          ukv,
          zusatz,
          auflager,
          anschluss,
        );
        zuschnittUk.addAll([
          for (final d in hoelzer)
            // UK-Holz gibt es nur mit UK
            (artikel: uk!, stueck: d, anzahl: f.haeufigkeit),
        ]);
        bedarfe.addAll([
          for (final b in [
            ...?ukv?.bedarf,
            ...zusatz.bedarf,
            ...?auflager?.bedarf,
            ...anschluss.bedarf,
          ])
            // das UK-Holz kommt aus dem gemeinsamen Zuschnitt
            if (!_istUkHolz(b, uk)) b * f.haeufigkeit,
          if (uk != null)
            for (final b in ukBedarf(uk, hoelzer)) b * f.haeufigkeit,
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
          zusatz,
          ukv,
          auflager,
          anschluss,
        );
      }
    }
    final varianten = verschnittvarianten(gruppen.values.toList());
    final gewaehlt = varianten.isEmpty
        ? null
        : math.min(planung.verschnittvariante, varianten.length);
    if (gewaehlt != null) {
      final variante = varianten[gewaehlt - 1];
      listen.addAll(variante.dielenlisten);
      zuschnittBelag.addAll([
        for (final MapEntry(key: nummer, value: dielen)
            in variante.zuschnitt.entries)
          for (final d in dielen)
            (artikel: belaege[nummer]!, stueck: d, anzahl: 1),
      ]);
    }
    for (final MapEntry(key: nummer, value: liste) in listen.entries) {
      bedarfe.addAll([
        for (final MapEntry(key: laenge, value: anzahl) in liste.anzahl.entries)
          Materialbedarf([belaege[nummer]!], anzahl, laenge: laenge),
      ]);
    }
    final summe = listen.values.fold(Dielenliste.leer, (a, b) => a + b);
    final dielenliste = _positionen(listen);
    // Freidielen der ganzen Planung (M8-04, R-B09, B-228): eigene Position
    // mit Preis 0, einmal je Planung – auch im Holzvolumen (M6-10)
    final frei = freidielenposition(
      dielenliste,
      istDiele: (n) => belaege[n]!.art == Artikelart.diele,
    );
    final alle = [
      ...bedarfe,
      if (frei != null)
        Materialbedarf(
          [belaege[frei.belag]!],
          frei.anzahl,
          laenge: frei.laenge,
          zusatz: Materialzusatz.freidiele,
        ),
      // Bohrsenker als optionale Position, nicht in der Summe (Planungskern
      // v6 Regel 4.5)
      ?bohrsenkerAngebot(regelwerk, bedarfe),
    ];
    return aktuell.mitPlanung(
      gesamt,
      verschnitt: listen.isEmpty ? null : summe.verschnitt,
      dielenliste: dielenliste,
      materialliste: Materialliste.aus(
        alle,
        mengen: mitMengen ? planung.mengen : const {},
      ),
      volumen: holzvolumen(alle),
      verschnittvarianten: [
        for (final v in varianten)
          (verschnitt: v.summe.verschnitt, dielen: _positionen(v.dielenlisten)),
      ],
      verschnittvariante: gewaehlt,
      zuschnittBelag: Zuschnittplan.aus(zuschnittBelag),
      zuschnittUk: Zuschnittplan.aus(zuschnittUk),
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

  /// Lieferhölzer der UK einer Fläche aus einem gemeinsamen Zuschnitt
  /// (M10-01, Paritätsnachweis): UK-Verlegung, zusätzliches Holz der
  /// Nutzungsart, Stützen der Hochterrasse und die UK-Stücke des
  /// Anschlusses (Blendenträger, Treppe). Kurze Stücke kommen so zuerst in
  /// die Reste der langen (`lieferhoelzer`) – wie im alten Planer (F28: 13
  /// × 400 cm für 309 + 39,9 + 39,9 cm) statt je Quelle eigene Hölzer.
  static List<Lieferdiele> _ukHoelzer(
    Planungsstand stand,
    Artikel? uk,
    UkVerlegung? ukv,
    Ukzusatz zusatz,
    Auflagerbedarf? auflager,
    Anschlussbedarf anschluss,
  ) {
    if (uk == null) return const [];
    return lieferhoelzer(
      [
        for (final d in [
          ...?ukv?.zuschnitt,
          ...zusatz.zuschnitt,
          ...?auflager?.zuschnitt,
        ])
          ...d.schnitte,
        for (final s in anschluss.stuecke)
          if (s.nummer == uk.nummer) s.laenge,
      ],
      ukLieferlaengen(uk),
      fest: stand.ukLaenge,
    );
  }

  /// Ob [b] Lieferholz der UK [uk] ist (mit Länge).
  static bool _istUkHolz(Materialbedarf b, Artikel? uk) =>
      b.laenge != null && b.einheiten.single.nummer == uk?.nummer;

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
      flaeche: Hoehenflaeche(stand.grundriss.ecken, hoehen.hoehen, [
        for (final p in stand.wirksameHoehenpunkte) stand.ortVon(p),
      ]),
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

  /// Terrassenanschluss der Fläche (M7): Seitenblende (M7-02, Planungskern
  /// v6, 4a) mit Trägern höchstens 40 cm auseinander aus den Resten der
  /// UK-Verlegung (ohne UK-Verlegung keine Träger), Entwässerungsrinnen
  /// (M7-03) und Treppen (M7-05).
  static Anschlussbedarf _anschluss(
    Planungsstand stand,
    Artikel? belag,
    Regelwerk? regelwerk,
    Artikel? uk,
    UkVerlegung? v,
    Hoehenpunkte hoehen,
  ) => anschlussbedarf(
    stand,
    hoehen: hoehen.hoehen,
    belag: belag,
    regelwerk: regelwerk,
    uk: uk,
    // mit UK-Verlegung gibt es immer eine Feldbreite
    ukAbstand: v == null
        ? null
        : wirksameFeldbreite(
            stand.feldbreite,
            belagFeldbreite(belag, regelwerk)!,
          ),
    ukStuecke: [for (final s in v?.stuecke ?? const <Planstueck>[]) s.laenge],
  );

  /// Geänderte Mengen der Materialliste (Mitarbeiter-Ansicht,
  /// Fachkonzept 08) übernimmt der Server nur von angemeldeten Mitarbeitern
  /// (M9-10). Die Rolle setzt der Router (`caller_authrole`, registriert mit
  /// `disclose_caller`) – ein Aufrufer kann sie nicht selbst angeben.
  static bool darfMengenAendern(LazyInvocationPayload aufruf) =>
      aufruf.customDetails?['caller_authrole'] == Rollen.mitarbeiter;

  static Future<void> _berechne(
    LazyInvocationPayload aufruf,
    Rechenwerk werk,
    Belagsuche belag,
    Regelwerksuche regelwerk,
    Unterkonstruktionssuche unterkonstruktion,
  ) async {
    try {
      final planung = Planung.ausBytes(_bytes(aufruf));
      final ergebnis = await werk.rechne(
        rechenauftrag(
          planung,
          {
            for (final f in planung.flaechen)
              f.stand.belag: belag(f.stand.belag),
          },
          [for (final f in planung.flaechen) unterkonstruktion(f.stand)],
          regelwerk(),
          mitMengen: darfMengenAendern(aufruf),
        ),
      );
      aufruf.respondWith(lazyPayload: verpacke(ergebnis), options: ppt);
    } on RechenzeitUeberschritten catch (fehler) {
      aufruf.respondWith(
        isError: true,
        errorUri: WampNamen.planungZuAufwendig,
        arguments: ['$fehler'],
      );
    } on Object catch (fehler) {
      aufruf.respondWith(
        isError: true,
        errorUri: WampNamen.planungUngueltig,
        arguments: ['$fehler'],
      );
    }
  }

  /// Berechnung der [planung] als Auftrag für das [Rechenwerk]: Belag und
  /// UK sind schon im Router-Isolate nachgeschlagen ([belaege] je
  /// Artikelnummer, [uks] je Fläche), damit der Auftrag nur versendbare
  /// Werte einschließt (die Suchfunktionen hängen an Dienst-Sitzungen).
  static Uint8List Function() rechenauftrag(
    Planung planung,
    Map<Artikelnummer?, Artikel?> belaege,
    List<Artikel?> uks,
    Regelwerk? regelwerk, {
    required bool mitMengen,
  }) =>
      () => berechnePlanung(
        planung,
        (nummer) => belaege[nummer],
        regelwerk,
        mitMengen,
        (stand) =>
            uks[planung.flaechen.indexWhere((f) => identical(f.stand, stand))],
      ).zuBytes();

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
