import 'dart:math' as math;

import '../artikel/artikel.dart';
import '../artikel/einheiten.dart';
import '../geometrie/punkt.dart';
import '../konfiguration/belagverlegung.dart';
import '../konfiguration/berechnung.dart';
import '../konfiguration/konfigurationsnummer.dart';
import '../konfiguration/planung.dart';
import '../konfiguration/planungsstand.dart';
import '../regeln/auflager.dart';
import 'materialliste.dart';
import 'stueckliste.dart';
import 'unterlagentexte.dart';

/// Ein Baustein eines Kapitels der Planungsunterlagen (M9-06) – was darin
/// steht, legt die Domäne fest, wie es aussieht, der Satz auf dem Server.
sealed class Baustein {
  const Baustein();
}

/// Ein Absatz Fließtext.
final class Absatz extends Baustein {
  const Absatz(this.text, {this.fett = false});

  final String text;
  final bool fett;
}

/// Bezeichnung und Wert untereinander („Terrassenfläche: 12,000 m²“).
final class Wertepaare extends Baustein {
  Wertepaare(List<(String, String)> zeilen)
    : zeilen = List.unmodifiable(zeilen);

  final List<(String, String)> zeilen;
}

/// Eine Tabelle mit Kopfzeile; [farben] (leer oder je Zeile) zeigt die
/// Farbe im Plan (M9-04), [rechts] die rechtsbündigen Spalten (Zahlen).
final class Tabelle extends Baustein {
  Tabelle(
    List<String> kopf,
    List<List<String>> zeilen, {
    List<Stueckfarbe> farben = const [],
    Set<int> rechts = const {},
  }) : kopf = List.unmodifiable(kopf),
       zeilen = List.unmodifiable([
         for (final z in zeilen) List<String>.unmodifiable(z),
       ]),
       farben = List.unmodifiable(farben),
       rechts = Set.unmodifiable(rechts);

  final List<String> kopf;
  final List<List<String>> zeilen;
  final List<Stueckfarbe> farben;
  final Set<int> rechts;
}

/// Ein Linienzug der Zeichnung in Planungskoordinaten (mm); [staerke] in
/// Punkt auf dem Papier, [gefuellt] füllt ihn in der Farbe [argb].
final class Planlinie {
  Planlinie(
    List<Punkt> punkte, {
    required this.argb,
    this.geschlossen = true,
    this.gefuellt = false,
    this.staerke = 0.5,
  }) : punkte = List.unmodifiable(punkte);

  final List<Punkt> punkte;
  final int argb;
  final bool geschlossen;
  final bool gefuellt;
  final double staerke;
}

/// Eine Beschriftung der Zeichnung, mittig um [ort].
typedef Planbeschriftung = ({Punkt ort, String text});

/// Eine Zeichnung (Grundriss, UK-Plan, Verlegeplan) – maßstäblich auf die
/// Seitenbreite gesetzt.
final class Plan extends Baustein {
  Plan(List<Planlinie> linien, [List<Planbeschriftung> texte = const []])
    : linien = List.unmodifiable(linien),
      texte = List.unmodifiable(texte);

  final List<Planlinie> linien;
  final List<Planbeschriftung> texte;
}

/// Ein Kapitel; [neueSeite] beginnt es oben auf einer neuen Seite.
final class Kapitel {
  Kapitel(this.titel, List<Baustein> inhalt, {this.neueSeite = true})
    : inhalt = List.unmodifiable(inhalt);

  final String titel;
  final List<Baustein> inhalt;
  final bool neueSeite;
}

/// Angaben des Kunden für das Deckblatt (aus der Anfrage, M9-07) – sie
/// werden nur gedruckt, nie gespeichert.
final class Kundendaten {
  Kundendaten({
    this.name = '',
    this.adresse = '',
    this.ort = '',
    this.telefon = '',
    this.email = '',
  });

