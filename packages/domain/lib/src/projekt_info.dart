/// Stammdaten des Projekts, die App und Server gleichermaßen anzeigen.
class ProjektInfo {
  const ProjektInfo({required this.name, required this.firma});

  final String name;
  final String firma;

  /// Titel für Fenster, Kopfzeile und Server-Meldungen.
  String get titel => '$name – $firma';
}

const terrassenplaner = ProjektInfo(
  name: 'Terrassenplaner',
  firma: 'ALTO HOLZ',
);
