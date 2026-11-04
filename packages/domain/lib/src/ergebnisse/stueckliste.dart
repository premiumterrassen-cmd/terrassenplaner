/// Stückliste des Plans (M9-04, Fachkonzept 08): je Artikel und Länge die
/// Anzahl der Stücke und ihre Farbe – dieselbe Farbe trägt jedes Stück in
/// der Zeichnung, so lässt sich jede Zeile im Plan wiederfinden.
///
/// Farben wie in den Planungsunterlagen des alten Planers (UK-Stückliste der
/// Referenzfälle, M1-02): **rot** ein Stück in ganzer Lieferlänge
/// (ungeschnitten), **blau** ein zugeschnittenes Längsstück, **grün** ein
/// Querstück (z. B. zwischen den UK-Hölzern). Quellen liefern ihre Stücke
/// als [Planstueck]: heute der Belag (M5-08), mit M6 die Unterkonstruktion.
library;

import 'package:flat_buffers/flat_buffers.dart' as fb;

import '../artikel/artikel.dart';
import '../artikel/einheiten.dart';

/// Farbe eines Stücks in Stückliste und Zeichnung (M9-04).
enum Stueckfarbe {
  /// Ganze Lieferlänge, ungeschnitten.
  rot(0, 0xFFD32F2F),

  /// Zugeschnittenes Längsstück.
  blau(1, 0xFF1976D2),

  /// Querstück.
  gruen(2, 0xFF388E3C);

  const Stueckfarbe(this.nummer, this.argb);

  /// Kennung im Transportformat.
  final int nummer;

  /// Farbwert (ARGB) für Zeichnung und PDF – eine Quelle für beide.
  final int argb;

  /// Farbe zur [nummer]; unbekannte Nummern sind ein Formatfehler.
  static Stueckfarbe ausNummer(int nummer) => values.firstWhere(
    (f) => f.nummer == nummer,
    orElse: () => throw FormatException('unbekannte Stückfarbe: $nummer'),
  );
}

/// Lage eines Stücks im Plan.
enum Stuecklage {
  /// In Hauptrichtung (Dielen, UK-Hölzer).
  laengs,

  /// Quer dazu (Querstücke, Leiterverband).
  quer,
}

/// Ein Stück des Plans (M9-04): Artikel, zugeschnittene [laenge], [lage]
/// und die ganze Länge, ab der es nicht geschnitten ist ([ganzeLaenge],
/// die längste Lieferlänge, in der verlegt wird).
final class Planstueck {
  const Planstueck(
    this.nummer,
    this.titel,
    this.laenge, {
    required this.ganzeLaenge,
    this.lage = Stuecklage.laengs,
  });

  final Artikelnummer nummer;
  final String titel;
  final Millimeter laenge;
  final Millimeter ganzeLaenge;
  final Stuecklage lage;

  /// Querstücke grün; Längsstücke rot in ganzer Länge, sonst blau.
  Stueckfarbe get farbe => switch (lage) {
    Stuecklage.quer => Stueckfarbe.gruen,
    Stuecklage.laengs when laenge >= ganzeLaenge => Stueckfarbe.rot,
    Stuecklage.laengs => Stueckfarbe.blau,
  };
}

/// Zeile der Stückliste: Artikel, Länge, Anzahl und Farbe.
final class Stuecklistenzeile {
  const Stuecklistenzeile({
    required this.nummer,
    required this.titel,
    required this.laenge,
    required this.stueck,
    required this.farbe,
  });

  final Artikelnummer nummer;
  final String titel;
  final Millimeter laenge;
  final int stueck;
  final Stueckfarbe farbe;

  @override
  bool operator ==(Object other) =>
      other is Stuecklistenzeile &&
      other.nummer == nummer &&
      other.titel == titel &&
      other.laenge == laenge &&
      other.stueck == stueck &&
      other.farbe == farbe;

  @override
  int get hashCode => Object.hash(nummer, titel, laenge, stueck, farbe);

  @override
  String toString() => '$stueck × ${laenge.mm} mm $nummer (${farbe.name})';
}

