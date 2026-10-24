/// Verzeichnis der aufbereiteten Artikelbilder neben der Web-App (M2-07).
const artikelbilderPfad = 'artikelbilder';

/// Dateiname des aufbereiteten Bildes: Name aus den Artikeldaten ohne
/// Endung, immer WebP (z. B. `Diele_60x23.jpg` → `Diele_60x23.webp`).
String artikelbildDatei(String bild) {
  final punkt = bild.lastIndexOf('.');
  return '${punkt <= 0 ? bild : bild.substring(0, punkt)}.webp';
}

/// Relative Adresse des Bildes für die App – Sonderzeichen kodiert.
String artikelbildAdresse(String bild) =>
    '$artikelbilderPfad/${Uri.encodeComponent(artikelbildDatei(bild))}';
