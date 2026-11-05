import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'ansichtsoptionen.dart';
import 'steuerung.dart';

/// Was die Draufsicht zeigt (M3-04): Umriss mit Eckpunkten, Bauteile und
/// Abläufe in Millimetern – fertig vom Server berechnet (ab M4/M5), die App
/// zeichnet nur.
final class Zeichnung {
  Zeichnung({
    List<Offset> umriss = const [],
    List<Offset>? ecken,
    this.geschlossen = true,
    List<List<Offset>> ausschnitte = const [],
    List<({String name, Color farbe})> ausschnittDarstellung = const [],
    List<Bauteil> bauteile = const [],
    List<Offset> ablaeufe = const [],
    List<List<Offset>> dielen = const [],
    List<int> nummern = const [],
    List<Color> dielenfarben = const [],
    List<(Offset, Offset)> querstreben = const [],
    List<(Offset, Offset, Color)> ukHoelzer = const [],
    this.ukBreite = 0,
    this.ausgangspunkt,
  }) : umriss = List.unmodifiable(umriss),
       ukHoelzer = List.unmodifiable(ukHoelzer),
       querstreben = List.unmodifiable(querstreben),
       dielenfarben = List.unmodifiable(dielenfarben),
       dielen = List.unmodifiable(dielen),
       nummern = List.unmodifiable(nummern),
       ecken = List.unmodifiable(ecken ?? umriss),
       ausschnitte = List.unmodifiable(ausschnitte),
       ausschnittDarstellung = List.unmodifiable(ausschnittDarstellung),
       bauteile = List.unmodifiable(bauteile),
       ablaeufe = List.unmodifiable(ablaeufe);

  static final leer = Zeichnung();

  /// Eckpunkte in mm (x längs, y quer), Reihenfolge entlang des Umrisses.
  final List<Offset> umriss;

  /// Ob der Umriss geschlossen ist; eine offene Freiform (M4-08) wird als
  /// Linienzug mit markierten Punkten gezeichnet.
  final bool geschlossen;

  /// Benannte Eckpunkte A, B … für Beschriftungen (ohne Angabe der Umriss,
  /// beim Kreis keine, M4-07).
  final List<Offset> ecken;

  /// Ausschnitte (M4-06) in mm, je Ausschnitt seine Eckpunkte.
  final List<List<Offset>> ausschnitte;

  /// Bezeichnung und Füllung je Ausschnitt (M4-12, nur Darstellung); fehlt
  /// ein Eintrag, ist er weiß und ohne Namen.
  final List<({String name, Color farbe})> ausschnittDarstellung;
  final List<Bauteil> bauteile;

  /// Lage der Abläufe (Entwässerung) in mm.
  final List<Offset> ablaeufe;

  /// Umrisse der Dielenstücke in mm (M5-05), vom Server verlegt.
  final List<List<Offset>> dielen;

  /// Nummer je Dielenstück wie in „Dielen nach Nummer“ (M5-08), parallel
  /// zu [dielen]; fehlt eine, bleibt das Stück ohne Nummer.
  final List<int> nummern;

  /// Farbe je Dielenstück wie in der Stückliste (M9-04), parallel zu
  /// [dielen]; fehlt eine, bekommt das Stück die normale Fuge.
  final List<Color> dielenfarben;

  /// Querstreben in mm (M6-05/M6-06), je Strebe Anfang und Ende.
  final List<(Offset, Offset)> querstreben;

  /// UK-Hölzer in mm (M6-10): Achse von, bis und Farbe wie in der
  /// Stückliste (rot ganze Lieferlänge, blau zugeschnitten).
  final List<(Offset, Offset, Color)> ukHoelzer;

  /// Breite der UK-Hölzer in der Draufsicht in mm.
  final double ukBreite;

  /// Ausgangspunkt der Verlegung in mm (M5-07): Ecke plus Verschiebung, dort
  /// liegt der Griff der ersten ganzen Diele; `null` ohne Dielen.
  final Offset? ausgangspunkt;
}

/// Ein Text der Zeichnung: [ort] ist der Ankerpunkt auf dem Bildschirm,
/// [richtung] zeigt, wohin der Text vom Anker aus liegt (Einheitsvektor;
/// null = mittig) – so berührt er die Linie nie, egal wie lang er ist.
typedef Zeichentext = ({String text, Offset ort, Offset richtung});

