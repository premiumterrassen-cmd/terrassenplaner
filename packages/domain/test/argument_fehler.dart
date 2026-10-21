import 'package:test/test.dart';

/// Erwartet einen `ArgumentError` mit genau diesem Feldnamen, Wert und Text –
/// so fallen vertauschte Argumente auf (Mutation-Tests).
Matcher wirftArgumentFehler(String name, Object? wert, String text) => throwsA(
  isA<ArgumentError>()
      .having((e) => e.name, 'name', name)
      .having((e) => e.invalidValue, 'invalidValue', wert)
      .having((e) => e.message, 'message', text),
);