  /// Aus einer WAMP-Nutzlast; nur Texte bis [hoechstlaenge] Zeichen.
  factory Kundendaten.aus(Map<Object?, Object?> werte) {
    String feld(String name) => switch (werte[name]) {
      null => '',
      final String s when s.length <= hoechstlaenge => s.trim(),
      final wert => throw ArgumentError.value(wert, name, 'kein kurzer Text'),
    };
    return Kundendaten(
      name: feld('name'),
      adresse: feld('adresse'),
      ort: feld('ort'),
      telefon: feld('telefon'),
      email: feld('email'),
    );
  }

  static const hoechstlaenge = 200;

  final String name;
  final String adresse;
  final String ort;
  final String telefon;
  final String email;

  List<String> get felder => [name, adresse, ort, telefon, email];
}

/// Was der Server je Fläche rechnet: die [berechnung] mit dieser Fläche als
/// bearbeiteter (Zeichnung, Höhen, UK, Stückliste) und die Verlegung des
/// Belags für „Dielen nach Nummer“ und den Zuschnitt.
final class Flaechenunterlage {
  Flaechenunterlage(this.berechnung, {this.belag, this.uk, this.verlegung});

  final Berechnung berechnung;
  final Artikel? belag;
  final Artikel? uk;
  final Belagverlegung? verlegung;
}

/// Die fertigen Planungsunterlagen: Kopfzeile jeder Seite, Seitenangabe und
/// Kapitel.
final class Planungsunterlagen {
  Planungsunterlagen({
    required this.texte,
    required this.kopfzeile,
    required List<Kapitel> kapitel,
  }) : kapitel = List.unmodifiable(kapitel);

  final Unterlagentexte texte;
  final String kopfzeile;
  final List<Kapitel> kapitel;
}

const _schwarz = 0xFF000000;
const _grau = 0xFF9E9E9E;

/// Stellt die Planungsunterlagen zusammen (M9-06) – Kapitel wie in den
/// Planungsunterlagen des alten Planers: Deckblatt mit Kundendaten,
/// Konfigurationsnummer und Zusammenfassung, je Fläche Terrasse mit
/// Eckpunkthöhen, Unterkonstruktion mit Stückliste, Höhenzuordnung der
/// Auflager, Belag mit Dielen nach Nummer und Zuschnittsplan, dazu
/// Materialliste mit Preisen (nur Anzeige, B-055), Hinweise, rechtliche
/// Hinweise und Grußtext.
///
/// [gesamt] ist die Berechnung der ganzen Planung (Materialliste, Fläche,
/// Volumen), [flaechen] je Fläche der [planung] eine Unterlage.
Planungsunterlagen planungsunterlagen({
  required Planung planung,
  required Berechnung gesamt,
  required List<Flaechenunterlage> flaechen,
  required DateTime datum,
  KonfigurationsStand? stand,
  Kundendaten? kunde,
  Unterlagensprache sprache = Unterlagensprache.deutsch,
}) {
  final t = Unterlagentexte.fuer(sprache);
  final nummer = switch (stand) {
    final s? =>
      '${t.konfigurationsnummer} ${s.kennung.wert} · '
          '${t.version} ${s.version}',
    null => '${t.konfigurationsnummer}: ${t.ohneNummer}',
  };
  final mehrere = flaechen.length > 1;
  return Planungsunterlagen(
    texte: t,
    kopfzeile: nummer,
    kapitel: [
      _deckblatt(t, gesamt, flaechen.length, datum, stand, kunde),
      for (final (i, f) in flaechen.indexed)
        ..._flaeche(
          t,
          f,
          planung.flaechen[i],
          mehrere ? '${t.terrasseNummer} ${i + 1}' : t.terrasse,
        ),
      if (!gesamt.materialliste.istLeer)
        _materialliste(t, gesamt.materialliste),
      ?_hinweise(t, flaechen, planung, mehrere),
      _rechtliches(t),
    ],
  );
}

