import 'dart:typed_data';

import 'package:connectanum_router/connectanum_router.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../datenhaltung/konfigurationen.dart';
import '../ergebnisse/planungsunterlagen_pdf.dart';
import '../router/planer_router.dart';
import '../zugriff/rollen.dart';
import 'planungs_dienst.dart';
import 'rechenwerk.dart';

/// Unterlagendienst (M9-06): erzeugt die Planungsunterlagen einer
/// gespeicherten Konfiguration als PDF – aus Version und aktuellem
/// Datenstand (docs/architektur/datenmodell.md), nie aus einer Planung der
/// App. So steht im PDF immer eine Konfigurationsnummer, unter der sich
/// genau diese Planung wieder laden lässt.
///
/// - PDF `[kennung, version]`, `[kennung, version, sprache]` oder
///   `[kennung, version, sprache, kunde]` → `[pdf]`; `sprache` ist `de`
///   oder `en`, `kunde` ein Wörterbuch mit `name`, `adresse`, `ort`,
///   `telefon`, `email` (nur gedruckt, nicht gespeichert).
///
/// Falscher Prüfcode und unbekannte Nummer geben denselben Fehler wie beim
/// Laden (M9-05b).
///
/// Berechnungen und PDF entstehen wie im Planungsdienst im [Rechenwerk]
/// (M10-02), nicht im Router-Isolate; dauert beides zu lange, antwortet der
/// Dienst mit `planung_zu_aufwendig`.
class UnterlagenDienst {
  UnterlagenDienst._(this._sitzung);

  static Future<UnterlagenDienst> starte(
    PlanerRouter router,
    KonfigurationsSpeicher ablage, {
    Belagsuche belag = _ohneBelag,
    Regelwerksuche regelwerk = _ohneRegelwerk,
    Unterkonstruktionssuche unterkonstruktion = _ohneUnterkonstruktion,
    DateTime Function() uhr = DateTime.now,
    Rechenwerk? rechenwerk,
  }) async {
    final werk = rechenwerk ?? Rechenwerk();
    final sitzung = await router.dienstSitzung(sitzungId);
    (await sitzung.register(
      WampNamen.planungsunterlagenPdf,
      // Die Rolle des Aufrufers entscheidet über geänderte Mengen (M9-10).
      options: RegisterOptions(discloseCaller: true),
    )).onInvoke(
      (aufruf) => _antworte(
        aufruf,
        (argumente) => _pdf(
          argumente,
          ablage,
          werk,
          belag,
          regelwerk,
          unterkonstruktion,
          uhr,
          mitMengen: darfMengenAendern(aufruf),
        ),
      ),
    );
    return UnterlagenDienst._(sitzung);
  }

  static Artikel? _ohneBelag(Artikelnummer? nummer) => null;

  static Regelwerk? _ohneRegelwerk() => null;

  static Artikel? _ohneUnterkonstruktion(Planungsstand stand) => null;

  /// Geänderte Mengen der Materialliste (Mitarbeiter-Ansicht) gelten im PDF
  /// wie in der Berechnung nur für angemeldete Mitarbeiter (Rolle
  /// `mitarbeiter` vom Router, M9-10).
  static bool darfMengenAendern(Invocation aufruf) =>
      aufruf.details.custom['caller_authrole'] == Rollen.mitarbeiter;

  /// authid der internen Dienst-Sitzung.
  static const sitzungId = 'unterlagen-dienst';

  /// Die Planungsunterlagen der [planung]: je Fläche eine Berechnung mit
  /// ihr als bearbeiteter Fläche und die Verlegung ihres Belags; die Werte
  /// der ganzen Planung (Materialliste, Fläche, Volumen) sind in jeder
  /// dieser Berechnungen gleich – mit Zubehör und Freidielen (M8) in
  /// Materialliste und Holzvolumen. Geänderte Mengen der Mitarbeiter-Ansicht
  /// gelten nur [mitMengen] (M9-10).
  static Planungsunterlagen unterlagen(
    Planung planung, {
    required DateTime datum,
    Belagsuche belag = _ohneBelag,
    Regelwerk? regelwerk,
    Unterkonstruktionssuche unterkonstruktion = _ohneUnterkonstruktion,
    KonfigurationsStand? stand,
    Kundendaten? kunde,
    Unterlagensprache sprache = Unterlagensprache.deutsch,
    bool mitMengen = false,
  }) {
    final flaechen = [
      for (final (i, f) in planung.flaechen.indexed)
        _flaeche(
          planung.gewaehlt(i),
          f.stand,
          belag,
          regelwerk,
          unterkonstruktion,
          mitMengen,
        ),
    ];
    return planungsunterlagen(
      planung: planung,
      gesamt: flaechen.first.berechnung,
      flaechen: flaechen,
      datum: datum,
      stand: stand,
      kunde: kunde,
      sprache: sprache,
    );
  }

