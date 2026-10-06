import 'package:connectanum_router/connectanum_router.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../router/planer_router.dart';

/// Hallo-Welt-Dienst (M0-12): beantwortet [WampNamen.hallo] mit der
/// Begrüßung – prüft die Kette Web-App → Router → Backend-Dienst.
class HalloDienst {
  HalloDienst._(this._sitzung);

  static Future<HalloDienst> starte(PlanerRouter router) async {
    final sitzung = await router.dienstSitzung(sitzungId);
    final registrierung = await sitzung.register(WampNamen.hallo);
    registrierung.onInvoke(
      (aufruf) => aufruf.respondWith(arguments: [begruessung()]),
    );
    return HalloDienst._(sitzung);
  }

  /// authid der internen Dienst-Sitzung.
  static const sitzungId = 'hallo-dienst';

  final RouterSession _sitzung;

  Future<void> stoppe() => _sitzung.close();
}