/// Stückliste des Plans (M9-04): gleiche Artikel, Länge und Farbe ergeben
/// eine Zeile.
final class Stueckliste {
  Stueckliste(List<Stuecklistenzeile> zeilen)
    : zeilen = List.unmodifiable(zeilen);

  /// Zählt die [stuecke]: Artikel in der Reihenfolge ihres ersten Stücks,
  /// je Artikel rot, blau, grün und darin die längsten zuerst – wie in den
  /// Planungsunterlagen (200 rot, 87 blau, 36/35/33 grün).
  factory Stueckliste.aus(Iterable<Planstueck> stuecke) {
    final artikel = <Artikelnummer, int>{};
    final anzahl = <(Artikelnummer, int, Stueckfarbe), int>{};
    final titel = <Artikelnummer, String>{};
    for (final s in stuecke) {
      artikel.putIfAbsent(s.nummer, () => artikel.length);
      titel.putIfAbsent(s.nummer, () => s.titel);
      anzahl.update(
        (s.nummer, s.laenge.mm, s.farbe),
        (n) => n + 1,
        ifAbsent: () => 1,
      );
    }
    final schluessel = anzahl.keys.toList()
      ..sort((a, b) {
        final art = artikel[a.$1]!.compareTo(artikel[b.$1]!);
        if (art != 0) return art;
        final farbe = a.$3.index.compareTo(b.$3.index);
        if (farbe != 0) return farbe;
        return b.$2.compareTo(a.$2);
      });
    return Stueckliste([
      for (final s in schluessel)
        Stuecklistenzeile(
          nummer: s.$1,
          titel: titel[s.$1]!,
          laenge: Millimeter(s.$2),
          stueck: anzahl[s]!,
          farbe: s.$3,
        ),
    ]);
  }

  /// Liest die Stückliste aus einem Puffer an [ort] ([schreibe]).
  factory Stueckliste.lies(fb.BufferContext puffer, int ort) => Stueckliste([
    for (final z in const fb.ListReader<int>(
      _Tabellenort(),
    ).vTableGet(puffer, ort, _versatz(0), const []))
      Stuecklistenzeile(
        nummer: Artikelnummer(
          const fb.StringReader().vTableGet(puffer, z, _versatz(0), ''),
        ),
        titel: const fb.StringReader().vTableGet(puffer, z, _versatz(1), ''),
        laenge: Millimeter(
          const fb.Int32Reader().vTableGet(puffer, z, _versatz(2), 0),
        ),
        stueck: const fb.Uint32Reader().vTableGet(puffer, z, _versatz(3), 0),
        farbe: Stueckfarbe.ausNummer(
          const fb.Uint8Reader().vTableGet(puffer, z, _versatz(4), 0),
        ),
      ),
  ]);

  static final leer = Stueckliste(const []);

  final List<Stuecklistenzeile> zeilen;

  bool get istLeer => zeilen.isEmpty;

  /// Schreibt `{ 0: zeilen ([{ 0: nummer (string), 1: titel (string), 2:
  /// laenge (int32 mm), 3: stueck (uint32), 4: farbe (uint8) }]) }` und gibt
  /// den Ort zurück.
  int schreibe(fb.Builder fbb) {
    final orte = fbb.writeList([for (final z in zeilen) _zeile(fbb, z)]);
    fbb
      ..startTable(1)
      ..addOffset(0, orte);
    return fbb.endTable();
  }

  static int _zeile(fb.Builder fbb, Stuecklistenzeile z) {
    final nummerOrt = fbb.writeString(z.nummer.wert);
    final titelOrt = fbb.writeString(z.titel);
    fbb
      ..startTable(5)
      ..addOffset(0, nummerOrt)
      ..addOffset(1, titelOrt)
      ..addInt32(2, z.laenge.mm)
      ..addUint32(3, z.stueck)
      ..addUint8(4, z.farbe.nummer);
    return fbb.endTable();
  }

  @override
  bool operator ==(Object other) {
    if (other is! Stueckliste || other.zeilen.length != zeilen.length) {
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