  static Flaechenunterlage _flaeche(
    Planung planung,
    Planungsstand stand,
    Belagsuche belag,
    Regelwerk? regelwerk,
    Unterkonstruktionssuche unterkonstruktion,
    bool mitMengen,
  ) {
    final artikel = belag(stand.belag);
    return Flaechenunterlage(
      PlanungsDienst.berechnePlanung(
        planung,
        belag,
        regelwerk,
        mitMengen,
        unterkonstruktion,
      ),
      belag: artikel,
      uk: unterkonstruktion(stand),
      verlegung: verlegeBelag(stand, artikel),
    );
  }

  /// PDF der Planungsunterlagen als Auftrag für das [Rechenwerk] (Muster
  /// `PlanungsDienst.rechenauftrag`): Belag und UK schlägt der Dienst schon
  /// im Router-Isolate nach – je Artikelnummer und je Planungsstand (gleiche
  /// Stände haben dieselbe UK) –, damit der Auftrag nur versendbare Werte
  /// einschließt (die Suchfunktionen hängen an Dienst-Sitzungen).
  /// [komprimiert] wie bei `planungsunterlagenPdf`.
  static Future<Uint8List> Function() pdfauftrag(
    Planung planung, {
    required DateTime datum,
    Belagsuche belag = _ohneBelag,
    Regelwerk? regelwerk,
    Unterkonstruktionssuche unterkonstruktion = _ohneUnterkonstruktion,
    KonfigurationsStand? stand,
    Kundendaten? kunde,
    Unterlagensprache sprache = Unterlagensprache.deutsch,
    bool mitMengen = false,
    bool komprimiert = true,
  }) {
    final belaege = {
      for (final f in planung.flaechen) f.stand.belag: belag(f.stand.belag),
    };
    final uks = {
      for (final f in planung.flaechen) f.stand: unterkonstruktion(f.stand),
    };
    return () => planungsunterlagenPdf(
      unterlagen(
        planung,
        datum: datum,
        belag: (nummer) => belaege[nummer],
        regelwerk: regelwerk,
        unterkonstruktion: (s) => uks[s],
        stand: stand,
        kunde: kunde,
        sprache: sprache,
        mitMengen: mitMengen,
      ),
      komprimiert: komprimiert,
    );
  }

  static Future<List<Object?>> _pdf(
    List<Object?> argumente,
    KonfigurationsSpeicher ablage,
    Rechenwerk werk,
    Belagsuche belag,
    Regelwerksuche regelwerk,
    Unterkonstruktionssuche unterkonstruktion,
    DateTime Function() uhr, {
    required bool mitMengen,
  }) async {
    final (kennung, version, sprache, kunde) = switch (argumente) {
      [final String k, final int v] => (k, v, 'de', null),
      [final String k, final int v, final String s] => (k, v, s, null),
      [
        final String k,
        final int v,
        final String s,
        final Map<Object?, Object?> d,
      ] =>
        (k, v, s, Kundendaten.aus(d)),
      _ => throw FormatException('unerwartete Argumente', argumente),
    };
    final stand = KonfigurationsStand(_kennung(kennung, version), version);
    final planung = Planung.ausBytes(ablage.lies(stand));
    return [
      await werk.rechne(
        pdfauftrag(
          planung,
          datum: uhr(),
          belag: belag,
          regelwerk: regelwerk(),
          unterkonstruktion: unterkonstruktion,
          stand: stand,
          kunde: kunde,
          sprache: Unterlagensprache.ausCode(sprache),
          mitMengen: mitMengen,
        ),
      ),
    ];
  }

  /// Fehlender oder falsch geschriebener Prüfcode: wie eine unbekannte
  /// Konfiguration (M9-05b).
  static Konfigurationskennung _kennung(String text, int version) {
    try {
      return Konfigurationskennung.lies(text);
    } on PruefcodeUngueltig catch (fehler) {
      throw KonfigurationUnbekannt(fehler.nummer, version);
    }
  }

  static Future<void> _antworte(
    Invocation aufruf,
    Future<List<Object?>> Function(List<Object?> argumente) arbeit,
  ) async {
    try {
      aufruf.respondWith(
        arguments: await arbeit(aufruf.arguments ?? const <Object?>[]),
      );
    } on KonfigurationUnbekannt catch (fehler) {
      aufruf.respondWith(
        isError: true,
        errorUri: WampNamen.konfigurationUnbekannt,
        arguments: [fehler.nummer.wert, ?fehler.version],
      );
    } on RechenzeitUeberschritten catch (fehler) {
      aufruf.respondWith(
        isError: true,
        errorUri: WampNamen.planungZuAufwendig,
        arguments: ['$fehler'],
      );
    } on Object catch (fehler) {
      aufruf.respondWith(
        isError: true,
        errorUri: WampNamen.konfigurationUngueltig,
        arguments: ['$fehler'],
      );
    }
  }

  final RouterSession _sitzung;

  Future<void> stoppe() => _sitzung.close();
}
