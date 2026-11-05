import 'dart:typed_data';

import 'package:connectanum_router/connectanum_router.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../router/planer_router.dart';
import 'planungs_dienst.dart';

/// Exportdienst (M9-08): erzeugt aus einer Planung die Importdatei für
/// GrandTotal. Er rechnet die Materialliste wie der Planungsdienst
/// (`PlanungsDienst.berechnePlanung`) und schreibt sie mit den Daten der
/// aktuellen Artikel (`grandTotalZeilen`, `grandTotalCsv`) – die App
/// fordert die Datei nur an und bietet sie zum Speichern an.
///
/// - export.grandtotal `[planung]` oder `[planung, adresse der App]` →
///   `[importdatei]`
///
/// Die Datei enthält nur, was auch die Materialliste zeigt (Verkaufsdaten,
/// B-055); geänderte Mengen der Mitarbeiter-Ansicht gelten wie beim
/// Planungsdienst nur für Mitarbeiter ([darfMengenAendern]).
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
  }) async {
    final sitzung = await router.dienstSitzung(sitzungId);
    (await sitzung.register(WampNamen.exportGrandTotal)).onInvoke(
      (aufruf) => _antworte(
        aufruf,
        (argumente) => grandTotal(
          argumente,
          belag: belag,
          regelwerk: regelwerk(),
          unterkonstruktion: unterkonstruktion,
          mitMengen: darfMengenAendern(aufruf),
        ),
      ),
    );
    return ExportDienst._(sitzung);
  }

  /// authid der internen Dienst-Sitzung.
  static const sitzungId = 'export-dienst';

  /// Obergrenze der Planung (wie beim Speichern, M9-05).
  static const groessterInhalt = 1 << 20;

  /// **Stelle für die Mitarbeiter-Anmeldung (M9-10):** wie
  /// `PlanungsDienst.darfMengenAendern` – geänderte Mengen der Materialliste
  /// gelten nur für angemeldete Mitarbeiter (Rolle `mitarbeiter` aus den
  /// Aufrufdetails). Bis es die Anmeldung gibt, exportiert der Dienst für
  /// jeden Aufrufer die berechneten Mengen.
  static bool darfMengenAendern(Invocation aufruf) => false;

  /// Importdatei zu den [argumente]n `[planung]` oder `[planung, adresse]`;
  /// geänderte Mengen der Planung gelten nur [mitMengen]. Wirft bei anderen
  /// Argumenten oder unlesbarer Planung.
  static String grandTotal(
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
    final berechnung = PlanungsDienst.berechnePlanung(
      Planung.ausBytes(inhalt),
      belag,
      regelwerk,
      mitMengen,
      unterkonstruktion,
    );
    return grandTotalCsv(
      grandTotalZeilen(
        berechnung.materialliste,
        (nummer) => regelwerk?.datei[nummer]?.artikel,
        bilder: adresse,
      ),
    );
  }

  static void _antworte(
    Invocation aufruf,
    String Function(List<Object?> argumente) arbeit,
  ) {
    try {
      aufruf.respondWith(
        arguments: [arbeit(aufruf.arguments ?? const <Object?>[])],
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
