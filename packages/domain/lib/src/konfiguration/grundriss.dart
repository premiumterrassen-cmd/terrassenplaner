import '../artikel/einheiten.dart';
import '../geometrie/kontur.dart';
import '../geometrie/punkt.dart';

/// Terrassenformen des Grundrisses (Fachkonzept 1.1). Die Nummer ist der
/// Wert im Transportformat und bleibt fest.
enum Terrassenform {
  rechteck(0, ['A — B', 'B — C']),
  lForm(1, ['A — B', 'B — C', 'C — D', 'D — E']),
  tForm(2, ['B — C', 'C — D', 'D — E', 'E — F', 'G — H', 'H — A']),
  uForm(3, ['A — B', 'B — C', 'C — D', 'E — F', 'F — G', 'H — A']),

  /// Rechteck mit innerem Ausschnitt; der Ausschnitt ist ein eigener Block
  /// (Fachkonzept 1.1/1.4).
  oForm(4, ['A — B', 'B — C']),
  kreis(5, ['Radius']),

  /// Gezeichnet statt bemaßt (M4-08): keine festen Eingabefelder.
  freiform(6, []);

  const Terrassenform(this.nummer, this.eingabekanten);

  final int nummer;

  /// Kanten, deren Maße eingegeben werden, in der Reihenfolge von
  /// [Grundriss.masse]; die übrigen ergeben sich daraus.
  final List<String> eingabekanten;

  /// Vorgabemaße nach der Formwahl (Fachkonzept 1.1).
  Grundriss get vorgabe => switch (this) {
    rechteck => RechteckGrundriss.start,
    lForm => LGrundriss.vorgabe,
    tForm => TGrundriss.vorgabe,
    uForm => UGrundriss.vorgabe,
    oForm => OGrundriss.vorgabe,
    kreis => KreisGrundriss.vorgabe,
    freiform => FreiformGrundriss.leer,
  };
}

/// Grundriss einer Terrasse (M4): Form und eingegebene Maße; daraus die
/// Eckpunkte ab A und die Kontur für den Geometrie-Kern (M4-01).
sealed class Grundriss {
  const Grundriss();

  /// Grundriss aus [form] und [masse] (Transportformat, Eingabefelder).
  factory Grundriss.aus(Terrassenform form, List<Millimeter> masse) {
    // die Freiform hat keine festen Felder und prüft selbst
    if (form != Terrassenform.freiform &&
        masse.length != form.eingabekanten.length) {
      throw ArgumentError.value(
        masse.length,
        'masse',
        'braucht ${form.eingabekanten.length} Maße',
      );
    }
    return switch (form) {
      Terrassenform.rechteck => RechteckGrundriss(masse[0], masse[1]),
      Terrassenform.lForm => LGrundriss(masse[0], masse[1], masse[2], masse[3]),
      Terrassenform.tForm => TGrundriss(
        masse[0],
        masse[1],
        masse[2],
        masse[3],
        masse[4],
        masse[5],
      ),
      Terrassenform.oForm => OGrundriss(masse[0], masse[1]),
      Terrassenform.kreis => KreisGrundriss(masse[0]),
      Terrassenform.freiform => FreiformGrundriss._aus(masse),
      Terrassenform.uForm => UGrundriss(
        masse[0],
        masse[1],
        masse[2],
        masse[3],
        masse[4],
        masse[5],
      ),
    };
  }

  /// Kleinste und größte Seitenlänge, die der Planer annimmt (größte:
  /// Alexander, 27.10.2026).
  static const kleinsteSeite = Millimeter(500);
  static const groessteSeite = Millimeter(30000);

  Terrassenform get form;

  /// Eingegebene Maße in der Reihenfolge von [Terrassenform.eingabekanten].
  List<Millimeter> get masse;

  /// Eckpunkte in mm ab A (A oben links, in der Zeichnung im Uhrzeigersinn);
  /// der Kreis hat keine.
  List<Punkt> get ecken;

  Kontur get kontur => Kontur(ecken);

  /// Kopie mit neuem Wert für das Eingabemaß [index].
  Grundriss mitMass(int index, Millimeter wert) =>
      Grundriss.aus(form, [...masse]..[index] = wert);

  /// Prüft alle Seiten, auch die abgeleiteten, gegen die Grenzen; der Name
  /// im Fehler ist die Kante in Kleinbuchstaben (z. B. `ef`).
  void _pruefeSeiten() => _pruefeKanten(ecken, ecken.length, kleinsteSeite);

