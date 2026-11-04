import 'dart:typed_data';

import 'package:connectanum_router/connectanum_router.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../datenhaltung/konfigurationen.dart';
import '../router/planer_router.dart';

/// Konfigurationsdienst (M9-05): SPEICHERN, LADEN und automatisches
/// Zwischenspeichern über WAMP. Nur er greift auf die gespeicherten
/// Konfigurationen zu (Sternstruktur); die Planung reist unverändert im
/// Transportformat (`Planung.zuBytes`) als Binärargument.
///
/// Eine gespeicherte Konfiguration heißt nach außen immer mit ihrer
/// **Kennung** `JJJJ-MM-TT-NNNN-XXXXX` (Nummer und Prüfcode, M9-05b): wer
/// nur die fortlaufende Nummer kennt, kann sie weder laden noch fortführen.
///
/// - speichern `[inhalt]` oder `[inhalt, kennung]` → `[kennung, version]`
/// - laden `[kennung, version]` → `[inhalt]`
/// - Entwurf speichern `[schluessel, inhalt]` oder
///   `[schluessel, inhalt, kennung, version]` → `[]`
/// - Entwurf laden `[schluessel]` → `[inhalt]` oder `[inhalt, kennung, version]`
///
/// Falscher Prüfcode und unbekannte Nummer geben denselben Fehler.
class KonfigurationsDienst {
  KonfigurationsDienst._(this._sitzung, this._ablage);

  static Future<KonfigurationsDienst> starte(
    PlanerRouter router,
    KonfigurationsSpeicher ablage,
  ) async {
    final sitzung = await router.dienstSitzung(sitzungId);
    final dienst = KonfigurationsDienst._(sitzung, ablage);
    for (final (prozedur, arbeit) in [
      (WampNamen.konfigurationSpeichern, dienst._speichern),
      (WampNamen.konfigurationLaden, dienst._laden),
      (WampNamen.entwurfSpeichern, dienst._entwurfSpeichern),
      (WampNamen.entwurfLaden, dienst._entwurfLaden),
    ]) {
      (await sitzung.register(prozedur))
          .onInvoke((aufruf) => _antworte(aufruf, arbeit));
    }
    return dienst;
  }

  /// authid der internen Dienst-Sitzung.
  static const sitzungId = 'konfigurations-dienst';

  /// Obergrenze einer gespeicherten Planung (Schutz vor Missbrauch); eine
  /// Fläche braucht wenige hundert Byte.
  static const groessterInhalt = 1 << 20;

  /// Sitzungsschlüssel des Browsers: 128 Bit Zufall als Hexadezimaltext.
  static final schluesselMuster = RegExp(r'^[0-9a-f]{32}$');

  final RouterSession _sitzung;
  final KonfigurationsSpeicher _ablage;

  List<Object?> _speichern(List<Object?> argumente, Invocation _) {
    final stand = switch (argumente) {
      [final Uint8List inhalt] => _ablage.speichere(_planung(inhalt)),
      [final Uint8List inhalt, final String kennung] => _ablage.speichere(
        _planung(inhalt),
        kennung: Konfigurationskennung.lies(kennung),
      ),
      _ => throw _ungueltig(argumente),
    };
    return [stand.kennung.wert, stand.version];
  }

  List<Object?> _laden(List<Object?> argumente, Invocation aufruf) =>
      switch (argumente) {
        [final String kennung, final int version] => [
          _ablage.lies(
            KonfigurationsStand(_kennungZumLaden(kennung, version), version),
            ohnePruefcode: darfOhnePruefcodeLaden(aufruf),
          ),
        ],
        _ => throw _ungueltig(argumente),
      };

  /// Fehlender oder falsch geschriebener Prüfcode beim Laden: wie eine
  /// unbekannte Konfiguration (M9-05b).
  static Konfigurationskennung _kennungZumLaden(String text, int version) {
    try {
      return Konfigurationskennung.lies(text);
    } on PruefcodeUngueltig catch (fehler) {
      throw KonfigurationUnbekannt(fehler.nummer, version);
    }
  }

  /// **Stelle für die Mitarbeiter-Anmeldung (M9-10):** Hier sollen später
  /// angemeldete Mitarbeiter (Rolle `mitarbeiter` aus den Aufrufdetails)
  /// Konfigurationen auch ohne passenden Prüfcode laden dürfen. Bis es die
  /// Anmeldung gibt, verlangt LADEN von jedem Aufrufer Nummer **und**
  /// Prüfcode.
  static bool darfOhnePruefcodeLaden(Invocation aufruf) => false;

  List<Object?> _entwurfSpeichern(List<Object?> argumente, Invocation _) {
    switch (argumente) {
      case [final String schluessel, final Uint8List inhalt]:
        _ablage.merkeEntwurf(_schluessel(schluessel), _planung(inhalt));
      case [
        final String schluessel,
        final Uint8List inhalt,
        final String kennung,
        final int version,
      ]:
        _ablage.merkeEntwurf(
          _schluessel(schluessel),
          _planung(inhalt),
          bezug: KonfigurationsStand(
            Konfigurationskennung.lies(kennung),
            version,
          ),
        );
      default:
        throw _ungueltig(argumente);
    }
    return const [];
  }

  List<Object?> _entwurfLaden(List<Object?> argumente, Invocation _) {
    final schluessel = switch (argumente) {
      [final String s] => _schluessel(s),
      _ => throw _ungueltig(argumente),
    };
    return switch (_ablage.entwurf(schluessel)) {
      null => throw const _EntwurfUnbekannt(),
      (:final inhalt, bezug: null) => [inhalt],
      (:final inhalt, bezug: final b?) => [inhalt, b.kennung.wert, b.version],
    };
  }

  /// Nur lesbare Planungen werden gespeichert – was gespeichert ist, lässt
  /// sich immer laden.
  static Uint8List _planung(Uint8List inhalt) {
    if (inhalt.length > groessterInhalt) {
      throw ArgumentError.value(inhalt.length, 'inhalt', 'zu groß');
    }
    Planung.ausBytes(inhalt);
    return inhalt;
  }

  static String _schluessel(String text) => schluesselMuster.hasMatch(text)
      ? text
      : throw ArgumentError.value(text, 'schluessel', 'kein Sitzungsschlüssel');

  static FormatException _ungueltig(List<Object?> argumente) =>
      FormatException('unerwartete Argumente', argumente);

  /// Ergebnis von [arbeit] oder der passende Fehler: unbekannte Nummer bzw.
  /// Version, kein Entwurf, sonst ungültiger Aufruf.
  static void _antworte(
    Invocation aufruf,
    List<Object?> Function(List<Object?> argumente, Invocation aufruf) arbeit,
  ) {
    final argumente = aufruf.arguments ?? const <Object?>[];
    try {
      aufruf.respondWith(arguments: arbeit(argumente, aufruf));
    } on KonfigurationUnbekannt catch (fehler) {
      aufruf.respondWith(
        isError: true,
        errorUri: WampNamen.konfigurationUnbekannt,
        arguments: [fehler.nummer.wert, ?fehler.version],
      );
    } on _EntwurfUnbekannt {
      aufruf.respondWith(isError: true, errorUri: WampNamen.entwurfUnbekannt);
    } on Object catch (fehler) {
      aufruf.respondWith(
        isError: true,
        errorUri: WampNamen.konfigurationUngueltig,
        arguments: ['$fehler'],
      );
    }
  }

  Future<void> stoppe() => _sitzung.close();
}

final class _EntwurfUnbekannt implements Exception {
  const _EntwurfUnbekannt();
}
