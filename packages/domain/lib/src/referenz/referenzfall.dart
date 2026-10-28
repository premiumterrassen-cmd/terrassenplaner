/// Referenzfall aus einer Planungsunterlage des alten Planers (M1-02):
/// anonymisierte Eingaben und die Ergebnisse, die der alte Planer dafür
/// geliefert hat. Prüfmaßstab für alle Berechnungen des neuen Planers.
///
/// Quelle sind die Planungsunterlagen-PDFs und – wo vorhanden – der Export
/// der Materialliste. Fehlende Seiten bleiben leer (`null` bzw. leere Liste);
/// nichts wird ergänzt.
final class Referenzfall {
  /// Liest einen Fall aus seiner JSON-Darstellung.
  factory Referenzfall.ausJson(Map<String, Object?> json) {
    final quelle = _map(json['quelle']);
    final eingaben = _map(json['eingaben']);
    final erwartet = _map(json['erwartet']);
    return Referenzfall._(
      id: json['id']! as String,
      konfigurationsnummer: quelle['konfigurationsnummer']! as String,
      version: quelle['version']! as int,
      datum: DateTime.parse(quelle['datum']! as String),
      mitExport: quelle['export']! as bool,
      grundriss: ReferenzGrundriss.ausJson(_map(eingaben['grundriss'])),
      flaecheM2: _zahl(eingaben['flaeche_m2']),
      volumenM3: _zahl(eingaben['volumen_m3']),
      belag: eingaben['belag'] as String?,
      verlegerichtung: eingaben['verlegerichtung'] as String?,
      unterkonstruktion: eingaben['unterkonstruktion'] as String?,
      aufbauhoehenCm: _zahlen(eingaben['aufbauhoehen_cm']),
      ukStueckliste: _liste(
        erwartet['unterkonstruktion_stueckliste'],
        Stueckposition.ausJson,
      ),
      zuschnittUnterkonstruktion: _liste(
        erwartet['zuschnitt_unterkonstruktion'],
        Zuschnitt.ausJson,
      ),
      dielen: _liste(erwartet['dielen'], Dielenposition.ausJson),
      zuschnittDeckbelag: _liste(
        erwartet['zuschnitt_deckbelag'],
        Zuschnitt.ausJson,
      ),
      materialliste: _liste(
        erwartet['materialliste'],
        Materialposition.ausJson,
      ),
      hinweise: List.unmodifiable(json['hinweise']! as List<Object?>),
    );
  }

  Referenzfall._({
    required this.id,
    required this.konfigurationsnummer,
    required this.version,
    required this.datum,
    required this.mitExport,
    required this.grundriss,
    required this.flaecheM2,
    required this.volumenM3,
    required this.belag,
    required this.verlegerichtung,
    required this.unterkonstruktion,
    required this.aufbauhoehenCm,
    required this.ukStueckliste,
    required this.zuschnittUnterkonstruktion,
    required this.dielen,
    required this.zuschnittDeckbelag,
    required this.materialliste,
    required this.hinweise,
  });

  /// `<konfigurationsnummer>-v<version>`.
  final String id;
  final String konfigurationsnummer;
  final int version;
  final DateTime datum;

  /// Ob die Materialliste aus einem Export des alten Planers stammt.
  final bool mitExport;

  final ReferenzGrundriss grundriss;
  final double? flaecheM2;
  final double? volumenM3;
  final String? belag;
  final String? verlegerichtung;
  final String? unterkonstruktion;

  /// Aufbauhöhe je Eckpunkt in cm (fehlt in vielen Unterlagen).
  final Map<String, double>? aufbauhoehenCm;

  final List<Stueckposition> ukStueckliste;
  final List<Zuschnitt> zuschnittUnterkonstruktion;
  final List<Dielenposition> dielen;
  final List<Zuschnitt> zuschnittDeckbelag;
  final List<Materialposition> materialliste;

  /// Besonderheiten und Unsicherheiten beim Auslesen.
  final List<Object?> hinweise;

  /// Anzahl der zugeschnittenen Deckbelag-Stücke (Schnitte > 0).
  int get deckbelagStuecke => zuschnittDeckbelag.fold(
    0,
    (summe, z) => summe + z.menge * z.schnitteCm.where((s) => s > 0).length,
  );

  /// Anzahl der Dielen laut „Dielen/Platten nach Nummer“.
  int get dielenStuecke => dielen.fold(0, (summe, d) => summe + d.stueck);
}

