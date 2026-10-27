import 'package:web/web.dart' as web;

import 'einstellungs_speicher.dart';

/// `localStorage` des Browsers; Fehler fängt [SichererSpeicher] ab.
EinstellungsSpeicher browserSpeicher() => _LocalStorage();

final class _LocalStorage implements EinstellungsSpeicher {
  @override
  String? lies(String schluessel) =>
      web.window.localStorage.getItem(schluessel);

  @override
  void schreibe(String schluessel, String wert) =>
      web.window.localStorage.setItem(schluessel, wert);
}
