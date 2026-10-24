import 'package:connectanum_router/connectanum_router.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../router/planer_router.dart';
import 'artikeldatei_quelle.dart';

/// Artikeldienst (M2-06): liefert Artikel und Regelwerk über WAMP. Die App
/// hält nichts dauerhaft vor; wechseln die Artikeldaten, meldet der Dienst
/// die neue Version über [WampNamen.artikelGeaendert].
class ArtikelDienst {
  ArtikelDienst._(this._sitzung, this._regelwerk);

  static Future<ArtikelDienst> starte(
    PlanerRouter router,
    Artikeldatei datei,
  ) async {
    final sitzung = await router.dienstSitzung(sitzungId);
    final dienst = ArtikelDienst._(sitzung, Regelwerk(datei));
    (await sitzung.register(WampNamen.artikelVersion)).onInvoke(
      (aufruf) => aufruf.respondWith(arguments: [dienst.datei.version]),
    );
    (await sitzung.register(WampNamen.artikelListe)).onInvoke(dienst._liste);
    (await sitzung.register(WampNamen.artikelRegeln)).onInvoke(dienst._regeln);
    return dienst;
  }

  /// authid der internen Dienst-Sitzung.
  static const sitzungId = 'artikel-dienst';

  final RouterSession _sitzung;
  Regelwerk _regelwerk;

  /// Aktuelle Artikeldatei.
  Artikeldatei get datei => _regelwerk.datei;

  /// Tauscht die Artikeldaten aus und meldet die neue Version – ohne
  /// Neustart und ohne App-Update.
  Future<void> ersetze(Artikeldatei neu) async {
    _regelwerk = Regelwerk(neu);
    await _sitzung.publish(
      WampNamen.artikelGeaendert,
      arguments: [neu.version],
    );
  }

  /// Übernimmt einen neuen Stand aus [quelle]. Fehlerhafte Dateien meldet
  /// [melde]; der bisherige Stand bleibt dann in Betrieb.
  Future<void> aktualisiere(
    ArtikeldateiQuelle quelle,
    void Function(String meldung) melde,
  ) async {
    final Artikeldatei? neu;
    try {
      neu = quelle.neuerStand();
    } on Object catch (fehler) {
      melde('Artikeldatei ${quelle.pfad} nicht übernommen: $fehler');
      return;
    }
    if (neu == null || neu.version == datei.version) return;
    await ersetze(neu);
    melde(
      'Artikeldaten ${neu.version} aus ${neu.quelle}: '
      '${neu.eintraege.length} Artikel',
    );
  }

  void _liste(Invocation aufruf) {
    final Artikelfilter filter;
    try {
      filter = Artikelfilter.ausJson(aufruf.argumentsKeywords ?? const {});
    } on ArgumentError catch (fehler) {
      _filterFehler(aufruf, fehler);
      return;
    } on TypeError catch (fehler) {
      _filterFehler(aufruf, fehler);
      return;
    }
    aufruf.respondWith(
      arguments: [
        {
          'version': datei.version,
          'artikel': [
            for (final a in _regelwerk.finde(filter)) artikelAlsJson(a),
          ],
        },
      ],
    );
  }

  /// Unbekannte Werte (ArgumentError) oder falsche Typen (TypeError).
  static void _filterFehler(Invocation aufruf, Object fehler) =>
      aufruf.respondWith(
        isError: true,
        errorUri: WampNamen.artikelFilterUngueltig,
        arguments: ['$fehler'],
      );

  void _regeln(Invocation aufruf) {
    final argumente = aufruf.arguments ?? const <Object?>[];
    final nummer = switch (argumente) {
      [final String text] => Artikelnummer(text),
      _ => null,
    };
    if (nummer == null || datei[nummer] == null) {
      aufruf.respondWith(
        isError: true,
        errorUri: WampNamen.artikelUnbekannt,
        arguments: argumente,
      );
      return;
    }
    aufruf.respondWith(arguments: [_regelwerk.regeln(nummer).alsJson()]);
  }

  Future<void> stoppe() => _sitzung.close();
}
