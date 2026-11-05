import 'package:flat_buffers/flat_buffers.dart' as fb;

import '../artikel/einheiten.dart';
import '../geometrie/punkt.dart';

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

  /// Verblendung nur bei Belagstärke 19–23 mm (Fachkonzept 4.2).
  belagstaerke(3),

  /// Die Artikeldaten nennen zum Belag keine Verblendung.
  ohneVerblendungsartikel(4),

  /// Die Artikeldaten nennen zum Belag keine Rinne (M7-03) – ohne Material
  /// und ohne Aussparung im Belag.
  ohneRinnenartikel(5);

  const Anschlussmeldung(this.nummer);

  /// Nummer im Transportformat.
  final int nummer;

  /// Meldung zur [nummer] aus dem Transportformat.
  static Anschlussmeldung ausNummer(int nummer) => values.firstWhere(
    (m) => m.nummer == nummer,
    orElse: () => throw FormatException('unbekannte Anschlussmeldung $nummer'),
  );
}

/// Eine Seite mit Rolle für die Zeichnung: Nummer der Seite, Rolle und die
/// Strecke von Ecke zu Ecke in mm.
typedef Seitenlinie = ({int seite, Seitenrolle rolle, Punkt von, Punkt bis});

/// Weiterer Höhenreferenzpunkt für die Zeichnung (M7-04): Ort in
/// Planungskoordinaten und geprüfte Höhe.
typedef Hoehenpunktort = ({Punkt ort, Millimeter hoehe});

/// Was der Server zum Terrassenanschluss der bearbeiteten Fläche rechnet
/// (M7): die Seiten mit Rolle für die Zeichnung (M7-01, M7-02) und die
/// Hinweise.
final class Anschlussergebnis {
  Anschlussergebnis({
    List<Seitenlinie> seiten = const [],
    List<Anschlussmeldung> meldungen = const [],
    List<Hoehenpunktort> hoehenpunkte = const [],
  }) : seiten = List.unmodifiable(seiten),
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
    );
  }

  /// Ohne Seiten mit Rolle.
  static final leer = Anschlussergebnis();

  /// Seiten mit Rolle in der Reihenfolge der Seiten.
  final List<Seitenlinie> seiten;

  /// Hinweise zum Anschluss der bearbeiteten Fläche.
  final List<Anschlussmeldung> meldungen;

  /// Weitere Höhenreferenzpunkte (Abläufe) für die Zeichnung (M7-04).
  final List<Hoehenpunktort> hoehenpunkte;

  /// Schreibt die Tabelle `{ 0: seiten ([uint16]), 1: rollen ([uint8]),
  /// 2: linien ([float64] von x, y, bis x, y je Seite), 3: meldungen
  /// ([uint8], M7-02), 4: Orte der Höhenreferenzpunkte ([float64] x, y),
  /// 5: ihre Höhen ([int32] mm) (M7-04) }` und gibt ihren Ort zurück. Neue
  /// Felder nur anhängen.
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
    fbb
      ..startTable(_punkteHoehenPlatz + 1)
      ..addOffset(_seitenPlatz, seitenOrt)
      ..addOffset(_rollenPlatz, rollenOrt)
      ..addOffset(_linienPlatz, linienOrt)
      ..addOffset(_meldungenPlatz, meldungenOrt)
      ..addOffset(_punkteOrtePlatz, orteOrt)
      ..addOffset(_punkteHoehenPlatz, hoehenOrt);
    return fbb.endTable();
  }

  static const _seitenPlatz = 0;
  static const _rollenPlatz = 1;
  static const _linienPlatz = 2;
  static const _meldungenPlatz = 3;
  static const _punkteOrtePlatz = 4;
  static const _punkteHoehenPlatz = 5;
}

int _versatz(int platz) => 4 + 2 * platz;
