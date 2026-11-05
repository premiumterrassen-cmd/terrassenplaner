import 'package:flat_buffers/flat_buffers.dart' as fb;

import '../geometrie/punkt.dart';

/// Rolle einer Seite im Terrassenanschluss (Fachkonzept 04) – bestimmt ihre
/// Farbe in der Zeichnung.
enum Seitenrolle {
  /// Grenzt an ein bestehendes Bauelement (M7-01): grau.
  bauelement(1);

  const Seitenrolle(this.nummer);

  /// Nummer im Transportformat.
  final int nummer;

  /// Rolle zur [nummer] aus dem Transportformat.
  static Seitenrolle ausNummer(int nummer) => values.firstWhere(
    (r) => r.nummer == nummer,
    orElse: () => throw FormatException('unbekannte Seitenrolle $nummer'),
  );
}

/// Eine Seite mit Rolle für die Zeichnung: Nummer der Seite, Rolle und die
/// Strecke von Ecke zu Ecke in mm.
typedef Seitenlinie = ({int seite, Seitenrolle rolle, Punkt von, Punkt bis});

/// Was der Server zum Terrassenanschluss der bearbeiteten Fläche rechnet
/// (M7): die Seiten mit Rolle für die Zeichnung (M7-01).
final class Anschlussergebnis {
  Anschlussergebnis({List<Seitenlinie> seiten = const []})
    : seiten = List.unmodifiable(seiten);

  /// Liest die Tabelle am Ort [ort] ([schreibe]).
  factory Anschlussergebnis.lies(fb.BufferContext puffer, int ort) {
    final nummern = const fb.ListReader<int>(fb.Uint16Reader())
        .vTableGet(puffer, ort, _versatz(_seitenPlatz), const []);
    final rollen = const fb.ListReader<int>(fb.Uint8Reader())
        .vTableGet(puffer, ort, _versatz(_rollenPlatz), const []);
    final punkte = const fb.ListReader<double>(fb.Float64Reader())
        .vTableGet(puffer, ort, _versatz(_linienPlatz), const []);
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
    );
  }

  /// Ohne Seiten mit Rolle.
  static final leer = Anschlussergebnis();

  /// Seiten mit Rolle in der Reihenfolge der Seiten.
  final List<Seitenlinie> seiten;

  /// Schreibt die Tabelle `{ 0: seiten ([uint16]), 1: rollen ([uint8]),
  /// 2: linien ([float64] von x, y, bis x, y je Seite) }` und gibt ihren
  /// Ort zurück. Neue Felder nur anhängen.
  int schreibe(fb.Builder fbb) {
    final seitenOrt = fbb.writeListUint16([for (final s in seiten) s.seite]);
    final rollenOrt = fbb.writeListUint8([
      for (final s in seiten) s.rolle.nummer,
    ]);
    final linienOrt = fbb.writeListFloat64([
      for (final s in seiten) ...[s.von.x, s.von.y, s.bis.x, s.bis.y],
    ]);
    fbb
      ..startTable(_linienPlatz + 1)
      ..addOffset(_seitenPlatz, seitenOrt)
      ..addOffset(_rollenPlatz, rollenOrt)
      ..addOffset(_linienPlatz, linienOrt);
    return fbb.endTable();
  }

  static const _seitenPlatz = 0;
  static const _rollenPlatz = 1;
  static const _linienPlatz = 2;
}

int _versatz(int platz) => 4 + 2 * platz;
