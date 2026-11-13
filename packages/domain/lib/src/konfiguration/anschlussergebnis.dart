import 'package:flat_buffers/flat_buffers.dart' as fb;

import '../artikel/einheiten.dart';
import '../geometrie/punkt.dart';
import 'treppe.dart';

/// Rolle einer Seite im Terrassenanschluss (Fachkonzept 04) – bestimmt ihre
/// Farbe in der Zeichnung.
enum Seitenrolle {
  /// Grenzt an ein bestehendes Bauelement (M7-01): grau.
  bauelement(1),

  /// Verblendet (M7-02): gelb.
  verblendung(2),

  /// Mit Entwässerungsrinne (M7-03): blau.
  rinne(3);

  const Seitenrolle(this.nummer);

  /// Nummer im Transportformat.
  final int nummer;

  /// Rolle zur [nummer] aus dem Transportformat.
  static Seitenrolle ausNummer(int nummer) => values.firstWhere(
    (r) => r.nummer == nummer,
    orElse: () => throw FormatException('unbekannte Seitenrolle $nummer'),
  );
}

/// Hinweis zum Terrassenanschluss für die App (M7).
enum Anschlussmeldung {
  /// Alle freien Seiten sind verblendet: „Achtung: Bitte beachten Sie, dass
  /// eine Unterlüftung der Terrasse gewährleistet sein muss!“ (F37).
  unterlueftung(1),

  /// An einer verblendeten Seite liegt die Terrasse nicht über dem Boden
  /// (Höhe höchstens Dielenstärke) – dort keine Verblendung.
  keinHoehenunterschied(2),

  /// Die Artikeldaten nennen zum Belag keine Rinne (M7-03) – ohne Material
  /// und ohne Aussparung im Belag.
  ohneRinnenartikel(5),

  /// Eine Treppe liegt an einer Seite, die nicht frei ist (am Bauelement
  /// oder mit Rinne, Fachkonzept 5.1) – sie wird nicht gerechnet.
  treppeNichtFrei(6),

  /// Die Serie des Belags hat keine glattkante Blende in seiner Stärke und
  /// der nötigen Breite (Planungsregeln Alexander, Planungskern v6, 4a.4):
  /// Rückfrage statt raten, an dieser Seite kein Material. Ersetzt die
  /// früheren Meldungen 3 (Belagstärke 19–23 mm) und 4 (kein
  /// Verblendungsartikel).
  blendeFehlt(7),

  /// Eine Rinne liegt an einer Seite, die nicht gerade, waagerecht oder
  /// senkrecht ist oder kürzer als 30 cm (Planungsregeln Alexander,
  /// Planungskern v11, Regel 13.1.1) – dort keine Rinne.
  rinneNichtMoeglich(8),

  /// Die gewählte Rinnenfarbe gibt es in den Artikeldaten nicht (Regel
  /// 13.1.5) – Rinne ohne Material, Rückfrage.
  rinnenfarbeFehlt(9),

  /// Annahme zur Rinne (Regel 13.1.2): Systemschrauben UNIA 4,2 × 22 mm
  /// und Endkappen RELO VB stehen nicht in der Materialliste, Höhenausgleich
  /// mit GUMO.
  rinnenmontage(10),

  /// Für die Stützhölzer unter der Rinne nennen die Artikeldaten keine
  /// Eckverbundwinkel RELO E (Regel 13.1.4) – ohne Material, Rückfrage.
  eckwinkelFehlt(11),

  /// Blende am Bogen aus senkrechten Stücken (Planungsregeln Alexander
  /// (Planungskern v12, 12.11.2026), Regel 14.3.5): unten ca. 1 cm Luft,
  /// Hirnholz oben und unten mit Stirnkantenschutz streichen, je Stück
  /// 2 Schrauben in die Rand-UK, vorbohren.
  bogenblende(20),

  /// Ein Stück der Blende am Bogen ist höher als 30 cm: unten zusätzlich
  /// an einem Riegel befestigen (nicht in der Stückliste, Regel 14.3.5).
  bogenblendeRiegel(21);

  const Anschlussmeldung(this.nummer);

  /// Nummer im Transportformat.
  final int nummer;

  /// Meldung zur [nummer] aus dem Transportformat.
  static Anschlussmeldung ausNummer(int nummer) => values.firstWhere(
    (m) => m.nummer == nummer,
    orElse: () => throw FormatException('unbekannte Anschlussmeldung $nummer'),
  );
}

/// Hinweis der Prüfliste zu einer Treppe – Planungsregeln Alexander
/// (Planungskern v7, 11.11.2026) Regel 9.5.5 (`treppenpruefung`).
enum Treppenmeldung {
  /// Eine Steigung liegt außerhalb 15–19 cm.
  steigung(1),

  /// Ein Schrittmaß 2 × Steigung + Auftritt liegt außerhalb 59–67 cm.
  schrittmass(2),

  /// Die Treppe ist längs der Seite schmaler als 50 cm.
  zuSchmal(3),

  /// Die Treppe reicht über das Ende ihrer Seite hinaus.
  ueberSeite(4);

