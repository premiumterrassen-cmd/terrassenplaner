import 'dart:math' as math;

/// Abstand in Millimetern, unter dem zwei Punkte als gleich gelten (M4-01).
const geometrieToleranz = 1e-6;

/// Punkt bzw. Vektor der Draufsicht in Millimetern (M4-01): `x` längs,
/// `y` quer, Punkt A der Terrasse liegt bei (0|0). Die Zeichnung zeigt `y`
/// nach unten, im 3D-Modell (M3-10) ist es die z-Achse. Umlaufsinn und
/// Drehrichtung sind mathematisch benannt (als zeige `y` nach oben) – in
/// der Zeichnung erscheinen sie gespiegelt.
final class Punkt {
  const Punkt(this.x, this.y);

  static const ursprung = Punkt(0, 0);

  final double x;
  final double y;

  Punkt operator +(Punkt p) => Punkt(x + p.x, y + p.y);
  Punkt operator -(Punkt p) => Punkt(x - p.x, y - p.y);
  Punkt operator *(double faktor) => Punkt(x * faktor, y * faktor);

  /// Skalarprodukt.
  double punktprodukt(Punkt p) => x * p.x + y * p.y;

  /// z-Komponente des Kreuzprodukts: > 0, wenn [p] links von diesem Vektor liegt.
  double kreuz(Punkt p) => x * p.y - y * p.x;

  double get laenge => math.sqrt(x * x + y * y);

  double abstand(Punkt p) => (this - p).laenge;

  /// Richtung als Winkel im Bogenmaß gegen die x-Achse (−π … π).
  double get richtung => math.atan2(y, x);

  /// Um [winkel] (Bogenmaß, gegen den Uhrzeigersinn) um [mitte] gedreht.
  Punkt gedreht(double winkel, [Punkt mitte = ursprung]) {
    final c = math.cos(winkel);
    final s = math.sin(winkel);
    final v = this - mitte;
    return Punkt(mitte.x + v.x * c - v.y * s, mitte.y + v.x * s + v.y * c);
  }

  /// Senkrechter Vektor gleicher Länge, nach links gedreht.
  Punkt get links => Punkt(-y, x);

  /// Gleiche Richtung, Länge 1.
  Punkt get einheit => this * (1 / laenge);

  bool gleich(Punkt p, [double toleranz = geometrieToleranz]) =>
      abstand(p) < toleranz;

  @override
  bool operator ==(Object other) =>
      other is Punkt && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x|$y)';
}

/// Achsparalleles Rechteck, das eine Form umschließt.
final class Huellrechteck {
  const Huellrechteck(this.min, this.max);

  /// Kleinstes Rechteck um alle [punkte].
  factory Huellrechteck.um(Iterable<Punkt> punkte) {
    final xs = [for (final p in punkte) p.x];
    final ys = [for (final p in punkte) p.y];
    return Huellrechteck(
      Punkt(xs.reduce(math.min), ys.reduce(math.min)),
      Punkt(xs.reduce(math.max), ys.reduce(math.max)),
    );
  }

  final Punkt min;
  final Punkt max;

  double get breite => max.x - min.x;
  double get hoehe => max.y - min.y;
  Punkt get mitte => (min + max) * 0.5;

  /// Überschneidung mit [u], Berührung eingeschlossen.
  bool beruehrt(Huellrechteck u) =>
      !(u.min.x > max.x ||
          u.max.x < min.x ||
          u.min.y > max.y ||
          u.max.y < min.y);
}
