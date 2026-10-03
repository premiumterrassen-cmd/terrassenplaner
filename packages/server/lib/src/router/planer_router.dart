import 'package:connectanum_router/connectanum_router.dart';

import '../zugriff/rollen.dart';
import 'router_einstellungen.dart';
import 'router_laufzeit.dart';

/// Laufender öffentlicher WAMP-Router des Terrassenplaners.
class PlanerRouter {
  PlanerRouter._(this.einstellungen, this._laufzeit);

  static PlanerRouter starte(RouterEinstellungen einstellungen) =>
      PlanerRouter._(
        einstellungen,
        RouterLaufzeit.starte(
          einstellungen.alsRouterSettings(),
          einstellungen.healthListen,
        ),
      );

  final RouterEinstellungen einstellungen;
  final RouterLaufzeit _laufzeit;

  /// Tatsächlich gebundener Port des WebSocket-Listeners.
  int get webSocketPort => _laufzeit.hauptPort;

  /// Tatsächlich gebundener Port des Health-Endpunkts.
  int get healthPort => _laufzeit.healthPort;

  /// Interne Sitzung für einen Backend-Dienst (Rolle `dienst`), ohne
  /// Netzwerk-Anmeldung.
  Future<RouterSession> dienstSitzung(String dienstName) =>
      _laufzeit.binding.createInternalSession(
        realmUri: einstellungen.realm,
        authId: dienstName,
        authRole: Rollen.dienst,
      );

  Future<void> stoppe() => _laufzeit.stoppe();
}