  const Treppenmeldung(this.nummer);

  /// Nummer im Transportformat.
  final int nummer;

  /// Meldung zur [nummer] aus dem Transportformat.
  static Treppenmeldung ausNummer(int nummer) => values.firstWhere(
    (m) => m.nummer == nummer,
    orElse: () => throw FormatException('unbekannte Treppenmeldung $nummer'),
  );
}

/// Eine Seite mit Rolle für die Zeichnung: Nummer der Seite, Rolle und die
/// Strecke von Ecke zu Ecke in mm.
typedef Seitenlinie = ({int seite, Seitenrolle rolle, Punkt von, Punkt bis});

/// Weiterer Höhenreferenzpunkt für die Zeichnung (M7-04): Ort in
/// Planungskoordinaten und geprüfte Höhe.
typedef Hoehenpunktort = ({Punkt ort, Millimeter hoehe});

/// Eine Treppe für Zeichnung und Anzeige (M7-05): Umrisse ihrer Teile
/// (Podest, Stufen) in Planungskoordinaten, Treppenmaße L × B × H und ob
/// sie an einer freien Seite liegt, dazu die Hinweise der Prüfliste
/// (Planungskern v7 Regel 9.5.5).
typedef Treppenbild = ({
  List<List<Punkt>> teile,
  Treppenmasse masse,
  bool frei,
  List<Treppenmeldung> meldungen,
});

/// Was der Server zum Terrassenanschluss der bearbeiteten Fläche rechnet
/// (M7): die Seiten mit Rolle für die Zeichnung (M7-01, M7-02) und die
/// Hinweise.
final class Anschlussergebnis {
  Anschlussergebnis({
    List<Seitenlinie> seiten = const [],
    List<Anschlussmeldung> meldungen = const [],
    List<Hoehenpunktort> hoehenpunkte = const [],
    List<Treppenbild> treppen = const [],
  }) : treppen = List.unmodifiable(treppen),
       seiten = List.unmodifiable(seiten),
       meldungen = List.unmodifiable(meldungen),
       hoehenpunkte = List.unmodifiable(hoehenpunkte);

  /// Liest die Tabelle am Ort [ort] ([schreibe]).
  factory Anschlussergebnis.lies(fb.BufferContext puffer, int ort) {
    final nummern = const fb.ListReader<int>(fb.Uint16Reader())
        .vTableGet(puffer, ort, _versatz(_seitenPlatz), const []);
    final rollen = const fb.ListReader<int>(fb.Uint8Reader())
        .vTableGet(puffer, ort, _versatz(_rollenPlatz), const []);
    final punkte = const fb.ListReader<double>(fb.Float64Reader())
        .vTableGet(puffer, ort, _versatz(_linienPlatz), const []);
    final orte = const fb.ListReader<double>(fb.Float64Reader())
        .vTableGet(puffer, ort, _versatz(_punkteOrtePlatz), const []);
    final hoehen = const fb.ListReader<int>(fb.Int32Reader())
        .vTableGet(puffer, ort, _versatz(_punkteHoehenPlatz), const []);
    return Anschlussergebnis(
      seiten: [
        for (var i = 0; i < nummern.length; i++)
          (
            seite: nummern[i],
            rolle: Seitenrolle.ausNummer(rollen[i]),
            von: Punkt(punkte[4 * i], punkte[4 * i + 1]),
            bis: Punkt(punkte[4 * i + 2], punkte[4 * i + 3]),
          ),
      ],
      meldungen: [
        for (final n in const fb.ListReader<int>(
          fb.Uint8Reader(),
        ).vTableGet(puffer, ort, _versatz(_meldungenPlatz), const []))
          Anschlussmeldung.ausNummer(n),
      ],
      hoehenpunkte: [
        for (var i = 0; i < hoehen.length; i++)
          (
            ort: Punkt(orte[2 * i], orte[2 * i + 1]),
            hoehe: Millimeter(hoehen[i]),
          ),
      ],
      treppen: [
        for (final t in const fb.ListReader<int>(
          _Tabellenort(),
        ).vTableGet(puffer, ort, _versatz(_treppenPlatz), const []))
          _liesTreppe(puffer, t),
      ],
    );
  }

  static Treppenbild _liesTreppe(fb.BufferContext puffer, int ort) {
    final masse = const fb.ListReader<int>(fb.Int32Reader())
        .vTableGet(puffer, ort, _versatz(0), const [0, 0, 0]);
    return (
      teile: [
        for (final t in const fb.ListReader<int>(
          _Tabellenort(),
        ).vTableGet(puffer, ort, _versatz(2), const []))
          _punkte(puffer, t),
      ],
      masse: (
        laenge: Millimeter(masse[0]),
        breite: Millimeter(masse[1]),
        hoehe: Millimeter(masse[2]),
      ),
      frei: const fb.BoolReader().vTableGet(puffer, ort, _versatz(1), true),
      meldungen: [
        for (final n in const fb.ListReader<int>(
          fb.Uint8Reader(),
        ).vTableGet(puffer, ort, _versatz(3), const []))
          Treppenmeldung.ausNummer(n),
      ],
    );
  }

