/// Materialliste der ganzen Planung (M9-03, Fachkonzept 08): alle Artikel
/// mit Menge und Preisen – nur Anzeige, führend ist GrandTotal (B-055).
///
/// Jede Quelle (Belag M5-08, Befestigung M5-09, später Unterkonstruktion M6
/// und Zubehör M8) liefert ihren Bedarf als Liste von [Materialbedarf]; die
/// Materialliste fasst gleiche Bedarfe über Flächen und Quellen zusammen,
/// wählt die Verkaufseinheiten ([verpackt]) und rechnet die Preise aus den
/// Artikeldaten (Verkaufspreise wie im Shop, B-152/B-123).
library;

import 'dart:math' as math;

import 'package:flat_buffers/flat_buffers.dart' as fb;

import '../artikel/artikel.dart';
import '../artikel/einheiten.dart';
import '../regeln/befestigungsbedarf.dart';

/// Mehrwertsteuersatz in Prozent, der in den Bruttopreisen enthalten ist
/// („enthaltene 19% MwSt.“ wie im alten Planer, Shop Deutschland).
const mehrwertsteuerSatz = 19;

/// Zusatz einer Position, der sie von einer gleichen Position ohne Zusatz
/// trennt.
enum Materialzusatz {
  /// Freidiele (B-079, R-B09): steht mit Preis 0 in der Materialliste
  /// (Fachkonzept 08); gerechnet wird sie mit dem Zubehör (M8).
  freidiele(1),

  /// Verblendung (M7-02, Fachkonzept 4.2): Dielen für die verblendeten
  /// Seiten, „– Verblendung“ wie im alten Planer, nur in der Materialliste.
  verblendung(2);

  const Materialzusatz(this.nummer);

  /// Kennung im Transportformat (0 = kein Zusatz).
  final int nummer;

  /// Zusatz zur [nummer]; `null` für 0 oder unbekannte Nummern.
  static Materialzusatz? ausNummer(int nummer) =>
      values.where((z) => z.nummer == nummer).firstOrNull;
}

/// Schlüssel einer Position: gleiche Artikelnummer, Länge und Zusatz sind
/// eine Position. Unter ihm merkt sich die Planung geänderte Mengen der
/// Mitarbeiter-Ansicht.
typedef Positionsschluessel = ({
  Artikelnummer nummer,
  Millimeter? laenge,
  Materialzusatz? zusatz,
});

/// Bedarf einer Quelle (M9-03): so viele [stueck] eines Artikels, der in
/// den [einheiten] verkauft wird – meist eine, bei Clips z. B. VPE 50, 100
/// und 250 desselben Clips. Mit [laenge] ist es ein Stück in dieser
/// Lieferlänge (Dielen, UK): gezählt wird je Stück, nicht verpackt.
final class Materialbedarf {
  Materialbedarf(
    List<Artikel> einheiten,
    this.stueck, {
    this.laenge,
    this.zusatz,
    this.jePlanung = false,
  }) : einheiten = List.unmodifiable(einheiten) {
    if (einheiten.isEmpty) {
      throw ArgumentError.value(einheiten, 'einheiten', 'mindestens eine');
    }
    if (laenge != null && einheiten.length > 1) {
      throw ArgumentError.value(
        einheiten,
        'einheiten',
        'ein Stück mit Länge hat genau einen Artikel',
      );
    }
    if (stueck < 0) {
      throw ArgumentError.value(stueck, 'stueck', 'nicht negativ');
    }
  }

  /// Verkaufseinheiten des Bedarfs, wie im Regelwerk verwiesen.
  final List<Artikel> einheiten;

  /// Benötigte Stück (bei Dielen und UK: Anzahl der Lieferstücke).
  final int stueck;

  /// Lieferlänge eines Stücks; `null` für Artikel ohne Länge.
  final Millimeter? laenge;
  final Materialzusatz? zusatz;

  /// Einmal je Planung, unabhängig von Flächen und Häufigkeit (z. B. die
  /// wiederverwendbare Montagehilfe, Fachkonzept 2.6).
  final bool jePlanung;

  /// Bedarf einer Fläche, die [haeufigkeit]-mal gebaut wird (M4-14); ein
  /// Bedarf [jePlanung] bleibt gleich.
  Materialbedarf operator *(int haeufigkeit) => jePlanung
      ? this
      : Materialbedarf(
          einheiten,
          stueck * haeufigkeit,
          laenge: laenge,
          zusatz: zusatz,
        );