/// Bildschirm-Pixel je Millimeter bei 100 % Zoom (1 m = 100 px).
const pixelJeMm = 0.1;

/// Zeichnet die Draufsicht nach den [optionen] (M3-04); folgt Zoom und
/// Verschiebung der [ansicht].
class ZeichnungsMaler extends CustomPainter {
  ZeichnungsMaler({
    required this.zeichnung,
    required this.optionen,
    required this.ansicht,
    required this.sprache,
    this.strich = PlanerFarben.text,
  }) : super(repaint: Listenable.merge([optionen, ansicht]));

  final Zeichnung zeichnung;
  final AnsichtsOptionen optionen;
  final AnsichtSteuerung ansicht;

  /// Beschriftungen und Zahlen in der Sprache der Oberfläche (M3-07).
  final PlanerTexte sprache;

  /// Farbe von Umriss, Kanten und Beschriftung (hell/dunkel, M3-09).
  final Color strich;

  /// Abstand der Maßlinien vom Umriss in Pixeln.
  static const masslinienAbstand = 44.0;

  static const belagFarbe = Color(0xFFD9B98A);
  static const ukFarbe = Color(0xFF7A5A33);

  /// Füllung leerer Ausschnitte („leer/weiß“ im alten Planer).
  static const leerFarbe = Color(0xFFFFFFFF);

  Offset bildschirm(Offset mm) =>
      ansicht.verschiebung + mm * (pixelJeMm * ansicht.zoom);

  Rect _draufsicht(Quader q) {
    final faktor = pixelJeMm * ansicht.zoom;
    return bildschirm(Offset(q.x.mm.toDouble(), q.z.mm.toDouble())) &
        Size(q.laenge.mm * faktor, q.breite.mm * faktor);
  }

  /// Bauteile der sichtbaren Ebenen; Unterkonstruktion unter dem Belag.
  List<(Rect, Color)> rechtecke() => [
    for (final (art, ebene, farbe) in const [
      (Bauteilart.unterkonstruktion, Ebene.unterkonstruktion, ukFarbe),
      (Bauteilart.diele, Ebene.belag, belagFarbe),
    ])
      if (optionen.zeigt(ebene))
        for (final teil in zeichnung.bauteile)
          if (teil.art == art) (_draufsicht(teil.quader), farbe),
  ];

  /// Dielenstücke auf dem Bildschirm, wenn die Ebene Belag sichtbar ist.
  List<Path> dielenpfade() => [
    if (optionen.zeigt(Ebene.belag))
      for (final d in zeichnung.dielen)
        Path()..addPolygon([for (final p in d) bildschirm(p)], true),
  ];

  /// Querstreben auf dem Bildschirm, wenn die Ebene UK sichtbar ist; sie
  /// liegen über dem Belag, damit man sie bei beiden Ebenen sieht.
  List<(Offset, Offset)> strebenlinien() => [
    if (optionen.zeigt(Ebene.unterkonstruktion))
      for (final (von, bis) in zeichnung.querstreben)
        (bildschirm(von), bildschirm(bis)),
  ];

  /// UK-Hölzer auf dem Bildschirm mit Farbe und Strichbreite (M6-10), wenn
  /// die Ebene UK sichtbar ist; halb durchsichtig über dem Belag, damit
  /// man sie bei beiden Ebenen sieht. Mindestens 1 Pixel breit.
  List<(Offset, Offset, Color, double)> holzlinien() => [
    if (optionen.zeigt(Ebene.unterkonstruktion))
      for (final (von, bis, farbe) in zeichnung.ukHoelzer)
        (
          bildschirm(von),
          bildschirm(bis),
          farbe.withValues(alpha: holzDeckkraft),
          math.max(1, zeichnung.ukBreite * pixelJeMm * ansicht.zoom),
        ),
  ];

  /// Deckkraft der UK-Hölzer über dem Belag.
  static const holzDeckkraft = 0.6;

  /// Farbe der Querstreben: grün wie Querstücke in der Stückliste (M9-04).
  static final strebenFarbe = Color(Stueckfarbe.gruen.argb);

  /// Rand des Dielenstücks [index] in der Farbe der Stückliste (M9-04);
  /// `null` = normale Fuge.
  Color? dielenrand(int index) => zeichnung.dielenfarben.elementAtOrNull(index);

  /// Schriftgröße der Dielennummern in Pixeln.
  static const nummerGroesse = 10.0;