Kapitel _deckblatt(
  Unterlagentexte t,
  Berechnung gesamt,
  int flaechen,
  DateTime datum,
  KonfigurationsStand? stand,
  Kundendaten? kunde,
) => Kapitel(t.titel, [
  if (kunde != null) ...[
    Absatz(t.kunde, fett: true),
    Wertepaare([
      for (final (i, wert) in kunde.felder.indexed)
        if (wert.isNotEmpty) (t.kundenfelder[i], wert),
    ]),
  ],
  Wertepaare([
    (t.konfigurationsnummer, stand?.kennung.wert ?? t.ohneNummer),
    if (stand != null) (t.version, '${stand.version}'),
    (t.datum, _datum(datum)),
  ]),
  Absatz(t.zusammenfassung, fett: true),
  Wertepaare([
    (t.gesamtflaeche, '${t.zahl(gesamt.gesamtflaecheQuadratmeter, 3)} m²'),
    if (flaechen > 1) (t.flaechenanzahl, '$flaechen'),
    if (gesamt.volumen case final v?) (t.volumen, '${t.zahl(v, 3)} m³'),
    if (gesamt.verschnitt case final v?)
      (t.verschnitt, '${t.zahl(v * 100, 2)} %'),
    if (!gesamt.materialliste.istLeer)
      (t.summeMaterial, t.preis(gesamt.materialliste.summe)),
  ]),
]);

String _datum(DateTime d) => '${_zwei(d.day)}.${_zwei(d.month)}.${d.year}';

String _zwei(int n) => '$n'.padLeft(2, '0');

/// Kapitel einer Fläche: Terrasse mit Geometrie und Höhen, UK, Auflager,
/// Belag und Zuschnitt – was es nicht gibt, entfällt.
List<Kapitel> _flaeche(
  Unterlagentexte t,
  Flaechenunterlage f,
  Terrassenflaeche flaeche,
  String titel,
) {
  final b = f.berechnung;
  final unterbau = b.unterbau;
  final v = f.verlegung;
  return [
    Kapitel(titel, [
      _eckdaten(t, f, flaeche),
      Absatz(t.geometrie, fett: true),
      _grundriss(t, b),
      if (b.hoehenpunkte.hoehen.isNotEmpty) _hoehen(t, b),
    ]),
    if (unterbau.hoelzer.isNotEmpty)
      Kapitel('$titel – ${t.ukKapitel}', [
        _ukPlan(b),
        Absatz(t.stuecklisteUk, fett: true),
        _stueckliste(t, b.stueckliste, ohne: f.belag?.nummer),
      ]),
    if (unterbau.zuordnung.isNotEmpty)
      Kapitel('$titel – ${t.auflagerKapitel}', [
        if (unterbau.auflagerabstand case final a?)
          Wertepaare([(t.auflagerabstand, '${t.cm(a)} cm')]),
        Tabelle(
          [t.auflager, '${t.spalt} (cm)', t.anzahl],
          [
            for (final z in unterbau.zuordnung)
              [z.titel, '${t.cm(z.von)} – ${t.cm(z.bis)}', '${z.anzahl}'],
          ],
          rechts: {1, 2},
        ),
      ], neueSeite: false),
    if (v != null) ...[
      Kapitel('$titel – ${t.belagKapitel}', [
        Absatz(t.dielenHinweis),
        _belagPlan(b),
        Absatz(t.dielenNachNummer, fett: true),
        _sorten(t, v, f.belag!),
        Absatz(t.lieferung, fett: true),
        Tabelle(
          [t.laengeCm, t.stueck],
          [
            for (final MapEntry(key: laenge, value: n)
                in v.dielenliste.anzahl.entries)
              [t.cm(laenge), '$n'],
          ],
          rechts: {0, 1},
        ),
      ]),
      Kapitel('$titel – ${t.zuschnittBelag}', [
        _zuschnitt(t, v, f.belag!),
      ], neueSeite: false),
    ],
  ];
}