  /// Gleiche Bedarfe werden zusammengefasst: gleiche Einheiten, Länge und
  /// Zusatz.
  String get _gruppe => [
    for (final e in einheiten) e.nummer.wert,
    '${laenge?.mm}',
    '${zusatz?.nummer}',
    '$jePlanung',
  ].join('|');

  @override
  String toString() => '$stueck × ${einheiten.first}';
}

/// Holzvolumen der [bedarfe] in m³ (M6-10, Kennzahl „Volumen“ wie im alten
/// Planer): je Bedarf mit Lieferlänge Stück × Länge × Breite × Stärke des
/// Artikels – Dielen und UK so, wie sie geliefert werden (F28: 112 m UK
/// 40 × 60 = 0,269 m³). Bedarfe ohne Länge oder Querschnitt zählen nicht;
/// `null`, wenn keiner zählt.
double? holzvolumen(Iterable<Materialbedarf> bedarfe) {
  double? summe;
  for (final b in bedarfe) {
    final masse = b.einheiten.first.abmessungen;
    final (laenge, breite, staerke) = (b.laenge, masse.breite, masse.staerke);
    if (laenge == null || breite == null || staerke == null) continue;
    summe = (summe ?? 0) + b.stueck * laenge.m * breite.m * staerke.m;
  }
  return summe;
}

/// Eine Zeile der Materialliste (M9-03): Position, Bild, Artikel, Menge,
/// Einzelpreis, Positionspreis, Preis je lfm und Gesamt-lfm. Preise brutto
/// inklusive Mehrwertsteuer in Cent, nur Anzeige (B-055); `null`, wenn der
/// Artikel keinen Preis hat.
final class Materialzeile {
  const Materialzeile({
    required this.position,
    required this.nummer,
    required this.titel,
    required this.bereich,
    required this.einheit,
    required this.anzahl,
    this.bild,
    this.laenge,
    this.berechnet,
    this.zusatz,
    this.einzelpreis,
    this.positionspreis,
    this.preisJeLfm,
    this.gesamtlaenge,
  });

  /// Positionsnummer ab 1.
  final int position;
  final Artikelnummer nummer;

  /// Titel wie im Shop (B-152).
  final String titel;

  /// Erste Abbildung des Artikels (Dateiname der Artikeldaten, M2-07).
  final String? bild;
  final Bereich bereich;

  /// Einheit der [anzahl]: Stück bei Dielen und UK, sonst die
  /// Verkaufseinheit (VPE, Karton, lfm …).
  final Mengeneinheit einheit;

  /// Lieferlänge (Dielen, UK); `null` ohne Länge.
  final Millimeter? laenge;

  /// Menge in [einheit] – in der Mitarbeiter-Ansicht änderbar.
  final int anzahl;

  /// Berechnete Menge, wenn ein Mitarbeiter sie geändert hat; sonst `null`
  /// (R-D04: der geänderte Wert steht unter dem berechneten).
  final int? berechnet;
  final Materialzusatz? zusatz;

  /// Preis je Stück bzw. Verkaufseinheit.
  final Cent? einzelpreis;

  /// Preis der Position (bei Ware je lfm aus den Gesamt-lfm gerechnet).
  final Cent? positionspreis;

  /// Preis je laufendem Meter, wenn die Position eine Länge hat.
  final Cent? preisJeLfm;

  /// Gesamtlänge ([anzahl] × [laenge]) für „Gesamt-lfm“.
  final Millimeter? gesamtlaenge;

  Positionsschluessel get schluessel =>
      (nummer: nummer, laenge: laenge, zusatz: zusatz);

  @override
  bool operator ==(Object other) =>
      other is Materialzeile &&
      other.position == position &&
      other.nummer == nummer &&
      other.titel == titel &&
      other.bild == bild &&
      other.bereich == bereich &&
      other.einheit == einheit &&
      other.laenge == laenge &&
      other.anzahl == anzahl &&
      other.berechnet == berechnet &&
      other.zusatz == zusatz &&
      other.einzelpreis == einzelpreis &&
      other.positionspreis == positionspreis &&
      other.preisJeLfm == preisJeLfm &&
      other.gesamtlaenge == gesamtlaenge;

  @override
  int get hashCode => Object.hash(
    position,
    nummer,
    titel,
    bild,
    bereich,
    einheit,
    laenge,
    anzahl,
    berechnet,
    zusatz,
    einzelpreis,
    positionspreis,
    preisJeLfm,
    gesamtlaenge,
  );