  /// Prüft die ersten [anzahl] Kanten (zyklisch) gegen [kleinste] bis
  /// [groessteSeite].
  static void _pruefeKanten(List<Punkt> e, int anzahl, Millimeter kleinste) {
    for (var i = 0; i < anzahl; i++) {
      final laenge = Millimeter(e[i].abstand(e[(i + 1) % e.length]).round());
      if (laenge < kleinste || laenge > groessteSeite) {
        throw ArgumentError.value(
          laenge.mm,
          _kante(i, e.length),
          'muss zwischen ${kleinste.mm ~/ 10} und '
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
    if (a.length != b.length) return false;
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

/// Kreis (M4-07): eingegeben wird der Radius; der Mittelpunkt liegt so, dass
/// der Kreis oben und links an 0|0 grenzt. Die Fläche ist exakt π·r² – der
/// alte Planer rechnet ein Vieleck (Ø 360 cm: 10,150 statt 10,179 m²), das
/// wird nicht übernommen (Alexander, 27.10.2026).
final class KreisGrundriss extends Grundriss {
  KreisGrundriss(this.radius) {
    final durchmesser = radius * 2;
    if (durchmesser < Grundriss.kleinsteSeite ||
        durchmesser > Grundriss.groessteSeite) {
      throw ArgumentError.value(
        radius.mm,
        'radius',
        'Durchmesser muss zwischen ${Grundriss.kleinsteSeite.mm ~/ 10} und '
            '${Grundriss.groessteSeite.mm ~/ 10} cm liegen',
      );
    }
  }

  const KreisGrundriss._(this.radius);

  /// Vorgabe des alten Planers: Ø 360 cm (Fachkonzept 1.1).
  static const vorgabe = KreisGrundriss._(Millimeter(1800));

  final Millimeter radius;

  @override
  Terrassenform get form => Terrassenform.kreis;

  @override
  List<Millimeter> get masse => [radius];

  @override
  List<Punkt> get ecken => const [];

  @override
  Kontur get kontur {
    final r = radius.mm.toDouble();
    return Kontur.kreis(Punkt(r, r), r);
  }
}

/// Außenrand der O-Form (M4-06): ein Rechteck wie [RechteckGrundriss], die
/// innere Aussparung ist ein [Ausschnitt] im Planungsstand.
final class OGrundriss extends Grundriss {
  OGrundriss(this.ab, this.bc) {
    _pruefeSeiten();
  }

  const OGrundriss._(this.ab, this.bc);

  /// Vorgabe des alten Planers: außen 540 × 360 cm (Fachkonzept 1.1).
  static const vorgabe = OGrundriss._(Millimeter(5400), Millimeter(3600));

  final Millimeter ab;
  final Millimeter bc;

  @override
  Terrassenform get form => Terrassenform.oForm;

  @override
  List<Millimeter> get masse => [ab, bc];

  @override
  List<Punkt> get ecken => RechteckGrundriss._(ab, bc).ecken;
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

/// T-Form (M4-04): Balken oben, Steg nach unten. Eingegeben werden B—C,
/// C—D, D—E, E—F, G—H und H—A (Fachkonzept 1.1); daraus
/// A—B = G—H + E—F + C—D und F—G = B—C + D—E − H—A, damit die Unterkante
/// des Stegs gerade bleibt.
final class TGrundriss extends Grundriss {
  TGrundriss(this.bc, this.cd, this.de, this.ef, this.gh, this.ha) {
    _pruefeSeiten();
  }

  const TGrundriss._(this.bc, this.cd, this.de, this.ef, this.gh, this.ha);

  /// Vorgabemaße des alten Planers: A—B 405, sonst 180 bzw. 135 cm
  /// (9,72 m²).
  static const vorgabe = TGrundriss._(
    Millimeter(1800),
    Millimeter(1350),
    Millimeter(1800),
    Millimeter(1350),
    Millimeter(1350),
    Millimeter(1800),
  );

  final Millimeter bc;
  final Millimeter cd;
  final Millimeter de;
  final Millimeter ef;
  final Millimeter gh;
  final Millimeter ha;

  @override
  Terrassenform get form => Terrassenform.tForm;

  @override
  List<Millimeter> get masse => [bc, cd, de, ef, gh, ha];

  @override
  List<Punkt> get ecken {
    final links = gh.mm.toDouble(), rechts = links + ef.mm;
    final breite = rechts + cd.mm;
    final balkenRechts = bc.mm.toDouble(), unten = balkenRechts + de.mm;
    final balkenLinks = ha.mm.toDouble();
    return [
      Punkt.ursprung,
      Punkt(breite, 0),
      Punkt(breite, balkenRechts),
      Punkt(rechts, balkenRechts),
      Punkt(rechts, unten),
      Punkt(links, unten),
      Punkt(links, balkenLinks),
      Punkt(0, balkenLinks),
    ];
  }
}

/// U-Form (M4-05): Öffnung oben zwischen den Schenkeln. Eingegeben werden
/// A—B, B—C, C—D, E—F, F—G und H—A (Fachkonzept 1.1); daraus
/// G—H = A—B + C—D + E—F und D—E = B—C + F—G − H—A, damit die Unterkante
/// gerade bleibt.
final class UGrundriss extends Grundriss {
  UGrundriss(this.ab, this.bc, this.cd, this.ef, this.fg, this.ha) {
    _pruefeSeiten();
  }

  const UGrundriss._(this.ab, this.bc, this.cd, this.ef, this.fg, this.ha);

  /// Vorgabemaße des alten Planers: Schenkel 135 cm breit, Öffnung
  /// 135 × 90 cm, außen 405 × 270 cm (9,72 m²).
  static const vorgabe = UGrundriss._(
    Millimeter(1350),
    Millimeter(900),
    Millimeter(1350),
    Millimeter(1350),
    Millimeter(2700),
    Millimeter(2700),
  );

  final Millimeter ab;
  final Millimeter bc;
  final Millimeter cd;
  final Millimeter ef;
  final Millimeter fg;
  final Millimeter ha;

  @override
  Terrassenform get form => Terrassenform.uForm;

  @override
  List<Millimeter> get masse => [ab, bc, cd, ef, fg, ha];

  @override
  List<Punkt> get ecken {
    final links = ab.mm.toDouble(), rechts = links + cd.mm;
    final breite = rechts + ef.mm;
    final unten = ha.mm.toDouble(), boden = bc.mm.toDouble();
    final rechtsOben = unten - fg.mm;
    return [
      Punkt.ursprung,
      Punkt(links, 0),
      Punkt(links, boden),
      Punkt(rechts, boden),
      Punkt(rechts, rechtsOben),
      Punkt(breite, rechtsOben),
      Punkt(breite, unten),
      Punkt(0, unten),
    ];
  }
}

/// Freiform (M4-08): Punkte in mm in der Reihenfolge des Zeichnens. Offen ist
/// sie ein Linienzug ohne Fläche; schließen lässt sie sich erst ab drei
/// Punkten und nur, wenn sich keine Kanten kreuzen (Fachkonzept 1.1).
final class FreiformGrundriss extends Grundriss {
  FreiformGrundriss(List<Punkt> punkte, {this.geschlossen = false})
    : punkte = List.unmodifiable(punkte) {
    if (geschlossen && punkte.length < 3) {
      throw ArgumentError.value(
        punkte.length,
        'punkte',
        'mindestens 3 Punkte zum Schließen',
      );
    }
    // offen zählen nur die gezeichneten Kanten, geschlossen auch die letzte
    Grundriss._pruefeKanten(
      punkte,
      geschlossen ? punkte.length : punkte.length - 1,
      kleinsteKante,
    );
    if (geschlossen && !Kontur(punkte).istEinfach) {
      throw ArgumentError.value(
        punkte.length,
        'punkte',
        'Kanten dürfen sich nicht kreuzen',
      );
    }
  }

  const FreiformGrundriss._leer() : punkte = const [], geschlossen = false;

  factory FreiformGrundriss._aus(List<Millimeter> masse) {
    if (masse.length.isEven) {
      throw ArgumentError.value(
        masse.length,
        'masse',
        'braucht Kennung und Punktpaare',
      );
    }
    // Zählschleife mit i++ (siehe Berechnung): kein Endlos-Mutant
    return FreiformGrundriss([
      for (var i = 0; i < masse.length ~/ 2; i++)
        Punkt(masse[2 * i + 1].mm.toDouble(), masse[2 * i + 2].mm.toDouble()),
    ], geschlossen: masse[0].mm == 1);
  }

  /// Leeres Raster nach der Formwahl.
  static const leer = FreiformGrundriss._leer();

  /// Kürzeste gezeichnete Kante (z. B. eine abgeschrägte Ecke).
  static const kleinsteKante = Millimeter(100);

  final List<Punkt> punkte;
  final bool geschlossen;

  @override
  Terrassenform get form => Terrassenform.freiform;

  /// Transportformat: Kennung (1 = geschlossen), dann x, y je Punkt in mm.
  @override
  List<Millimeter> get masse => [
    Millimeter(geschlossen ? 1 : 0),
    for (final p in punkte) ...[
      Millimeter(p.x.round()),
      Millimeter(p.y.round()),
    ],
  ];

  @override
  List<Punkt> get ecken => punkte;

  /// Nur für eine geschlossene Form.
  @override
  Kontur get kontur {
    if (!geschlossen) throw StateError('Freiform ist noch offen');
    return super.kontur;
  }

  /// Mit einem weiteren Punkt am Ende.
  FreiformGrundriss mitPunkt(Punkt p) => FreiformGrundriss([...punkte, p]);

  /// Mit [p] statt des letzten Punkts (Zeichnungshilfe).
  FreiformGrundriss mitLetztemPunkt(Punkt p) =>
      FreiformGrundriss([...punkte.take(punkte.length - 1), p]);

  /// Ohne den letzten Punkt, offen.
  FreiformGrundriss ohneLetztenPunkt() =>
      FreiformGrundriss(punkte.take(punkte.length - 1).toList());

  /// Die geschlossene Form.
  FreiformGrundriss geschlossene() =>
      FreiformGrundriss(punkte, geschlossen: true);
}