/// Grundriss der Terrasse: Form, Eckpunkte und Kantenlängen.
final class ReferenzGrundriss {
  ReferenzGrundriss.ausJson(Map<String, Object?> json)
    : form = json['form']! as String,
      eckpunkte = List.unmodifiable(json['eckpunkte']! as List<Object?>),
      kantenCm = _kanten(json['kanten_cm']),
      rundungen = json['rundungen']! as bool,
      ausschnitte = _liste(json['ausschnitte'], ReferenzAusschnitt.ausJson);

  /// Rechteck, L-Form, T-Form, U-Form, O-Form, Kreis oder Freiform.
  final String form;
  final List<Object?> eckpunkte;

  /// Kante (`A-B`) → Länge in cm; `null`, wenn in der Zeichnung ohne Maß.
  final Map<String, double?> kantenCm;
  final bool rundungen;
  final List<ReferenzAusschnitt> ausschnitte;
}

/// Ausschnitt oder Teilfläche im Grundriss (A1 …).
final class ReferenzAusschnitt {
  ReferenzAusschnitt.ausJson(Map<String, Object?> json)
    : name = json['name']! as String,
      funktion = json['funktion']! as String,
      kantenCm = _kanten(json['kanten_cm']);

  final String name;

  /// „leere Fläche“, „anderer Terrassenbelag“ oder „unbekannt“.
  final String funktion;
  final Map<String, double?> kantenCm;
}

/// Zeile einer Stückliste (Artikel, Länge, Stück).
final class Stueckposition {
  Stueckposition.ausJson(Map<String, Object?> json)
    : artikel = json['artikel']! as String,
      laengeCm = _zahl(json['laenge_cm'])!,
      stueck = json['stueck']! as int;

  final String artikel;
  final double laengeCm;
  final int stueck;
}

/// Zeile eines Zuschnittplans: [menge] Ausgangsstücke, je in [schnitteCm]
/// zerlegt.
final class Zuschnitt {
  Zuschnitt.ausJson(Map<String, Object?> json)
    : artikel = json['artikel']! as String,
      ausgangslaengeCm = _zahl(json['ausgangslaenge_cm'])!,
      menge = json['menge']! as int,
      schnitteCm = List.unmodifiable([
        for (final s in json['schnitte_cm']! as List<Object?>) _zahl(s)!,
      ]);

  final String artikel;
  final double ausgangslaengeCm;
  final int menge;
  final List<double> schnitteCm;

  /// Rest je Ausgangsstück (Verschnitt) in cm.
  double get restCm =>
      ausgangslaengeCm - schnitteCm.fold(0.0, (summe, s) => summe + s);
}

/// Diele bzw. Platte nach Nummer (Länge × Breite, Stück).
final class Dielenposition {
  Dielenposition.ausJson(Map<String, Object?> json)
    : artikel = json['artikel']! as String,
      laengeCm = _zahl(json['laenge_cm'])!,
      breiteCm = _zahl(json['breite_cm'])!,
      stueck = json['stueck']! as int;

  final String artikel;
  final double laengeCm;
  final double breiteCm;
  final int stueck;
}

/// Position der Materialliste aus dem Export des alten Planers.
final class Materialposition {
  Materialposition.ausJson(Map<String, Object?> json)
    : artikelnummer = json['artikelnummer'] as String?,
      bezeichnung = json['bezeichnung']! as String,
      laengeMm = json['laenge_mm'] as int?,
      anzahl = json['anzahl']! as int,
      einheit = json['einheit']! as String,
      typ = json['typ']! as String;

  /// Artikelnummer des Shops; `null`, wo der Export nur eine
  /// Herstellernummer hatte (nicht übernommen, B-023).
  final String? artikelnummer;
  final String bezeichnung;
  final int? laengeMm;
  final int anzahl;
  final String einheit;

  /// Artikeltyp des alten Planers (Deckbelag, Unterkonstruktion …).
  final String typ;
}

Map<String, Object?> _map(Object? wert) => wert! as Map<String, Object?>;

double? _zahl(Object? wert) => (wert as num?)?.toDouble();

Map<String, double>? _zahlen(Object? wert) => wert == null
    ? null
    : Map.unmodifiable({
        for (final MapEntry(:key, :value) in _map(wert).entries)
          key: _zahl(value)!,
      });

Map<String, double?> _kanten(Object? wert) => Map.unmodifiable({
  for (final MapEntry(:key, :value) in _map(wert).entries) key: _zahl(value),
});

List<T> _liste<T>(Object? wert, T Function(Map<String, Object?>) lies) =>
    List.unmodifiable([
      for (final eintrag in wert! as List<Object?>) lies(_map(eintrag)),
    ]);