Wertepaare _eckdaten(
  Unterlagentexte t,
  Flaechenunterlage f,
  Terrassenflaeche flaeche,
) {
  final s = flaeche.stand;
  final b = f.berechnung;
  return Wertepaare([
    (t.flaeche, '${t.zahl(b.flaecheQuadratmeter, 3)} m²'),
    if (flaeche.haeufigkeit > 1) (t.haeufigkeit, '${flaeche.haeufigkeit}'),
    if (f.belag case final belag?) ...[
      (t.belag, belag.titel),
      (t.verlegerichtung, t.richtung(s.verlegerichtung, s.dielenwinkel)),
      (t.verlegeart, t.art(s.verlegeart)),
      (t.ausgangspunkt, _ausgangspunkt(t, s)),
      if (b.befestigung.art case final art?)
        (t.befestigung, t.befestigungsart(art)),
    ],
    (t.terrassenart, t.terrassenartText(s.terrassenart)),
    if (f.uk case final uk?) (t.unterkonstruktion, uk.titel),
    (t.untergrund, t.untergrundText(s.untergrund)),
    if (s.wirksameNutzungsart case final n?)
      (t.nutzungsart, t.nutzungsartText(n)),
    (t.nutzung, s.gewerblich ? t.gewerblich : t.privat),
    (t.auflagen, t.auflagenText(s.auflagen)),
    if (b.unterbau.feldbreite case final fb?) (t.feldbreite, '${t.cm(fb)} cm'),
  ]);
}

/// „A, waagrecht 0 cm, senkrecht 0 cm“ wie im alten Planer.
String _ausgangspunkt(Unterlagentexte t, Planungsstand s) =>
    '${eckname(s.ausgangsecke)} (${t.cm(s.verschiebungX)} cm | '
    '${t.cm(s.verschiebungY)} cm)';

/// Name des Eckpunkts [i]: A, B, … wie in der Zeichnung der App.
String eckname(int i) => _buchstaben[i % _buchstaben.length];

const _buchstaben = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

Plan _grundriss(Unterlagentexte t, Berechnung b) {
  final ecken = b.ecken;
  // Namen etwas außerhalb der Ecken, damit der Umriss sie nicht verdeckt
  final mitte = ecken.isEmpty ? Punkt.ursprung : _mitte(ecken);
  return Plan(
    [
      Planlinie(
        b.umriss,
        argb: _schwarz,
        geschlossen: b.geschlossen,
        staerke: 1,
      ),
      for (final a in b.ausschnitte) Planlinie(a, argb: _grau),
    ],
    [
      for (final (i, e) in ecken.indexed)
        (ort: mitte + (e - mitte) * 1.06, text: eckname(i)),
      // Kantenmaße in m an der Mitte jeder Kante
      for (var i = 0; i < ecken.length; i++)
        if (b.geschlossen || i < ecken.length - 1)
          (
            ort: (ecken[i] + ecken[(i + 1) % ecken.length]) * 0.5,
            text:
                '${t.zahl(ecken[i].abstand(ecken[(i + 1) % ecken.length]) / 1000, 2)} m',
          ),
    ],
  );
}

Tabelle _hoehen(Unterlagentexte t, Berechnung b) {
  final hoehen = b.hoehenpunkte.hoehen;
  final winkel = innenwinkel(b.ecken);
  return Tabelle(
    [t.eckpunkt, '${t.aufbauhoehe} (cm)', t.winkel],
    [
      for (final (i, h) in hoehen.indexed)
        [eckname(i), t.cm(h), if (i < winkel.length) '${winkel[i]}°' else ''],
    ],
    rechts: {1, 2},
  );
}

/// Innenwinkel je Eckpunkt in ganzen Grad – unabhängig vom Umlaufsinn
/// (90° bei einem Rechteck, 270° an der inneren Ecke einer L-Form).
List<int> innenwinkel(List<Punkt> ecken) {
  final n = ecken.length;
  if (n < 3) return const [];
  var flaeche = 0.0;
  for (var i = 0; i < n; i++) {
    flaeche += ecken[i].kreuz(ecken[(i + 1) % n]);
  }
  final sinn = flaeche.sign;
  return [
    for (var i = 0; i < n; i++)
      _winkel(ecken[(i + n - 1) % n], ecken[i], ecken[(i + 1) % n], sinn),
  ];
}

