import 'referenzfall.dart';

/// Referenzkonfiguration aus dem alten Planer (M1-03): gezielt eingestellte
/// Eingaben – je Fall eine Option abweichend von der Startkonfiguration F01 –
/// und die Ergebnisse, die der alte Planer dafür anzeigt und exportiert.
///
/// Quelle sind die Mitarbeiter-Exporte „CSV-Download“ (Materialliste) und
/// „Zuschnittliste“ – dieselben Dateien, die in das ERP importiert werden.
/// Die Eingaben bleiben eine offene Map, bis das Eingabemodell des neuen
/// Planers steht.
final class Referenzkonfiguration {
  /// Liest eine Konfiguration aus ihrer JSON-Darstellung.
  factory Referenzkonfiguration.ausJson(Map<String, Object?> json) {
    final anzeige = json['anzeige']! as Map<String, Object?>;
    return Referenzkonfiguration._(
      id: json['id']! as String,
      beschreibung: json['beschreibung']! as String,
      eingaben: Map.unmodifiable(json['eingaben']! as Map<String, Object?>),
      flaecheM2: _zahl(anzeige['flaeche_m2'])!,
      verschnittProzent: _zahl(anzeige['verschnitt_prozent']),
      volumenM3: _zahl(anzeige['volumen_m3']),
      treppenmasseCm: anzeige['treppenmasse_cm'] == null
          ? null
          : List.unmodifiable([
              for (final m in anzeige['treppenmasse_cm']! as List<Object?>)
                _zahl(m)!,
            ]),
      materialliste: List.unmodifiable([
        for (final m in json['materialliste']! as List<Object?>)
          Materialposition.ausJson(m! as Map<String, Object?>),
      ]),
      zuschnitt: List.unmodifiable([
        for (final z in json['zuschnitt']! as List<Object?>)
          Zuschnitt.ausJson(z! as Map<String, Object?>),
      ]),
    );
  }

  Referenzkonfiguration._({
    required this.id,
    required this.beschreibung,
    required this.eingaben,
    required this.flaecheM2,
    required this.verschnittProzent,
    required this.volumenM3,
    required this.treppenmasseCm,
    required this.materialliste,
    required this.zuschnitt,
  });

  /// `F01` … `F43`.
  final String id;

  /// Was gegenüber der Startkonfiguration verstellt wurde, und Befunde.
  final String beschreibung;

  /// Vollständige Eingaben (Startkonfiguration + Abweichung).
  final Map<String, Object?> eingaben;

  /// Angezeigte Fläche in m².
  final double flaecheM2;

  /// Angezeigter Verschnitt in Prozent (`null`, wo nicht erfasst).
  final double? verschnittProzent;

  /// Angezeigtes Volumen in m³ (`null` bei Holzfliesen).
  final double? volumenM3;

  /// Angezeigte Treppenmaße L × B × H in cm (nur mit Treppe).
  final List<double>? treppenmasseCm;

  /// Materialliste aus dem „CSV-Download“ (ohne Preise).
  final List<Materialposition> materialliste;

  /// Zuschnittliste aus dem Export (Deckbelag und Unterkonstruktion).
  final List<Zuschnitt> zuschnitt;
}

double? _zahl(Object? wert) => (wert as num?)?.toDouble();
