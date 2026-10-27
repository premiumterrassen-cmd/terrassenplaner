import '../artikel/einheiten.dart';
import '../geometrie/kontur.dart';

/// Terrassenformen des Grundrisses (Fachkonzept 1.1); weitere folgen mit
/// M4-03 bis M4-08. Die Nummer ist der Wert im Transportformat und bleibt
/// fest.
enum Terrassenform {
  rechteck(0);

  const Terrassenform(this.nummer);

  final int nummer;
}

/// Grundriss einer Terrasse (M4): Form und Maße; die Kontur rechnet der
/// Geometrie-Kern (M4-01).
sealed class Grundriss {
  const Grundriss();

  /// Grundriss aus [form] und [masse] (Transportformat).
  factory Grundriss.aus(Terrassenform form, List<Millimeter> masse) =>
      switch (form) {
        Terrassenform.rechteck => switch (masse) {
          [final ab, final bc] => RechteckGrundriss(ab, bc),
          _ => throw ArgumentError.value(
            masse.length,
            'masse',
            'Rechteck braucht zwei Maße',
          ),
        },
      };

  Terrassenform get form;

  /// Maße in der Reihenfolge der Eingabefelder (Transportformat).
  List<Millimeter> get masse;

  Kontur get kontur;

  /// Kleinste und größte Seitenlänge, die der Planer annimmt (Annahme bis
  /// zur Klärung mit Alexander: wie der 3D-Prototyp, M3-10).
  static const kleinsteSeite = Millimeter(500);
  static const groessteSeite = Millimeter(20000);

  static Millimeter _seite(Millimeter wert, String name) {
    if (wert < kleinsteSeite || wert > groessteSeite) {
      throw ArgumentError.value(
        wert.mm,
        name,
        'muss zwischen ${kleinsteSeite.mm ~/ 10} und '
        '${groessteSeite.mm ~/ 10} cm liegen',
      );
    }
    return wert;
  }
}

/// Rechteck (M4-02), die Standardform: A oben links, A—B längs, B—C quer;
/// in der Zeichnung liegt D—C unten (Fachkonzept 1.1).
final class RechteckGrundriss extends Grundriss {
  RechteckGrundriss(Millimeter ab, Millimeter bc)
    : this._(Grundriss._seite(ab, 'ab'), Grundriss._seite(bc, 'bc'));

  const RechteckGrundriss._(this.ab, this.bc);

  /// Startkonfiguration des alten Planers (F01): 480 × 309 cm.
  static const start = RechteckGrundriss._(Millimeter(4800), Millimeter(3090));

  final Millimeter ab;
  final Millimeter bc;

  @override
  Terrassenform get form => Terrassenform.rechteck;

  @override
  List<Millimeter> get masse => [ab, bc];

  @override
  Kontur get kontur => Kontur.rechteck(ab.mm.toDouble(), bc.mm.toDouble());

  @override
  bool operator ==(Object other) =>
      other is RechteckGrundriss && other.ab == ab && other.bc == bc;

  @override
  int get hashCode => Object.hashAll(masse);
}
