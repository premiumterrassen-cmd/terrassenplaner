import 'package:connectanum_router/auth.dart';
import 'package:connectanum_router/connectanum_router.dart';

import 'router_einstellungen.dart';

/// Laufender WAMP-Router des Terrassenplaners (connectanum_router).
class PlanerRouter {
  PlanerRouter._(this.einstellungen, this._runtime, this._binding);

  /// Startet die native Transportschicht und den Router.
  static PlanerRouter starte(RouterEinstellungen einstellungen) {
    registerDefaultAuthenticators();
    final runtime = NativeTransportRuntime()..start();
    final settings = einstellungen.alsRouterSettings();
    final router = Router(
      RouterConfig(
        endpoints: settings.listeners
            .map(Endpoint.fromListenerSettings)
            .toList(growable: false),
      ),
      settings: settings,
    );
    return PlanerRouter._(einstellungen, runtime, router.start(runtime));
  }

  final RouterEinstellungen einstellungen;
  final NativeTransportRuntime _runtime;
  final RouterBinding _binding;

  /// Tatsächlich gebundener Port des WebSocket-Listeners.
  int get webSocketPort => _binding.listeners.first.port;

  /// Tatsächlich gebundener Port des Health-Listeners.
  int get healthPort => _binding.listeners.last.port;

  /// Beendet Sitzungen geordnet und gibt die Transportschicht frei.
  Future<void> stoppe() async {
    await _binding.dispose();
    _runtime
      ..shutdown()
      ..dispose();
  }
}
