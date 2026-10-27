import '../artikel/einheiten.dart';
import '../geometrie/kontur.dart';
import '../geometrie/punkt.dart';

/// Terrassenformen des Grundrisses (Fachkonzept 1.1); weitere folgen mit
/// M4-04 bis M4-08. Die Nummer ist der Wert im Transportformat und bleibt
/// fest.
enum Terrassenform {
  rechteck(0, ['A — B', 'B — C']),
  lForm(1, ['A — B', 'B — C', 'C — D', 'D — E']);

  const Terrassenform(this.nummer, this.eingabekanten);

  final int nummer;

  /// Kanten, deren Maße eingegeben werden, in der Reihenfolge von
  /// [Grundriss.masse]; die übrigen ergeben sich daraus.
  final List<String> eingabekanten;

  /// Vorgabemaße nach der Formwahl (Fachkonzept 1.1).
  Grundriss get vorgabe => switch (this) {
    rechteck => RechteckGrundriss.start,
    lForm => LGrundriss.vorgabe,
  };
}

/// Grundriss einer Terrasse (M4): Form und eingegebene Maße; daraus die
/// Eckpunkte ab A und die Kontur für den Geometrie-Kern (M4-01).
sealed class Grundriss {
  const Grundriss();

  /// Grundriss aus [form] und [masse] (Transportformat, Eingabefelder).
  factory Grundriss.aus(Terrassenform form, List<Millimeter> masse) {
    if (masse.length != form.eingabekanten.length) {
      throw ArgumentError.value(
        masse.length,
        'masse',
        'braucht ${form.eingabekanten.length} Maße',
      );
    }
    return switch (form) {
      Terrassenform.rechteck => RechteckGrundriss(masse[0], masse[1]),
      Terrassenform.lForm => LGrundriss(masse[0], masse[1], masse[2], masse[3]),
    };
  }

  /// Kleinste und größte Seitenlänge, die der Planer annimmt (größte:
  /// Alexander, 27.10.2026).
  static const kleinsteSeite = Millimeter(500);
  static const groessteSeite = Millimeter(30000);

  Terrassenform get form;

  /// Eingegebene Maße in der Reihenfolge von [Terrassenform.eingabekanten].
  List<Millimeter> get masse;

  /// Eckpunkte in mm ab A (A oben links, in der Zeichnung im Uhrzeigersinn).
  List<Punkt> get ecken;

  Kontur get kontur => Kontur(ecken);

  /// Kopie mit neuem Wert für das Eingabemaß [index].
  Grundriss mitMass(int index, Millimeter wert) =>
      Grundriss.aus(form, [...masse]..[index] = wert);

  /// Prüft alle Seiten, auch die abgeleiteten, gegen die Grenzen; der Name
  /// im Fehler ist die Kante in Kleinbuchstaben (z. B. `ef`).
  void _pruefeSeiten() {
    final e = ecken;
    for (var i = 0; i < e.length; i++) {
      final laenge = Millimeter(e[i].abstand(e[(i + 1) % e.length]).round());
      if (laenge < kleinsteSeite || laenge > groessteSeite) {
        throw ArgumentError.value(
          laenge.mm,
          _kante(i, e.length),
          'muss zwischen ${kleinsteSeite.mm ~/ 10} und '
          '${groessteSeite.mm ~/ 10} cm liegen',
        );
      }
    }
  }

  static String _kante(int i, int anzahl) =>
      String.fromCharCodes([97 + i, 97 + (i + 1) % anzahl]);

  @override
  bool operator ==(Object other) {
    if (other is! Grundriss || other.form != form) return false;
    final a = masse, b = other.masse;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll([form, ...masse]);
}

/// Rechteck (M4-02), die Standardform: A—B längs, B—C quer; in der
/// Zeichnung liegt D—C unten (Fachkonzept 1.1).
final class RechteckGrundriss extends Grundriss {
  RechteckGrundriss(this.ab, this.bc) {
    _pruefeSeiten();
  }

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
  List<Punkt> get ecken {
    final x = ab.mm.toDouble(), y = bc.mm.toDouble();
    return [Punkt.ursprung, Punkt(x, 0), Punkt(x, y), Punkt(0, y)];
  }
}

/// L-Form (M4-03): Ausschnitt oben rechts. Eingegeben werden A—B, B—C, C—D
/// und D—E; E—F = A—B + C—D und F—A = B—C + D—E (Fachkonzept 1.1).
final class LGrundriss extends Grundriss {
  LGrundriss(this.ab, this.bc, this.cd, this.de) {
    _pruefeSeiten();
  }

  const LGrundriss._(this.ab, this.bc, this.cd, this.de);

  /// Vorgabemaße des alten Planers: 270, 180, 270, 180 cm (14,58 m²).
  static const vorgabe = LGrundriss._(
    Millimeter(2700),
    Millimeter(1800),
    Millimeter(2700),
    Millimeter(1800),
  );

  final Millimeter ab;
  final Millimeter bc;
  final Millimeter cd;
  final Millimeter de;

  @override
  Terrassenform get form => Terrassenform.lForm;

  @override
  List<Millimeter> get masse => [ab, bc, cd, de];

  @override
  List<Punkt> get ecken {
    final b = ab.mm.toDouble(), c = bc.mm.toDouble();
    final d = b + cd.mm, e = c + de.mm;
    return [
      Punkt.ursprung,
      Punkt(b, 0),
      Punkt(b, c),
      Punkt(d, c),
      Punkt(d, e),
      Punkt(0, e),
    ];
  }
}
