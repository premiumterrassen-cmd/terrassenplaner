import 'package:flutter/foundation.dart';

/// Hält eine Antwort des Servers, die die Oberfläche anzeigt (Beläge M5-01,
/// Zubehör M8-01). Die App rechnet nichts selbst und merkt sich nichts
/// dauerhaft.
class LadeQuelle<T> extends ChangeNotifier {
  LadeQuelle(this.lade) {
    ladeNeu();
  }

  final Future<T> Function() lade;

  T? _auswahl;
  Object? _fehler;

  /// Geladene Antwort; `null`, solange nichts geladen ist.
  T? get auswahl => _auswahl;

  /// Fehler des letzten Ladens; `null`, wenn es gelang.
  Object? get fehler => _fehler;

  Future<void> ladeNeu() async {
    _fehler = null;
    notifyListeners();
    try {
      _auswahl = await lade();
    } on Object catch (fehler) {
      _fehler = fehler;
    }
    notifyListeners();
  }
}