  static List<Punkt> _punkte(fb.BufferContext puffer, int ort) {
    final k = const fb.ListReader<double>(fb.Float64Reader())
        .vTableGet(puffer, ort, _versatz(0), const []);
    return [
      for (var i = 0; i < k.length ~/ 2; i++) Punkt(k[2 * i], k[2 * i + 1]),
    ];
  }

  /// Ohne Seiten mit Rolle.
  static final leer = Anschlussergebnis();

  /// Seiten mit Rolle in der Reihenfolge der Seiten.
  final List<Seitenlinie> seiten;

  /// Hinweise zum Anschluss der bearbeiteten Fläche.
  final List<Anschlussmeldung> meldungen;

  /// Weitere Höhenreferenzpunkte (Abläufe) für die Zeichnung (M7-04).
  final List<Hoehenpunktort> hoehenpunkte;

  /// Treppen in der Reihenfolge des Planungsstands (M7-05).
  final List<Treppenbild> treppen;

  /// Schreibt die Tabelle `{ 0: seiten ([uint16]), 1: rollen ([uint8]),
  /// 2: linien ([float64] von x, y, bis x, y je Seite), 3: meldungen
  /// ([uint8], M7-02), 4: Orte der Höhenreferenzpunkte ([float64] x, y),
  /// 5: ihre Höhen ([int32] mm) (M7-04), 6: treppen ([{ 0: masse ([int32]
  /// L, B, H mm), 1: frei (bool), 2: teile ([{ 0: punkte ([float64]) }]),
  /// 3: meldungen ([uint8], Planungskern v7 Regel 9.5.5) }], M7-05) }` und
  /// gibt ihren Ort zurück. Neue Felder nur anhängen.
  int schreibe(fb.Builder fbb) {
    final seitenOrt = fbb.writeListUint16([for (final s in seiten) s.seite]);
    final rollenOrt = fbb.writeListUint8([
      for (final s in seiten) s.rolle.nummer,
    ]);
    final linienOrt = fbb.writeListFloat64([
      for (final s in seiten) ...[s.von.x, s.von.y, s.bis.x, s.bis.y],
    ]);
    final meldungenOrt = fbb.writeListUint8([
      for (final m in meldungen) m.nummer,
    ]);
    final orteOrt = fbb.writeListFloat64([
      for (final p in hoehenpunkte) ...[p.ort.x, p.ort.y],
    ]);
    final hoehenOrt = fbb.writeListInt32([
      for (final p in hoehenpunkte) p.hoehe.mm,
    ]);
    final treppenOrt = fbb.writeList([
      for (final t in treppen) _schreibeTreppe(fbb, t),
    ]);
    fbb
      ..startTable(_treppenPlatz + 1)
      ..addOffset(_seitenPlatz, seitenOrt)
      ..addOffset(_rollenPlatz, rollenOrt)
      ..addOffset(_linienPlatz, linienOrt)
      ..addOffset(_meldungenPlatz, meldungenOrt)
      ..addOffset(_punkteOrtePlatz, orteOrt)
      ..addOffset(_punkteHoehenPlatz, hoehenOrt)
      ..addOffset(_treppenPlatz, treppenOrt);
    return fbb.endTable();
  }

  static int _schreibeTreppe(fb.Builder fbb, Treppenbild t) {
    final masseOrt = fbb.writeListInt32([
      t.masse.laenge.mm,
      t.masse.breite.mm,
      t.masse.hoehe.mm,
    ]);
    final teileOrt = fbb.writeList([
      for (final teil in t.teile) _schreibePunkte(fbb, teil),
    ]);
    final meldungenOrt = t.meldungen.isEmpty
        ? null
        : fbb.writeListUint8([for (final m in t.meldungen) m.nummer]);
    fbb
      ..startTable(4)
      ..addOffset(0, masseOrt)
      ..addBool(1, t.frei)
      ..addOffset(2, teileOrt)
      ..addOffset(3, meldungenOrt);
    return fbb.endTable();
  }

  static int _schreibePunkte(fb.Builder fbb, List<Punkt> punkte) {
    final ort = fbb.writeListFloat64([
      for (final p in punkte) ...[p.x, p.y],
    ]);
    fbb
      ..startTable(1)
      ..addOffset(0, ort);
    return fbb.endTable();
  }

  static const _seitenPlatz = 0;
  static const _rollenPlatz = 1;
  static const _linienPlatz = 2;
  static const _meldungenPlatz = 3;
  static const _punkteOrtePlatz = 4;
  static const _punkteHoehenPlatz = 5;
  static const _treppenPlatz = 6;
}

/// Liest nur den Ort einer Tabelle – die Felder liest der Aufrufer.
final class _Tabellenort extends fb.TableReader<int> {
  const _Tabellenort();

  @override
  int createObject(fb.BufferContext puffer, int ort) => ort;
}

int _versatz(int platz) => 4 + 2 * platz;