  @override
  String toString() => '$position. $anzahl ${einheit.anzeige} $nummer $titel';
}

/// Materialliste der Planung (M9-03): Positionen, Summe brutto und die
/// darin enthaltene Mehrwertsteuer – nur Anzeige (B-055).
final class Materialliste {
  Materialliste(
    List<Materialzeile> positionen, {
    required this.summe,
    required this.mehrwertsteuer,
    this.vollstaendig = true,
  }) : positionen = List.unmodifiable(positionen);

  /// Fasst die [bedarfe] aller Quellen und Flächen zusammen (gleiche
  /// Einheiten, Länge und Zusatz: Stück addiert, ein Bedarf je Planung
  /// zählt einmal), wählt die Verkaufseinheiten ([verpackt]: wenig
  /// Überhang, wenig Packungen) und rechnet die Preise.
  ///
  /// [mengen] sind geänderte Mengen der Mitarbeiter-Ansicht (R-D04): Sie
  /// ersetzen die berechnete Anzahl ihrer Position, die berechnete bleibt
  /// in [Materialzeile.berechnet] sichtbar; 0 wählt die Position ab.
  /// Mengen zu Positionen, die es nicht mehr gibt, wirken nicht.
  ///
  /// Reihenfolge: Bereich (Belag, Unterkonstruktion, Befestigung, Auflager,
  /// Anschluss, Zubehör), dann Artikelnummer, Länge und Zusatz.
  factory Materialliste.aus(
    Iterable<Materialbedarf> bedarfe, {
    Map<Positionsschluessel, int> mengen = const {},
  }) {
    final gruppen = <String, Materialbedarf>{};
    for (final b in bedarfe) {
      gruppen.update(
        b._gruppe,
        (v) => Materialbedarf(
          v.einheiten,
          b.jePlanung ? math.max(v.stueck, b.stueck) : v.stueck + b.stueck,
          laenge: v.laenge,
          zusatz: v.zusatz,
          jePlanung: v.jePlanung,
        ),
        ifAbsent: () => b,
      );
    }
    final anzahl = <Positionsschluessel, (Artikel, int)>{};
    for (final b in gruppen.values) {
      final teile = b.laenge == null
          ? verpackt(b.stueck, b.einheiten)
          : [if (b.stueck > 0) (b.einheiten.single, b.stueck)];
      for (final (artikel, n) in teile) {
        anzahl.update(
          (nummer: artikel.nummer, laenge: b.laenge, zusatz: b.zusatz),
          (v) => (artikel, v.$2 + n),
          ifAbsent: () => (artikel, n),
        );
      }
    }
    final schluessel = anzahl.keys.toList()..sort(_vergleiche(anzahl));
    final positionen = [
      for (final (i, s) in schluessel.indexed)
        _position(i + 1, s, anzahl[s]!.$1, anzahl[s]!.$2, mengen[s]),
    ];
    final summe = positionen.fold(
      const Cent(0),
      (summe, p) => summe + (p.positionspreis ?? const Cent(0)),
    );
    return Materialliste(
      positionen,
      summe: summe,
      mehrwertsteuer: enthalteneMehrwertsteuer(summe),
      vollstaendig: positionen.every((p) => p.positionspreis != null),
    );
  }

  /// Liest die Materialliste aus einem Puffer an [ort] ([schreibe]).
  factory Materialliste.lies(fb.BufferContext puffer, int ort) => Materialliste(
    [
      for (final p in const fb.ListReader<int>(
        _Tabellenort(),
      ).vTableGet(puffer, ort, _versatz(0), const []))
        _liesPosition(puffer, p),
    ],
    summe: Cent(_int64(puffer, ort, 1) ?? 0),
    mehrwertsteuer: Cent(_int64(puffer, ort, 2) ?? 0),
    vollstaendig: const fb.BoolReader().vTableGet(
      puffer,
      ort,
      _versatz(3),
      true,
    ),
  );

  /// Ohne Positionen.
  static final leer = Materialliste(
    const [],
    summe: const Cent(0),
    mehrwertsteuer: const Cent(0),
  );

  final List<Materialzeile> positionen;

  /// Summe aller Positionspreise brutto.
  final Cent summe;

  /// In der [summe] enthaltene Mehrwertsteuer ([mehrwertsteuerSatz]).
  final Cent mehrwertsteuer;

  /// Ob jede Position einen Preis hat; sonst fehlt deren Preis in der
  /// [summe].
  final bool vollstaendig;

