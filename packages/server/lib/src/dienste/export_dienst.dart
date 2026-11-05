import 'dart:typed_data';

import 'package:connectanum_router/connectanum_router.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../router/planer_router.dart';
import '../zugriff/rollen.dart';
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
/// Die Prozedur liegt unter `mitarbeiter.`: Exporte gibt es nur in der
/// Mitarbeiter-Ansicht (Fachkonzept 08), der Router lehnt Kunden ab. Die
/// Datei enthält die Materialliste mit Zubehör und Freidielen (M8) und den
/// vom Mitarbeiter geänderten Mengen (`Planung.mengen`, [darfMengenAendern]).
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
    (await sitzung.register(
      WampNamen.exportGrandTotal,
      // Die Rolle des Aufrufers entscheidet über geänderte Mengen (M9-10).
      options: RegisterOptions(discloseCaller: true),
    )).onInvoke(
      (aufruf) => _exportiere(aufruf, belag, regelwerk, unterkonstruktion),
    );
    return ExportDienst._(sitzung);
  }

  static void _exportiere(
    Invocation aufruf,
    Belagsuche belag,
    Regelwerksuche regelwerk,
    Unterkonstruktionssuche unterkonstruktion,
  ) => _antworte(
    aufruf,
    (argumente) => grandTotal(
      argumente,
      belag: belag,
      regelwerk: regelwerk(),
      unterkonstruktion: unterkonstruktion,
      mitMengen: darfMengenAendern(aufruf),
    ),
  );

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
