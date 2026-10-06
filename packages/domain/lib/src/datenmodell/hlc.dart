/// Hybrid Logical Clock: Zeitstempel, der über Knoten hinweg eine eindeutige,
/// mit der Uhrzeit verträgliche Reihenfolge ergibt (Grundlage für die spätere
/// Verteilung, docs/architektur/datenmodell.md).
///
/// Textform `MMMMMMMMMMMMM-ZZZZ-knoten` (Millisekunden 13-stellig, Zähler
/// 4-stellig, beide mit führenden Nullen) – lexikografisch sortierbar.
class Hlc implements Comparable<Hlc> {
  const Hlc(this.millis, this.zaehler, this.knoten);

  factory Hlc.ausText(String text) {
    final teile = text.split('-');
    if (teile.length < 3) throw FormatException('Ungültiger HLC', text);
    return Hlc(
      int.parse(teile[0]),
      int.parse(teile[1]),
      teile.sublist(2).join('-'),
    );
  }

  final int millis;
  final int zaehler;
  final String knoten;

  @override
  int compareTo(Hlc andere) {
    final m = millis.compareTo(andere.millis);
    if (m != 0) return m;
    final z = zaehler.compareTo(andere.zaehler);
    return z != 0 ? z : knoten.compareTo(andere.knoten);
  }

  @override
  bool operator ==(Object other) => other is Hlc && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(millis, zaehler, knoten);

  @override
  String toString() =>
      '${millis.toString().padLeft(13, '0')}-${zaehler.toString().padLeft(4, '0')}-$knoten';
}

/// Uhr eines Knotens, die monoton steigende [Hlc] liefert.
class HlcUhr {
  HlcUhr(this.knoten, {DateTime Function()? uhr}) : _uhr = uhr ?? DateTime.now;

  final String knoten;
  final DateTime Function() _uhr;
  Hlc? _letzter;

  /// Zeitstempel für ein lokales Ereignis.
  Hlc jetzt() {
    final physisch = _uhr().millisecondsSinceEpoch;
    final letzter = _letzter;
    final neu = letzter == null || physisch > letzter.millis
        ? Hlc(physisch, 0, knoten)
        : Hlc(letzter.millis, letzter.zaehler + 1, knoten);
    return _letzter = neu;
  }

  /// Zeitstempel nach Empfang eines Ereignisses mit [fremd] von einem anderen
  /// Knoten – liegt sicher nach beiden.
  Hlc empfange(Hlc fremd) {
    final physisch = _uhr().millisecondsSinceEpoch;
    final letzter = _letzter ?? Hlc(0, 0, knoten);
    final millis = [
      physisch,
      letzter.millis,
      fremd.millis,
    ].reduce((a, b) => a > b ? a : b);
    final int zaehler;
    if (millis == letzter.millis && millis == fremd.millis) {
      zaehler =
          (letzter.zaehler > fremd.zaehler ? letzter.zaehler : fremd.zaehler) +
          1;
    } else if (millis == letzter.millis) {
      zaehler = letzter.zaehler + 1;
    } else if (millis == fremd.millis) {
      zaehler = fremd.zaehler + 1;
    } else {
      zaehler = 0;
    }
    return _letzter = Hlc(millis, zaehler, knoten);
  }
}