  /// Dielennummern (M5-08) auf der Ebene Belag: mittig im Stück, längs
  /// gedreht, nur wo die Nummer auf dem Bildschirm ins Stück passt – Breite
  /// (Fläche ÷ längste Kante) mindestens eine Zeile, Länge mindestens die
  /// Ziffern.
  List<({String text, Offset ort, double winkel})> dielennummern() => [
    if (optionen.zeigt(Ebene.belag))
      for (final (i, d) in zeichnung.dielen.indexed)
        if (i < zeichnung.nummern.length)
          ?_nummernlage([
            for (final p in d) bildschirm(p),
          ], zeichnung.nummern[i]),
  ];

  static ({String text, Offset ort, double winkel})? _nummernlage(
    List<Offset> schirm,
    int nummer,
  ) {
    var kante = Offset.zero;
    var flaeche = 0.0;
    var summe = Offset.zero;
    for (var i = 0; i < schirm.length; i++) {
      final p = schirm[i];
      final q = schirm[_nachher(schirm, i)];
      if ((q - p).distance > kante.distance) kante = q - p;
      flaeche += p.dx * q.dy - q.dx * p.dy;
      summe += p;
    }
    final text = '$nummer';
    final laenge = kante.distance;
    if (laenge == 0 ||
        flaeche.abs() / 2 / laenge < nummerGroesse + 2 ||
        laenge < text.length * nummerGroesse * 0.6 + 4) {
      return null;
    }
    // Text nie auf dem Kopf: Winkel zwischen −90° und 90°
    var winkel = math.atan2(kante.dy, kante.dx);
    if (winkel > math.pi / 2) winkel -= math.pi;
    if (winkel <= -math.pi / 2) winkel += math.pi;
    return (text: text, ort: summe / schirm.length.toDouble(), winkel: winkel);
  }

  /// Alle Texte der eingeschalteten Beschriftungen und Maße: Seitenlängen
  /// außen neben der Kante, Winkel innen in der Ecke, Punktnamen außen.
  List<Zeichentext> texte() {
    if (!zeichnung.geschlossen) return _offeneTexte();
    final punkte = zeichnung.ecken;
    final n = punkte.length;
    final schirm = [for (final p in punkte) bildschirm(p)];
    return [
      if (optionen.beschriftet(Beschriftung.punkte))
        for (var i = 0; i < n; i++)
          (
            text: punktname(i),
            ort: schirm[i] - innen(punkte, i) * beschriftungsAbstand,
            richtung: -innen(punkte, i),
          ),
      if (optionen.beschriftet(Beschriftung.seitenlaengen))
        for (var i = 0; i < n; i++)
          (
            text: zentimeter(
              (punkte[_nachher(punkte, i)] - punkte[i]).distance,
            ),
            ort:
                Offset.lerp(schirm[i], schirm[_nachher(punkte, i)], 0.5)! +
                aussen(punkte, i) * beschriftungsAbstand,
            richtung: aussen(punkte, i),
          ),
      if (optionen.beschriftet(Beschriftung.winkel))
        for (var i = 0; i < n; i++)
          (
            text: '${innenwinkel(punkte, i).round()}°',
            ort: schirm[i] + innen(punkte, i) * beschriftungsAbstand,
            richtung: innen(punkte, i),
          ),
      if (optionen.beschriftet(Beschriftung.ablaeufe))
        for (final a in zeichnung.ablaeufe)
          (
            text: sprache.ablauf,
            ort: bildschirm(a) + const Offset(0, -beschriftungsAbstand),
            richtung: const Offset(0, -1),
          ),
      if (optionen.zeigt(Ebene.masse) && zeichnung.umriss.isNotEmpty)
        ..._masse([for (final p in zeichnung.umriss) bildschirm(p)]),
    ];
  }

  /// Radius der Punktmarken beim Zeichnen einer Freiform in Pixeln.
  static const punktRadius = 4.0;

