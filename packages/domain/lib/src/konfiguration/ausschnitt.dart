import 'dart:math' as math;

import '../artikel/einheiten.dart';
import '../geometrie/kontur.dart';
import '../geometrie/punkt.dart';
import 'grundriss.dart';

/// Form eines Ausschnitts (Fachkonzept 1.4); die Nummer ist der Wert im
/// Transportformat und bleibt fest.
enum Ausschnittform {
  rechteck(0),

  /// Spitze oben in der Mitte, Grundseite unten über die ganze Länge.
  dreieck(1),

  /// Regelmäßig in Länge × Breite: Spitzen links und rechts, oben und unten
  /// gerade.
  sechseck(2),

  /// Durchmesser = Länge; die Breite folgt der Länge.
  kreis(3);

  const Ausschnittform(this.nummer);

  final int nummer;
}

/// Funktion eines Ausschnitts (Fachkonzept 1.4): leer (kein Belag, Material
/// entfällt) oder eine Teilfläche mit anderem Terrassenbelag (Belag folgt mit
/// M5).
enum Ausschnittfunktion {
  leer(0),
  andererBelag(1);

  const Ausschnittfunktion(this.nummer);

  final int nummer;
}

/// Was eine leere Fläche zeigt – nur Darstellung, ohne Wirkung auf die
/// Berechnung (Fachkonzept 1.4).
enum Ausschnittinhalt {
  leer(0),
  kiesHell(1),
  steinDunkel(2),
  pool(3),
  rasen(4),
  erde(5);

  const Ausschnittinhalt(this.nummer);

  final int nummer;
}

/// Ausschnitt oder Teilfläche im Grundriss (Fachkonzept 1.4, M4-06/M4-12):
/// Lage über die Koordinaten der Ecke oben links ihres umschließenden
/// Rechtecks (Punkt A der Terrasse = 0|0, negative Werte möglich).
final class Ausschnitt {
  Ausschnitt({
    required this.bezeichnung,
    required this.x,
    required this.y,
    required this.laenge,
    required Millimeter breite,
    this.form = Ausschnittform.rechteck,
    this.funktion = Ausschnittfunktion.leer,
    this.inhalt = Ausschnittinhalt.leer,
  }) : breite = form == Ausschnittform.kreis ? laenge : breite {
    if (bezeichnung.isEmpty || bezeichnung.length > 10) {
      throw ArgumentError.value(
        bezeichnung,
        'bezeichnung',
        'braucht 1 bis 10 Zeichen',
      );
    }
    for (final (name, wert) in [('laenge', laenge), ('breite', this.breite)]) {
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

  const Ausschnitt._(this.bezeichnung, this.x, this.y, this.laenge, this.breite)
    : form = Ausschnittform.rechteck,
      funktion = Ausschnittfunktion.leer,
      inhalt = Ausschnittinhalt.leer;

  /// Ausschnitt der O-Form im alten Planer: 240 × 180 cm mittig in
  /// 540 × 360 cm (Fachkonzept 1.1).
  static const oForm = Ausschnitt._(
    'A1',
    Millimeter(1500),
    Millimeter(900),
    Millimeter(2400),
    Millimeter(1800),
  );

  /// Vorgabemaße einer weiteren Fläche: 180 × 120 cm (Fachkonzept 1.4).
  static const vorgabeLaenge = Millimeter(1800);
  static const vorgabeBreite = Millimeter(1200);

  /// Kleinste Seite eines Ausschnitts (z. B. für einen Pfosten).
  static const kleinsteSeite = Millimeter(100);

  /// Bezeichnung wie im alten Planer („A1“, höchstens 10 Zeichen).
  final String bezeichnung;
  final Millimeter x;
  final Millimeter y;
  final Millimeter laenge;
  final Millimeter breite;
  final Ausschnittform form;
  final Ausschnittfunktion funktion;
  final Ausschnittinhalt inhalt;

  /// Maße in der Reihenfolge der Eingabefelder: X, Y, Länge, Breite.
  List<Millimeter> get masse => [x, y, laenge, breite];

  Kontur get kontur {
    final l = laenge.mm.toDouble(), b = breite.mm.toDouble();
    final o = Punkt(x.mm.toDouble(), y.mm.toDouble());
    return switch (form) {
      Ausschnittform.rechteck => Kontur.rechteck(l, b, o),
      Ausschnittform.dreieck => Kontur([
        o + Punkt(l / 2, 0),
        o + Punkt(l, b),
        o + Punkt(0, b),
      ]),
      Ausschnittform.sechseck => Kontur([
        for (var i = 0; i < 6; i++)
          o +
              Punkt(l / 2, b / 2) +
              Punkt(
                math.cos(i * math.pi / 3) * l / 2,
                math.sin(i * math.pi / 3) * b / 2,
              ),
      ]),
      Ausschnittform.kreis => Kontur.kreis(o + Punkt(l / 2, l / 2), l / 2),
    };
  }

  /// Kopie mit neuem Wert für das Maß [index] aus [masse].
  Ausschnitt mitMass(int index, Millimeter wert) {
    final m = [...masse]..[index] = wert;
    return _kopie(x: m[0], y: m[1], laenge: m[2], breite: m[3]);
  }

  /// Verschoben um [dx], [dy] (Ziehen in der Zeichnung).
  Ausschnitt verschoben(Millimeter dx, Millimeter dy) =>
      _kopie(x: x + dx, y: y + dy);

  Ausschnitt mitForm(Ausschnittform form) => _kopie(form: form);

  Ausschnitt mitFunktion(Ausschnittfunktion funktion) =>
      _kopie(funktion: funktion);

  Ausschnitt mitInhalt(Ausschnittinhalt inhalt) => _kopie(inhalt: inhalt);

  Ausschnitt mitBezeichnung(String bezeichnung) =>
      _kopie(bezeichnung: bezeichnung);

  Ausschnitt _kopie({
    String? bezeichnung,
    Millimeter? x,
    Millimeter? y,
    Millimeter? laenge,
    Millimeter? breite,
    Ausschnittform? form,
    Ausschnittfunktion? funktion,
    Ausschnittinhalt? inhalt,
  }) => Ausschnitt(
    bezeichnung: bezeichnung ?? this.bezeichnung,
    x: x ?? this.x,
    y: y ?? this.y,
    laenge: laenge ?? this.laenge,
    breite: breite ?? this.breite,
    form: form ?? this.form,
    funktion: funktion ?? this.funktion,
    inhalt: inhalt ?? this.inhalt,
  );

  @override
  bool operator ==(Object other) =>
      other is Ausschnitt &&
      other.bezeichnung == bezeichnung &&
      other.x == x &&
      other.y == y &&
      other.laenge == laenge &&
      other.breite == breite &&
      other.form == form &&
      other.funktion == funktion &&
      other.inhalt == inhalt;

  @override
  int get hashCode =>
      Object.hashAll([bezeichnung, ...masse, form, funktion, inhalt]);
}
