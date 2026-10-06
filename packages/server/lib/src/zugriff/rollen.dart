import 'package:connectanum_router/connectanum_router.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Rollen im Planer-Realm und ihre Rechte (Prefix-URIs).
///
/// - [kunde]: anonyme Besucher des Planers – nur Kunden-Prozeduren aufrufen
///   und Kunden-Ereignisse abonnieren.
/// - [mitarbeiter]: angemeldete Mitarbeiter (SCRAM) – zusätzlich
///   Mitarbeiter-Prozeduren und -Ereignisse.
/// - [dienst]: Backend-Dienste auf unserem Server (nur interne Sitzungen) –
///   dürfen Prozeduren registrieren und Ereignisse veröffentlichen.
abstract final class Rollen {
  /// Technischer Rollenname `anonymous`: connectanum vergibt bei anonymer
  /// Anmeldung fest diese Rolle.
  static const kunde = 'anonymous';
  static const mitarbeiter = 'mitarbeiter';
  static const dienst = 'dienst';

  static const uriBasis = WampNamen.basis;
  static const kundeUri = WampNamen.kunde;
  static const mitarbeiterUri = WampNamen.mitarbeiter;

  static const _nutzen = ['call', 'subscribe'];
  static const _anbieten = [
    'register',
    'unregister',
    'publish',
    'call',
    'subscribe',
  ];

  /// Alle Rollen mit ihren Rechten für den Planer-Realm.
  static List<RoleSettingsBuilder> alle() => [
    RoleSettingsBuilder(kunde)
      ..addPermissionFromBuilder(_recht(kundeUri, _nutzen)),
    RoleSettingsBuilder(mitarbeiter)
      ..addPermissionFromBuilder(_recht(kundeUri, _nutzen))
      ..addPermissionFromBuilder(_recht(mitarbeiterUri, _nutzen)),
    RoleSettingsBuilder(dienst)
      ..addPermissionFromBuilder(_recht(uriBasis, _anbieten)),
  ];

  static PermissionSettingsBuilder _recht(String uri, List<String> erlaubt) =>
      PermissionSettingsBuilder(uri)
        ..setMatchPolicy(PermissionMatchPolicy.prefix)
        ..allowOperations(erlaubt);
}