  /// Offene Freiform (M4-08): Punktnamen oben links am Punkt und die Längen
  /// der gezeichneten Kanten neben der Kante – ohne Innen und Außen.
  List<Zeichentext> _offeneTexte() {
    final punkte = zeichnung.ecken;
    final schirm = [for (final p in punkte) bildschirm(p)];
    return [
      if (optionen.beschriftet(Beschriftung.punkte))
        for (var i = 0; i < punkte.length; i++)
          (
            text: punktname(i),
            ort: schirm[i] + oben * beschriftungsAbstand,
            richtung: oben,
          ),
      if (optionen.beschriftet(Beschriftung.seitenlaengen))
        for (var i = 1; i < punkte.length; i++)
          (
            text: zentimeter((punkte[i] - punkte[i - 1]).distance),
            ort:
                Offset.lerp(schirm[i - 1], schirm[i], 0.5)! +
                oben * beschriftungsAbstand,
            richtung: oben,
          ),
    ];
  }

  /// Richtung „nach oben“ für Beschriftungen der offenen Freiform.
  static const oben = Offset(0, -1);

  /// Mitte des umschließenden Rechtecks.
  static Offset mitte(List<Offset> punkte) => _umschliessend(punkte).center;

  /// Abstand der Beschriftungen von Kante bzw. Ecke in Pixeln.
  static const beschriftungsAbstand = 6.0;

  /// Einheitsnormale der Kante [i] → [i]+1, die aus der Fläche zeigt.
  static Offset aussen(List<Offset> punkte, int i) {
    final d = punkte[_nachher(punkte, i)] - punkte[i];
    final normale = Offset(d.dy, -d.dx) / d.distance;
    return _rechtsherum(punkte) ? normale : -normale;
  }

  /// Einheitsrichtung vom Eckpunkt [i] in die Fläche (Winkelhalbierende).
  static Offset innen(List<Offset> punkte, int i) {
    final p = punkte[i];
    final a = punkte[_vorher(punkte, i)] - p;
    final b = punkte[_nachher(punkte, i)] - p;
    final halb = a / a.distance + b / b.distance;
    // Gestreckte Ecke (180°): senkrecht zur Kante nach innen.
    if (halb.distance < 1e-9) return -aussen(punkte, i);
    final richtung = halb / halb.distance;
    return innenwinkel(punkte, i) > 180 ? -richtung : richtung;
  }

  /// Gesamtmaße (Breite unten, Tiefe rechts) aus dem umschließenden Rechteck.
  List<Zeichentext> _masse(List<Offset> schirm) {
    final mm = _umschliessend(zeichnung.umriss);
    final px = _umschliessend(schirm);
    return [
      (
        text: zentimeter(mm.width),
        ort: px.bottomCenter + const Offset(0, masslinienAbstand),
        richtung: const Offset(0, 1),
      ),
      (
        text: zentimeter(mm.height),
        ort: px.centerRight + const Offset(masslinienAbstand, 0),
        richtung: const Offset(1, 0),
      ),
    ];
  }

  static Rect _umschliessend(List<Offset> punkte) => Rect.fromLTRB(
    punkte.map((p) => p.dx).reduce(math.min),
    punkte.map((p) => p.dy).reduce(math.min),
    punkte.map((p) => p.dx).reduce(math.max),
    punkte.map((p) => p.dy).reduce(math.max),
  );

  /// Eckpunktnamen wie im alten Planer: A, B, C …
  static String punktname(int i) => String.fromCharCode(0x41 + i.remainder(26));

  /// Länge in mm als Zentimeter, auf den Millimeter gerundet
  /// („480 cm“, „12,5 cm“ – auf Englisch „12.5 cm“).
  String zentimeter(double mm) =>
      '${zahlText(sprache, mm.round() / 10, '0.#')} cm';

  /// Innenwinkel am Eckpunkt [i] in Grad – auch für einspringende Ecken
  /// (L-Form: 270°), unabhängig von der Umlaufrichtung.
  static double innenwinkel(List<Offset> punkte, int i) {
    final p = punkte[i];
    final a = punkte[_vorher(punkte, i)] - p;
    final b = punkte[_nachher(punkte, i)] - p;
    final winkel = math.atan2(
      a.dx * b.dy - a.dy * b.dx,
      a.dx * b.dx + a.dy * b.dy,
    );
    final innen = (_rechtsherum(punkte) ? -winkel : winkel) * 180 / math.pi;
    return innen < 0 ? innen + 360 : innen;
  }

  static int _vorher(List<Offset> punkte, int i) =>
      i == 0 ? punkte.length - 1 : i - 1;

  static int _nachher(List<Offset> punkte, int i) =>
      i == punkte.length - 1 ? 0 : i + 1;