int _winkel(Punkt a, Punkt b, Punkt c, double sinn) {
  final ein = b - a;
  final aus = c - b;
  final drehung = math.atan2(ein.kreuz(aus), ein.punktprodukt(aus));
  return (180 - sinn * drehung * 180 / math.pi).round();
}

Plan _ukPlan(Berechnung b) {
  final u = b.unterbau;
  final halb = (u.holzbreite?.mm ?? 40) / 2;
  return Plan([
    Planlinie(b.umriss, argb: _grau, geschlossen: b.geschlossen),
    for (final h in u.hoelzer)
      Planlinie(
        _balken(h.von, h.bis, halb),
        argb: h.farbe.argb,
        gefuellt: true,
      ),
    for (final s in b.querstreben)
      Planlinie(
        [s.von, s.bis],
        argb: Stueckfarbe.gruen.argb,
        geschlossen: false,
        staerke: 1.5,
      ),
    for (final a in u.auflagerpunkte)
      Planlinie(_balken(a.ort, a.ort, 25), argb: _schwarz, gefuellt: true),
  ]);
}

/// Rechteck der Breite 2 × [halb] um die Strecke [von]–[bis], an den Enden
/// um [halb] verlängert – bei gleichen Punkten ein Quadrat.
List<Punkt> _balken(Punkt von, Punkt bis, double halb) {
  final richtung = bis.gleich(von) ? const Punkt(1, 0) : (bis - von).einheit;
  final laengs = richtung * halb;
  final quer = richtung.links * halb;
  return [
    von - laengs - quer,
    bis + laengs - quer,
    bis + laengs + quer,
    von - laengs + quer,
  ];
}

Plan _belagPlan(Berechnung b) => Plan(
  [
    Planlinie(b.umriss, argb: _schwarz, geschlossen: b.geschlossen),
    for (final (i, d) in b.dielen.indexed)
      Planlinie(d, argb: b.stueckfarben[i].argb, staerke: 0.3),
  ],
  [
    for (final (i, d) in b.dielen.indexed)
      (ort: _mitte(d), text: '${b.nummern[i]}'),
  ],
);

Punkt _mitte(List<Punkt> punkte) =>
    punkte.reduce((a, b) => a + b) * (1 / punkte.length);

/// Stückliste ohne die Zeilen des Belags [ohne] (die stehen beim Belag).
Tabelle _stueckliste(
  Unterlagentexte t,
  Stueckliste liste, {
  Artikelnummer? ohne,
}) {
  final zeilen = [
    for (final z in liste.zeilen)
      if (z.nummer != ohne) z,
  ];
  return Tabelle(
    [t.pos, t.artikel, t.laengeCm, t.stueck, t.farbeImPlan],
    [
      for (final (i, z) in zeilen.indexed)
        [
          '${i + 1}',
          z.titel,
          t.cm(z.laenge),
          '${z.stueck}',
          t.stueckfarbe(z.farbe),
        ],
    ],
    farben: [for (final z in zeilen) z.farbe],
    rechts: {0, 2, 3},
  );
}

/// „Dielen nach Nummer“ aller Teilflächen.
Tabelle _sorten(Unterlagentexte t, Belagverlegung v, Artikel belag) => Tabelle(
  [t.nr, t.artikel, t.masse, t.stueck],
  [
    for (final teil in v.teile)
      for (final s in teil.sorten)
        [
          '${s.nummer}',
          belag.titel,
          '${t.cm(s.laenge)} × ${t.cm(s.breite)}',
          '${s.stueck}',
        ],
  ],
  rechts: {0, 2, 3},
);

/// Zuschnittsplan: gleiche Lieferdielen mit gleichen Schnitten in einer
/// Zeile, in der Reihenfolge ihres ersten Auftretens.
Tabelle _zuschnitt(Unterlagentexte t, Belagverlegung v, Artikel belag) {
  final anzahl = <(Millimeter, String), int>{};
  for (final teil in v.teile) {
    for (final d in teil.zuschnitt) {
      final schnitte = [for (final s in d.schnitte) t.cm(s)].join(' | ');
      anzahl.update((d.laenge, schnitte), (n) => n + 1, ifAbsent: () => 1);
    }
  }
  return Tabelle(
    [t.artikel, t.ausgangslaenge, t.menge, t.schnittmasse],
    [
      for (final MapEntry(key: (laenge, schnitte), value: n) in anzahl.entries)
        [belag.titel, t.cm(laenge), '$n', schnitte],
    ],
    rechts: {1, 2},
  );
}

