/// Verlauf der Planungsstände für Rückgängig und Wiederherstellen (M3-03).
///
/// Speichert unveränderliche Stände – Rückgängig liefert deshalb exakt den
/// vorherigen Stand zurück, nicht eine Neuberechnung. Ein neuer Stand nach
/// Rückgängig verwirft die wiederherstellbaren Stände.
final class Verlauf<T extends Object> {
  Verlauf(T anfang, {this.hoechstens = 200}) : _staende = [anfang] {
    if (hoechstens < 1) {
      throw ArgumentError.value(hoechstens, 'hoechstens', 'mindestens 1');
    }
  }

  /// Wie viele Schritte rückgängig gemacht werden können (älteste fallen weg).
  final int hoechstens;

  final List<T> _staende;
  var _position = 0;

  /// Der aktuelle Stand.
  T get aktuell => _staende[_position];

  bool get kannRueckgaengig => _position > 0;
  bool get kannWiederherstellen => _position < _staende.length - 1;

  /// Übernimmt [neu] als aktuellen Stand; ein gleicher Stand ändert nichts.
  void setze(T neu) {
    if (neu == aktuell) return;
    _staende
      ..removeRange(_position + 1, _staende.length)
      ..add(neu);
    if (_staende.length > hoechstens + 1) _staende.removeAt(0);
    _position = _staende.length - 1;
  }

  /// Einen Schritt zurück; ohne Vorgänger bleibt alles, wie es ist.
  T rueckgaengig() {
    if (kannRueckgaengig) _position--;
    return aktuell;
  }

  /// Einen Schritt vor; ohne Nachfolger bleibt alles, wie es ist.
  T wiederherstellen() {
    if (kannWiederherstellen) _position++;
    return aktuell;
  }

  /// Setzt auf [anfang] zurück und leert den Verlauf.
  void zuruecksetzen(T anfang) {
    _staende
      ..clear()
      ..add(anfang);
    _position = 0;
  }
}
