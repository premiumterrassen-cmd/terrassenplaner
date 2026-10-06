import 'projekt_info.dart';

/// Antwort der Hallo-Welt-Prozedur (M0-12).
String begruessung({ProjektInfo info = terrassenplaner}) =>
    'Verbunden mit ${info.titel}';
