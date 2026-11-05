/// Zuschnittplan (M9-02, Fachkonzept 08): je Artikel die Ausgangslänge, wie
/// viele Lieferstücke so geschnitten werden (Menge) und die Schnittmaße –
/// für Belag und Unterkonstruktion wie in den Planungsunterlagen des alten
/// Planers („Zuschnitt Deckbelag“, „Zuschnitt Unterkonstruktion“).
library;

import 'package:flat_buffers/flat_buffers.dart' as fb;

import '../artikel/artikel.dart';
import '../artikel/einheiten.dart';
import '../konfiguration/belagverlegung.dart';

/// Ein Lieferstück eines Artikels, [anzahl]-mal (Häufigkeit der Fläche).
typedef Lieferzuschnitt = ({Artikel artikel, Lieferdiele stueck, int anzahl});

/// Zeile des Zuschnittplans: aus [menge] Stücken der [ausgangslaenge] werden
/// je die [schnitte] gesägt (längste zuerst).
final class Zuschnittzeile {
  Zuschnittzeile({
    required this.nummer,
    required this.titel,
    required this.ausgangslaenge,
    required this.menge,
    required List<Millimeter> schnitte,
  }) : schnitte = List.unmodifiable(schnitte);

  final Artikelnummer nummer;
  final String titel;
  final Millimeter ausgangslaenge;
  final int menge;
  final List<Millimeter> schnitte;

  @override
  bool operator ==(Object other) =>
      other is Zuschnittzeile &&
      other.nummer == nummer &&
      other.titel == titel &&
      other.ausgangslaenge == ausgangslaenge &&
      other.menge == menge &&
      _gleich(other.schnitte, schnitte);

  @override
  int get hashCode => Object.hash(
    nummer,
    titel,
    ausgangslaenge,
    menge,
    Object.hashAll(schnitte),
  );

  @override
  String toString() =>
      '$menge × ${ausgangslaenge.mm}: '
      '${[for (final s in schnitte) s.mm].join(' + ')} ($nummer)';
}

bool _gleich(List<Millimeter> a, List<Millimeter> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Zuschnittplan eines Bereichs (Belag oder Unterkonstruktion, M9-02).
final class Zuschnittplan {
  Zuschnittplan(List<Zuschnittzeile> zeilen)
    : zeilen = List.unmodifiable(zeilen);

  /// Fasst gleich geschnittene Lieferstücke zusammen (Artikel, Ausgangslänge
  /// und Schnitte): Artikel in der Reihenfolge ihres ersten Stücks, darin
  /// die längste Ausgangslänge zuerst, dann die größte Menge – wie in den
  /// Planungsunterlagen (F09: 48 × 600 cm ungeschnitten, 24 × 400 cm in
  /// 2 × 200 cm).
  factory Zuschnittplan.aus(Iterable<Lieferzuschnitt> stuecke) {
    final artikel = <Artikelnummer, int>{};
    final zeilen = <String, Lieferzuschnitt>{};
    for (final z in stuecke) {
      final d = z.stueck;
      final schluessel =
          '${z.artikel.nummer.wert}|${d.laenge.mm}|'
          '${[for (final s in d.schnitte) s.mm].join(',')}';
      artikel.putIfAbsent(z.artikel.nummer, () => artikel.length);
      zeilen.update(
        schluessel,
        (alt) => (
          artikel: alt.artikel,
          stueck: alt.stueck,
          anzahl: alt.anzahl + z.anzahl,
        ),
        ifAbsent: () => z,
      );
    }
    final liste = [...zeilen.values];
    final reihenfolge = [for (var i = 0; i < liste.length; i++) i]
      ..sort((a, b) {
        final (x, y) = (liste[a], liste[b]);
        final art = artikel[x.artikel.nummer]! - artikel[y.artikel.nummer]!;
        if (art != 0) return art;
        final laenge = y.stueck.laenge.mm - x.stueck.laenge.mm;
        if (laenge != 0) return laenge;
        final menge = y.anzahl - x.anzahl;
        return menge != 0 ? menge : a - b;
      });
    return Zuschnittplan([
      for (final i in reihenfolge)
        Zuschnittzeile(
          nummer: liste[i].artikel.nummer,
          titel: liste[i].artikel.titel,
          ausgangslaenge: liste[i].stueck.laenge,
          menge: liste[i].anzahl,
          schnitte: liste[i].stueck.schnitte,
        ),
    ]);
  }

  /// Liest den Plan aus einem Puffer an [ort] ([schreibe]).
  factory Zuschnittplan.lies(fb.BufferContext puffer, int ort) => Zuschnittplan(
    [
      for (final z in const fb.ListReader<int>(
        _Tabellenort(),
      ).vTableGet(puffer, ort, _versatz(0), const []))
        Zuschnittzeile(
          nummer: Artikelnummer(
            const fb.StringReader().vTableGet(puffer, z, _versatz(0), ''),
          ),
          titel: const fb.StringReader().vTableGet(puffer, z, _versatz(1), ''),
          ausgangslaenge: Millimeter(
            const fb.Int32Reader().vTableGet(puffer, z, _versatz(2), 0),
          ),
          menge: const fb.Uint32Reader().vTableGet(puffer, z, _versatz(3), 0),
          schnitte: [
            for (final s in const fb.ListReader<int>(
              fb.Int32Reader(),
            ).vTableGet(puffer, z, _versatz(4), const []))
              Millimeter(s),
          ],
        ),
    ],
  );

  static final leer = Zuschnittplan(const []);

  final List<Zuschnittzeile> zeilen;

  bool get istLeer => zeilen.isEmpty;

  /// Schreibt `{ 0: zeilen ([{ 0: nummer (string), 1: titel (string),
  /// 2: ausgangslaenge (int32 mm), 3: menge (uint32), 4: schnitte ([int32]
  /// mm) }]) }` und gibt den Ort zurück.
  int schreibe(fb.Builder fbb) {
    final orte = fbb.writeList([for (final z in zeilen) _zeile(fbb, z)]);
    fbb
      ..startTable(1)
      ..addOffset(0, orte);
    return fbb.endTable();
  }

  static int _zeile(fb.Builder fbb, Zuschnittzeile z) {
    final nummerOrt = fbb.writeString(z.nummer.wert);
    final titelOrt = fbb.writeString(z.titel);
    final schnitteOrt = fbb.writeListInt32([for (final s in z.schnitte) s.mm]);
    fbb
      ..startTable(5)
      ..addOffset(0, nummerOrt)
      ..addOffset(1, titelOrt)
      ..addInt32(2, z.ausgangslaenge.mm)
      ..addUint32(3, z.menge)
      ..addOffset(4, schnitteOrt);
    return fbb.endTable();
  }

  @override
  bool operator ==(Object other) {
    if (other is! Zuschnittplan || other.zeilen.length != zeilen.length) {
      return false;
    }
    for (var i = 0; i < zeilen.length; i++) {
      if (other.zeilen[i] != zeilen[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(zeilen);
}

int _versatz(int platz) => 4 + 2 * platz;

/// Liest nur den Ort einer Tabelle – die Felder liest der Aufrufer.
final class _Tabellenort extends fb.TableReader<int> {
  const _Tabellenort();

  @override
  int createObject(fb.BufferContext puffer, int ort) => ort;
}
