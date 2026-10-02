import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Meldung, die der Server beim Start ins Protokoll schreibt.
String startMeldung({ProjektInfo info = terrassenplaner}) =>
    '${info.titel}: Server gestartet';