  bool get istLeer => positionen.isEmpty;

  /// Schreibt die Materialliste als Tabelle `{ 0: positionen ([{ 0:
  /// position (uint32), 1: nummer (string), 2: titel (string), 3: bild
  /// (string), 4: bereich (uint8), 5: einheit (uint8), 6: laenge (int32 mm),
  /// 7: anzahl (uint32), 8: berechnet (uint32), 9: zusatz (uint8), 10:
  /// einzelpreis, 11: positionspreis, 12: preisJeLfm (int64 Cent), 13:
  /// gesamtlaenge (int32 mm) }]; fehlende Werte fehlen), 1: summe, 2:
  /// mehrwertsteuer (int64 Cent), 3: vollstaendig (bool) }` und gibt ihren
  /// Ort zurück.
  int schreibe(fb.Builder fbb) {
    final orte = fbb.writeList([
      for (final p in positionen) _schreibePosition(fbb, p),
    ]);
    fbb
      ..startTable(4)
      ..addOffset(0, orte)
      ..addInt64(1, summe.cent)
      ..addInt64(2, mehrwertsteuer.cent)
      ..addBool(3, vollstaendig);
    return fbb.endTable();
  }

  @override
  bool operator ==(Object other) =>
      other is Materialliste &&
      other.summe == summe &&
      other.mehrwertsteuer == mehrwertsteuer &&
      other.vollstaendig == vollstaendig &&
      _gleich(other.positionen, positionen);

  @override
  int get hashCode => Object.hash(
    summe,
    mehrwertsteuer,
    vollstaendig,
    Object.hashAll(positionen),
  );
}

/// In einem Bruttobetrag enthaltene Mehrwertsteuer ([mehrwertsteuerSatz])
/// auf ganze Cent: Brutto minus gerundetes Netto, damit Netto und Steuer
/// zusammen genau die Summe ergeben (2.066,57 € → 329,96 €).
Cent enthalteneMehrwertsteuer(Cent brutto) => Cent(
  brutto.cent - (brutto.cent * 100 / (100 + mehrwertsteuerSatz)).round(),
);

Materialzeile _position(
  int position,
  Positionsschluessel s,
  Artikel artikel,
  int berechnet,
  int? geaendert,
) {
  final anzahl = geaendert ?? berechnet;
  final laenge = s.laenge;
  final (:einzel, :gesamt, :jeLfm) = _preise(artikel, laenge, anzahl, s.zusatz);
  return Materialzeile(
    position: position,
    nummer: artikel.nummer,
    titel: artikel.titel,
    bild: artikel.bilder.firstOrNull,
    bereich: artikel.art.bereich,
    einheit: laenge == null ? artikel.einheit.einheit : Mengeneinheit.stueck,
    laenge: laenge,
    anzahl: anzahl,
    berechnet: geaendert == null || geaendert == berechnet ? null : berechnet,
    zusatz: s.zusatz,
    einzelpreis: einzel,
    positionspreis: gesamt,
    preisJeLfm: jeLfm,
    gesamtlaenge: laenge == null ? null : laenge * anzahl,
  );
}

/// Preise einer Position. Ware je lfm (Dielen): Preis je lfm = Preis der
/// Verkaufseinheit ÷ Inhalt, Einzelpreis = je lfm × Länge, Positionspreis =
/// je lfm × Gesamt-lfm – so bleibt die Summe gleich, wie auch immer die
/// Längen gemischt sind (Fachkonzept 7.1). Sonst Einzelpreis = Preis der
/// Verkaufseinheit, Positionspreis = Einzelpreis × Anzahl, mit Länge auch
/// der Preis je lfm. Freidielen kosten nichts (B-079). Jeder Preis wird
/// einmal auf ganze Cent gerundet.
({Cent? einzel, Cent? gesamt, Cent? jeLfm}) _preise(
  Artikel artikel,
  Millimeter? laenge,
  int anzahl,
  Materialzusatz? zusatz,
) {
  if (zusatz == Materialzusatz.freidiele) {
    return (
      einzel: const Cent(0),
      gesamt: const Cent(0),
      jeLfm: laenge == null ? null : const Cent(0),
    );
  }
  final preis = artikel.preisBrutto;
  if (preis == null) return (einzel: null, gesamt: null, jeLfm: null);
  if (laenge != null && artikel.einheit.einheit == Mengeneinheit.laufmeter) {
    final jeLfm = preis.cent / artikel.einheit.inhalt;
    return (
      einzel: Cent((jeLfm * laenge.m).round()),
      gesamt: Cent((jeLfm * laenge.mm * anzahl / 1000).round()),
      jeLfm: Cent(jeLfm.round()),
    );
  }
  return (
    einzel: preis,
    gesamt: Cent(preis.cent * anzahl),
    jeLfm: laenge == null ? null : Cent((preis.cent / laenge.m).round()),
  );
}