Kapitel _materialliste(Unterlagentexte t, Materialliste liste) =>
    Kapitel(t.materialliste, [
      Tabelle(
        [t.pos, t.artikel, t.menge, t.lfmGesamt, t.jeLfm, t.jeStueck, t.gesamt],
        [
          for (final p in liste.positionen)
            [
              '${p.position}',
              [
                p.titel,
                if (p.laenge case final l?) '${t.laenge}: ${l.mm} mm',
                if (p.zusatz == Materialzusatz.freidiele) t.freidiele,
                if (p.zusatz == Materialzusatz.optional) t.optional,
              ].join(' – '),
              '${p.anzahl} ${t.einheit(p.einheit)}',
              switch (p.gesamtlaenge) {
                final l? => t.zahl(l.m, 2),
                null => '',
              },
              _betrag(t, p.preisJeLfm, leer: p.gesamtlaenge == null),
              _betrag(t, p.einzelpreis),
              _betrag(t, p.positionspreis),
            ],
        ],
        rechts: {0, 2, 3, 4, 5, 6},
      ),
      Wertepaare([
        (t.summeGesamt, t.preis(liste.summe)),
        (t.mehrwertsteuer, t.preis(liste.mehrwertsteuer)),
      ]),
      Absatz(t.preisHinweis),
      if (!liste.vollstaendig) Absatz(t.preisFehlt),
    ]);

/// Betrag ohne Währungszeichen; fehlt er, „–“ (bzw. leer bei Ware ohne lfm).
String _betrag(Unterlagentexte t, Cent? betrag, {bool leer = false}) =>
    switch (betrag) {
      final b? => t.preis(b).replaceAll(' €', ''),
      null => leer ? '' : '–',
    };

/// Meldungen aller Flächen; ohne Meldung kein Kapitel.
Kapitel? _hinweise(
  Unterlagentexte t,
  List<Flaechenunterlage> flaechen,
  Planung planung,
  bool mehrere,
) {
  final absaetze = <Baustein>[];
  for (final (i, f) in flaechen.indexed) {
    final texte = _meldungen(t, f, planung.flaechen[i].stand);
    if (texte.isEmpty) continue;
    if (mehrere) {
      absaetze.add(Absatz('${t.terrasseNummer} ${i + 1}', fett: true));
    }
    absaetze.addAll([for (final m in texte) Absatz('• $m')]);
  }
  if (absaetze.isEmpty) return null;
  return Kapitel(t.hinweise, absaetze, neueSeite: false);
}

List<String> _meldungen(
  Unterlagentexte t,
  Flaechenunterlage f,
  Planungsstand stand,
) {
  final b = f.berechnung;
  final h = b.hoehenpunkte;
  final u = b.unterbau;
  return [
    if (b.flaechenmeldung case final m?) t.flaechenmeldung(m),
    for (final m in b.belagmeldungen) t.belagmeldung(m, stand.dielenlaenge),
    if (h.gedreht) t.ukGedreht,
    if (h.korrigiert) t.hoeheKorrigiert(h.mindesthoehe!),
    for (final m in u.meldungen)
      t.auflagermeldung(
        m,
        m == Auflagermeldung.unterMindesthoehe ? u.hoeheVon! : u.hoeheBis!,
      ),
  ];
}

Kapitel _rechtliches(Unterlagentexte t) => Kapitel(t.rechtliches, [
  for (final absatz in t.rechtlicheHinweise) Absatz(absatz),
  Absatz(t.gruss),
  for (final (i, zeile) in t.absender.indexed) Absatz(zeile, fett: i == 0),
]);
