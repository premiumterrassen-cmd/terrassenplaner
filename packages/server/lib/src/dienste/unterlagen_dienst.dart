import 'package:connectanum_router/connectanum_router.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../datenhaltung/konfigurationen.dart';
import '../ergebnisse/planungsunterlagen_pdf.dart';
import '../router/planer_router.dart';
import 'planungs_dienst.dart';

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
class UnterlagenDienst {
  UnterlagenDienst._(this._sitzung);

  static Future<UnterlagenDienst> starte(
    PlanerRouter router,
    KonfigurationsSpeicher ablage, {
    Belagsuche belag = _ohneBelag,
    Regelwerksuche regelwerk = _ohneRegelwerk,
    Unterkonstruktionssuche unterkonstruktion = _ohneUnterkonstruktion,
    DateTime Function() uhr = DateTime.now,
  }) async {
    final sitzung = await router.dienstSitzung(sitzungId);
    (await sitzung.register(WampNamen.planungsunterlagenPdf)).onInvoke(
      (aufruf) => _antworte(
        aufruf,
        (argumente) =>
            _pdf(argumente, ablage, belag, regelwerk, unterkonstruktion, uhr),
      ),
    );
    return UnterlagenDienst._(sitzung);
  }

  static Artikel? _ohneBelag(Artikelnummer? nummer) => null;

  static Regelwerk? _ohneRegelwerk() => null;

  static Artikel? _ohneUnterkonstruktion(Planungsstand stand) => null;

  /// authid der internen Dienst-Sitzung.
  static const sitzungId = 'unterlagen-dienst';

  /// Die Planungsunterlagen der [planung]: je Fläche eine Berechnung mit
  /// ihr als bearbeiteter Fläche und die Verlegung ihres Belags; die Werte
  /// der ganzen Planung (Materialliste, Fläche, Volumen) sind in jeder
  /// dieser Berechnungen gleich. Geänderte Mengen der Mitarbeiter-Ansicht
  /// gelten wie in der Berechnung nur für Mitarbeiter (M9-10) – bis dahin
  /// nie.
  static Planungsunterlagen unterlagen(
    Planung planung, {
    required DateTime datum,
    Belagsuche belag = _ohneBelag,
    Regelwerk? regelwerk,
    Unterkonstruktionssuche unterkonstruktion = _ohneUnterkonstruktion,
    KonfigurationsStand? stand,
    Kundendaten? kunde,
    Unterlagensprache sprache = Unterlagensprache.deutsch,
  }) {
    final flaechen = [
      for (final (i, f) in planung.flaechen.indexed)
        _flaeche(
          planung.gewaehlt(i),
          f.stand,
          belag,
          regelwerk,
          unterkonstruktion,
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
  ) {
    final artikel = belag(stand.belag);
    return Flaechenunterlage(
      PlanungsDienst.berechnePlanung(
        planung,
        belag,
        regelwerk,
        false,
        unterkonstruktion,
      ),
      belag: artikel,
      uk: unterkonstruktion(stand),
      verlegung: verlegeBelag(stand, artikel),
    );
  }

  static Future<List<Object?>> _pdf(
    List<Object?> argumente,
    KonfigurationsSpeicher ablage,
    Belagsuche belag,
    Regelwerksuche regelwerk,
    Unterkonstruktionssuche unterkonstruktion,
    DateTime Function() uhr,
  ) async {
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
    final unterlagen = UnterlagenDienst.unterlagen(
      planung,
      datum: uhr(),
      belag: belag,
      regelwerk: regelwerk(),
      unterkonstruktion: unterkonstruktion,
      stand: stand,
      kunde: kunde,
      sprache: Unterlagensprache.ausCode(sprache),
    );
    return [await planungsunterlagenPdf(unterlagen)];
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
