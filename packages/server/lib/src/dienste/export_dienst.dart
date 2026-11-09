import 'dart:typed_data';

import 'package:connectanum_router/connectanum_router.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../router/planer_router.dart';
import '../zugriff/rollen.dart';
import 'planungs_dienst.dart';
import 'rechenwerk.dart';

/// Exportdienst (M9-08): erzeugt aus einer Planung die Importdatei für
/// GrandTotal. Er rechnet die Materialliste wie der Planungsdienst
/// (`PlanungsDienst.berechnePlanung`) und schreibt sie mit den Daten der
/// aktuellen Artikel (`grandTotalZeilen`, `grandTotalCsv`) – die App
/// fordert die Datei nur an und bietet sie zum Speichern an.
///
/// - export.grandtotal `[planung]` oder `[planung, adresse der App]` →
///   `[importdatei]`
///
/// Die Prozedur liegt unter `mitarbeiter.`: Exporte gibt es nur in der
/// Mitarbeiter-Ansicht (Fachkonzept 08), der Router lehnt Kunden ab. Die
/// Datei enthält die Materialliste mit Zubehör und Freidielen (M8) und den
/// vom Mitarbeiter geänderten Mengen (`Planung.mengen`, [darfMengenAendern]).
///
/// Gerechnet wird wie im Planungsdienst im [Rechenwerk] (M10-02), nicht im
/// Router-Isolate; dauert es zu lange, antwortet der Dienst mit
/// `planung_zu_aufwendig`.
class ExportDienst {
  ExportDienst._(this._sitzung);

  /// Wie der Planungsdienst: [belag], [regelwerk] und [unterkonstruktion]
  /// aus den aktuellen Artikeldaten; das Regelwerk liefert auch die
  /// Artikel der Zeilen (Maße, Art, Gewicht).
  static Future<ExportDienst> starte(
    PlanerRouter router, {
    required Belagsuche belag,
    required Regelwerksuche regelwerk,
    required Unterkonstruktionssuche unterkonstruktion,
    Rechenwerk? rechenwerk,
  }) async {
    final werk = rechenwerk ?? Rechenwerk();
    final sitzung = await router.dienstSitzung(sitzungId);
    (await sitzung.register(
      WampNamen.exportGrandTotal,
      // Die Rolle des Aufrufers entscheidet über geänderte Mengen (M9-10).
      options: RegisterOptions(discloseCaller: true),
    )).onInvoke(
      (aufruf) =>
          _exportiere(aufruf, werk, belag, regelwerk, unterkonstruktion),
    );
    return ExportDienst._(sitzung);
  }

  /// authid der internen Dienst-Sitzung.
  static const sitzungId = 'export-dienst';

  /// Obergrenze der Planung (wie beim Speichern, M9-05).
  static const groessterInhalt = 1 << 20;

  /// Geänderte Mengen der Materialliste gelten wie beim Planungsdienst nur
  /// für angemeldete Mitarbeiter (M9-10). Die Rolle setzt der Router
  /// (`caller_authrole`, registriert mit `disclose_caller`) – ein Aufrufer
  /// kann sie nicht selbst angeben; interne Dienste exportieren die
  /// berechneten Mengen.
  static bool darfMengenAendern(Invocation aufruf) =>
      aufruf.details.custom['caller_authrole'] == Rollen.mitarbeiter;

  /// Importdatei zu den [argumente]n `[planung]` oder `[planung, adresse]`
  /// als Auftrag für das [Rechenwerk]; geänderte Mengen der Planung gelten
  /// nur [mitMengen]. Argumente, Planung, Belag und UK prüft bzw. schlägt
  /// der Dienst sofort nach (im Router-Isolate, wirft bei anderen Argumenten
  /// oder unlesbarer Planung), damit der Auftrag nur versendbare Werte
  /// einschließt – Muster `PlanungsDienst.rechenauftrag`.
  static String Function() grandTotalAuftrag(
    List<Object?> argumente, {
    required Belagsuche belag,
    required Regelwerk? regelwerk,
    required Unterkonstruktionssuche unterkonstruktion,
    bool mitMengen = false,
  }) {
    final (inhalt, adresse) = switch (argumente) {
      [final Uint8List inhalt] => (inhalt, null),
      [final Uint8List inhalt, final String adresse] => (
        inhalt,
        Uri.parse(adresse),
      ),
      _ => throw FormatException('unerwartete Argumente', argumente),
    };
    if (inhalt.length > groessterInhalt) {
      throw ArgumentError.value(inhalt.length, 'planung', 'zu groß');
    }
    final planung = Planung.ausBytes(inhalt);
    final belaege = {
      for (final f in planung.flaechen) f.stand.belag: belag(f.stand.belag),
    };
    final uks = {
      for (final f in planung.flaechen) f.stand: unterkonstruktion(f.stand),
    };
    return () => grandTotalCsv(
      grandTotalZeilen(
        PlanungsDienst.berechnePlanung(
          planung,
          (nummer) => belaege[nummer],
          regelwerk,
          mitMengen,
          (stand) => uks[stand],
        ).materialliste,
        (nummer) => regelwerk?.datei[nummer]?.artikel,
        bilder: adresse,
      ),
    );
  }

  static Future<void> _exportiere(
    Invocation aufruf,
    Rechenwerk werk,
    Belagsuche belag,
    Regelwerksuche regelwerk,
    Unterkonstruktionssuche unterkonstruktion,
  ) async {
    try {
      final datei = await werk.rechne(
        grandTotalAuftrag(
          aufruf.arguments ?? const <Object?>[],
          belag: belag,
          regelwerk: regelwerk(),
          unterkonstruktion: unterkonstruktion,
          mitMengen: darfMengenAendern(aufruf),
        ),
      );
      aufruf.respondWith(arguments: [datei]);
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

  final RouterSession _sitzung;

  Future<void> stoppe() => _sitzung.close();
}