  /// Umlaufrichtung: im Uhrzeigersinn auf dem Bildschirm (y nach unten),
  /// bestimmt über das Vorzeichen der Gaußschen Trapezformel.
  static bool _rechtsherum(List<Offset> punkte) {
    var summe = 0.0;
    for (var i = 0; i < punkte.length; i++) {
      final p = punkte[i];
      final q = punkte[_nachher(punkte, i)];
      summe += p.dx * q.dy - q.dx * p.dy;
    }
    return summe > 0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final (rechteck, farbe) in rechtecke()) {
      canvas
        ..drawRect(rechteck, Paint()..color = farbe)
        ..drawRect(
          rechteck,
          Paint()
            ..color = strich.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke,
        );
    }
    // Ausschnitte unter dem Belag: leere bleiben frei, Teilflächen mit
    // anderem Belag tragen ihre eigenen Dielen (M5-08)
    final ausschnitte = [
      for (final (i, a) in zeichnung.ausschnitte.indexed)
        (
          Path()..addPolygon([for (final p in a) bildschirm(p)], true),
          i < zeichnung.ausschnittDarstellung.length
              ? zeichnung.ausschnittDarstellung[i]
              : (name: '', farbe: leerFarbe),
        ),
    ];
    for (final (pfad, darstellung) in ausschnitte) {
      canvas.drawPath(pfad, Paint()..color = darstellung.farbe);
    }
    final fuge = Paint()
      ..color = strich.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke;
    for (final (i, pfad) in dielenpfade().indexed) {
      canvas
        ..drawPath(pfad, Paint()..color = belagFarbe)
        ..drawPath(pfad, switch (dielenrand(i)) {
          final farbe? =>
            Paint()
              ..color = farbe
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          null => fuge,
        });
    }
    for (final (:text, :ort, :winkel) in dielennummern()) {
      final maler = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: nummerGroesse, color: strich),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas
        ..save()
        ..translate(ort.dx, ort.dy)
        ..rotate(winkel);
      maler.paint(canvas, textLage(Offset.zero, Offset.zero, maler.size));
      canvas.restore();
    }
    for (final (von, bis, farbe, breite) in holzlinien()) {
      canvas.drawLine(
        von,
        bis,
        Paint()
          ..color = farbe
          ..strokeWidth = breite,
      );
    }
    final strebe = Paint()
      ..color = strebenFarbe
      ..strokeWidth = 3;
    for (final (von, bis) in strebenlinien()) {
      canvas.drawLine(von, bis, strebe);
    }
    final umriss = [for (final p in zeichnung.umriss) bildschirm(p)];
    final linie = Paint()
      ..color = strich
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    if (umriss.isNotEmpty) {
      canvas.drawPath(Path()..addPolygon(umriss, zeichnung.geschlossen), linie);
    }
    if (!zeichnung.geschlossen) {
      for (final p in umriss) {
        canvas.drawCircle(p, punktRadius, Paint()..color = strich);
      }
    }
    // Rand und Name der Ausschnitte über dem Belag (Fachkonzept 1.4)
    for (final (pfad, darstellung) in ausschnitte) {
      canvas.drawPath(pfad, linie);
      final maler = TextPainter(
        text: TextSpan(
          text: darstellung.name,
          style: TextStyle(fontSize: 12, color: strich),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      maler.paint(
        canvas,
        textLage(pfad.getBounds().center, Offset.zero, maler.size),
      );
    }
    if (optionen.beschriftet(Beschriftung.ablaeufe)) {
      for (final a in zeichnung.ablaeufe) {
        canvas.drawCircle(bildschirm(a), 5, Paint()..color = Colors.blue);
      }
    }
    for (final (:text, :ort, :richtung) in texte()) {
      final maler = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: 12, color: strich),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      maler.paint(canvas, textLage(ort, richtung, maler.size));
    }
  }

  /// Obere linke Ecke eines Texts der [groesse], der vom Anker [ort] aus in
  /// [richtung] liegt.
  static Offset textLage(Offset ort, Offset richtung, Size groesse) {
    final halb = Offset(groesse.width / 2, groesse.height / 2);
    return ort + Offset(richtung.dx * halb.dx, richtung.dy * halb.dy) - halb;
  }

  @override
  bool shouldRepaint(ZeichnungsMaler alt) =>
      alt.zeichnung != zeichnung ||
      alt.optionen != optionen ||
      alt.ansicht != ansicht ||
      alt.sprache != sprache ||
      alt.strich != strich;
}