int Function(Positionsschluessel, Positionsschluessel) _vergleiche(
  Map<Positionsschluessel, (Artikel, int)> anzahl,
) => (a, b) {
  final bereich = anzahl[a]!.$1.art.bereich.index.compareTo(
    anzahl[b]!.$1.art.bereich.index,
  );
  if (bereich != 0) return bereich;
  final nummer = a.nummer.wert.compareTo(b.nummer.wert);
  if (nummer != 0) return nummer;
  final laenge = (a.laenge?.mm ?? 0).compareTo(b.laenge?.mm ?? 0);
  if (laenge != 0) return laenge;
  return (a.zusatz?.nummer ?? 0).compareTo(b.zusatz?.nummer ?? 0);
};

bool _gleich(List<Materialzeile> a, List<Materialzeile> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

int _schreibePosition(fb.Builder fbb, Materialzeile p) {
  final nummerOrt = fbb.writeString(p.nummer.wert);
  final titelOrt = fbb.writeString(p.titel);
  final bildOrt = switch (p.bild) {
    final b? => fbb.writeString(b),
    null => null,
  };
  fbb
    ..startTable(14)
    ..addUint32(0, p.position)
    ..addOffset(1, nummerOrt)
    ..addOffset(2, titelOrt)
    ..addOffset(3, bildOrt)
    ..addUint8(4, p.bereich.index)
    ..addUint8(5, p.einheit.index)
    ..addInt32(6, p.laenge?.mm)
    ..addUint32(7, p.anzahl)
    ..addUint32(8, p.berechnet)
    ..addUint8(9, p.zusatz?.nummer)
    ..addInt64(10, p.einzelpreis?.cent)
    ..addInt64(11, p.positionspreis?.cent)
    ..addInt64(12, p.preisJeLfm?.cent)
    ..addInt32(13, p.gesamtlaenge?.mm);
  return fbb.endTable();
}

Materialzeile _liesPosition(fb.BufferContext puffer, int ort) {
  Millimeter? mm(int platz) => switch (const fb.Int32Reader().vTableGetNullable(
    puffer,
    ort,
    _versatz(platz),
  )) {
    final w? => Millimeter(w),
    null => null,
  };
  Cent? cent(int platz) => switch (_int64(puffer, ort, platz)) {
    final w? => Cent(w),
    null => null,
  };
  return Materialzeile(
    position: const fb.Uint32Reader().vTableGet(puffer, ort, _versatz(0), 0),
    nummer: Artikelnummer(
      const fb.StringReader().vTableGet(puffer, ort, _versatz(1), ''),
    ),
    titel: const fb.StringReader().vTableGet(puffer, ort, _versatz(2), ''),
    bild: const fb.StringReader().vTableGetNullable(puffer, ort, _versatz(3)),
    bereich: Bereich
        .values[const fb.Uint8Reader().vTableGet(puffer, ort, _versatz(4), 0)],
    einheit: Mengeneinheit
        .values[const fb.Uint8Reader().vTableGet(puffer, ort, _versatz(5), 0)],
    laenge: mm(6),
    anzahl: const fb.Uint32Reader().vTableGet(puffer, ort, _versatz(7), 0),
    berechnet: const fb.Uint32Reader().vTableGetNullable(
      puffer,
      ort,
      _versatz(8),
    ),
    zusatz: Materialzusatz.ausNummer(
      const fb.Uint8Reader().vTableGet(puffer, ort, _versatz(9), 0),
    ),
    einzelpreis: cent(10),
    positionspreis: cent(11),
    preisJeLfm: cent(12),
    gesamtlaenge: mm(13),
  );
}

int? _int64(fb.BufferContext puffer, int ort, int platz) =>
    const fb.Int64Reader().vTableGetNullable(puffer, ort, _versatz(platz));

int _versatz(int platz) => 4 + 2 * platz;

/// Liest nur den Ort einer Tabelle – die Felder liest der Aufrufer.
final class _Tabellenort extends fb.TableReader<int> {
  const _Tabellenort();

  @override
  int createObject(fb.BufferContext puffer, int ort) => ort;
}
