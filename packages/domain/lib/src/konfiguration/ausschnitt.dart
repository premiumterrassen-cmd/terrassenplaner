import '../artikel/einheiten.dart';
import '../geometrie/kontur.dart';
import '../geometrie/punkt.dart';
import 'grundriss.dart';

/// Ausschnitt im Grundriss (Fachkonzept 1.4, M4-06): ein Rechteck als leere
/// Fläche, Lage über die Koordinaten seiner Ecke oben links (Punkt A der
/// Terrasse = 0|0, negative Werte möglich). Weitere Formen, „anderer
/// Terrassenbelag“ und die Prüfungen folgen mit M4-12.
final class Ausschnitt {
  Ausschnitt({
    required this.bezeichnung,
    required this.x,
    required this.y,
    required this.laenge,
    required this.breite,
  }) {
    if (bezeichnung.isEmpty || bezeichnung.length > 10) {
      throw ArgumentError.value(
        bezeichnung,
        'bezeichnung',
        'braucht 1 bis 10 Zeichen',
      );
    }
    for (final (name, wert) in [('laenge', laenge), ('breite', breite)]) {
      if (wert < kleinsteSeite || wert > Grundriss.groessteSeite) {
        throw ArgumentError.value(
          wert.mm,
          name,
          'muss zwischen ${kleinsteSeite.mm ~/ 10} und '
          '${Grundriss.groessteSeite.mm ~/ 10} cm liegen',
        );
      }
    }
  }

  const Ausschnitt._(
    this.bezeichnung,
    this.x,
    this.y,
    this.laenge,
    this.breite,
  );

  /// Ausschnitt der O-Form im alten Planer: 240 × 180 cm mittig in
  /// 540 × 360 cm (Fachkonzept 1.1).
  static const oForm = Ausschnitt._(
    'A1',
    Millimeter(1500),
    Millimeter(900),
    Millimeter(2400),
    Millimeter(1800),
  );

  /// Kleinste Seite eines Ausschnitts (z. B. für einen Pfosten).
  static const kleinsteSeite = Millimeter(100);

  /// Bezeichnung wie im alten Planer („A1“, höchstens 10 Zeichen).
  final String bezeichnung;
  final Millimeter x;
  final Millimeter y;
  final Millimeter laenge;
  final Millimeter breite;

  /// Maße in der Reihenfolge der Eingabefelder: X, Y, Länge, Breite.
  List<Millimeter> get masse => [x, y, laenge, breite];

  Kontur get kontur => Kontur.rechteck(
    laenge.mm.toDouble(),
    breite.mm.toDouble(),
    Punkt(x.mm.toDouble(), y.mm.toDouble()),
  );

  /// Kopie mit neuem Wert für das Maß [index] aus [masse].
  Ausschnitt mitMass(int index, Millimeter wert) {
    final m = [...masse]..[index] = wert;
    return Ausschnitt(
      bezeichnung: bezeichnung,
      x: m[0],
      y: m[1],
      laenge: m[2],
      breite: m[3],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Ausschnitt &&
      other.bezeichnung == bezeichnung &&
      other.x == x &&
      other.y == y &&
      other.laenge == laenge &&
      other.breite == breite;

  @override
  int get hashCode => Object.hashAll([bezeichnung, ...masse]);
}
