import 'package:connectanum_router/connectanum_router.dart';

/// Native Transportschicht + gestarteter Router; gemeinsame Grundlage von
/// Planer-Router und Auth-Server.
///
/// Eine Transportschicht je Prozess; mehrere Router-Prozesse auf einem
/// Rechner sind ab connectanum 3.0.0-beta.7 auch mit gemeinsamem `TMPDIR`
/// möglich.
class RouterLaufzeit {
  RouterLaufzeit._(this._runtime, this.binding, this._healthIndex);

  /// Startet die Transportschicht und einen Router mit [settings];
  /// [healthListen] ist die Adresse des Health-Endpunkts.
  factory RouterLaufzeit.starte(RouterSettings settings, String healthListen) {
    final runtime = NativeTransportRuntime()..start();
    final binding = Router(
      RouterConfig(
        endpoints: settings.listeners
            .map(Endpoint.fromListenerSettings)
            .toList(growable: false),
      ),
      settings: settings,
    ).start(runtime);
    // Der Health-Endpunkt hängt am Listener mit der Health-Adresse (eigener
    // HTTP-Listener oder – bei gleicher Adresse – an einem anderen Listener).
    final healthIndex = settings.listeners.indexWhere(
      (l) => l.endpoint.trim() == healthListen.trim(),
    );
    return RouterLaufzeit._(runtime, binding, healthIndex);
  }

  final NativeTransportRuntime _runtime;
  final RouterBinding binding;
  final int _healthIndex;

  /// Port des ersten Listeners (WebSocket bzw. RawSocket).
  int get hauptPort => binding.listeners.first.port;

  int get healthPort => binding.listeners[_healthIndex].port;

  /// Beendet Sitzungen geordnet und gibt die Transportschicht frei.
  Future<void> stoppe() async {
    await binding.dispose();
    _runtime
      ..shutdown()
      ..dispose();
  }
}
