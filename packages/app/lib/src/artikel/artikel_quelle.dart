import 'dart:async';
import 'dart:convert';

import 'package:connectanum_client/connectanum.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Artikel und Regeln vom Artikeldienst (M2-06) – ausschließlich über WAMP.
/// Antworten bleiben im Speicher, bis der Server neue Artikeldaten meldet;
/// dauerhaft speichert die App nichts (Frontend bleibt „doof“).
class ArtikelQuelle {
  ArtikelQuelle._(this._sitzung);

  /// Abonniert die Änderungsmeldung des Artikeldienstes auf [sitzung].
  static Future<ArtikelQuelle> verbinde(Session sitzung) async {
    final quelle = ArtikelQuelle._(sitzung);
    final abo = await sitzung.subscribe(WampNamen.artikelGeaendert);
    quelle._abo = abo.eventStream!.listen(
      (ereignis) => quelle._neueVersion(ereignis.arguments!.single as String),
    );
    return quelle;
  }

  static final _holzarten = {robinie.id: robinie};

  final Session _sitzung;
  late final StreamSubscription<Event> _abo;
  final _listen = <String, Future<List<Artikel>>>{};
  final _regeln = <Artikelnummer, Future<Artikelregeln>>{};
  final _aenderungen = StreamController<String>.broadcast();
  String? _version;

  /// Version der zuletzt geladenen Artikeldaten (`null` vor dem ersten Abruf).
  String? get version => _version;

  /// Neue Versionen der Artikeldaten – die Oberfläche lädt dann neu.
  Stream<String> get aenderungen => _aenderungen.stream;

  /// Artikel, auf die [filter] passt, in Datenreihenfolge.
  Future<List<Artikel>> liste([Artikelfilter filter = const Artikelfilter()]) =>
      _merke(_listen, jsonEncode(filter.alsJson()), () async {
        final antwort = await _sitzung.callSingle(
          WampNamen.artikelListe,
          argumentsKeywords: filter.alsJson(),
        );
        final daten = alsJsonObjekt(antwort.arguments!.single);
        _version = daten['version']! as String;
        return List.unmodifiable([
          for (final a in daten['artikel']! as List<Object?>)
            artikelAusJson(a! as Map<String, Object?>, _holzarten),
        ]);
      });

  /// Auswahl, Pflichtzubehör und Abstände zu einem Artikel.
  Future<Artikelregeln> regeln(Artikelnummer nummer) =>
      _merke(_regeln, nummer, () async {
        final antwort = await _sitzung.callSingle(
          WampNamen.artikelRegeln,
          arguments: [nummer.wert],
        );
        final regeln = Artikelregeln.ausJson(
          alsJsonObjekt(antwort.arguments!.single),
          _holzarten,
        );
        _version = regeln.version;
        return regeln;
      });

  /// Zwischenspeicher je Schlüssel; Fehler werden nicht gemerkt.
  Future<T> _merke<K, T>(
    Map<K, Future<T>> speicher,
    K schluessel,
    Future<T> Function() lade,
  ) => speicher.putIfAbsent(schluessel, () async {
    try {
      return await lade();
    } on Object {
      speicher.removeWhere((k, _) => k == schluessel);
      rethrow;
    }
  });

  void _neueVersion(String version) {
    _listen.clear();
    _regeln.clear();
    _version = version;
    _aenderungen.add(version);
  }

  Future<void> schliesse() async {
    await _abo.cancel();
    await _aenderungen.close();
  }
}
