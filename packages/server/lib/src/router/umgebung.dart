/// Hilfen zum Lesen der Umgebungsvariablen `PLANER_*`.
abstract final class Umgebung {
  /// Wert oder [standard], wenn die Variable fehlt.
  static String wert(Map<String, String> u, String name, String standard) =>
      u[name] ?? standard;

  /// Pflichtvariable (z. B. Geheimnisse) – fehlt sie, bricht der Start ab.
  static String pflicht(Map<String, String> u, String name) {
    final wert = u[name];
    if (wert == null || wert.isEmpty) {
      throw FormatException('Pflichtvariable fehlt', name);
    }
    return wert;
  }

  /// TCP-Port 0–65535 aus [name] oder [standard].
  static int port(Map<String, String> u, String name, int standard) {
    final text = u[name];
    if (text == null) return standard;
    final port = int.tryParse(text);
    if (port == null || port < 0 || port > 65535) {
      throw FormatException('Ungültiger Port in $name', text);
    }
    return port;
  }
}
