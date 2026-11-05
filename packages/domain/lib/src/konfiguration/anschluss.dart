import 'package:flat_buffers/flat_buffers.dart' as fb;

/// Eingaben zum Terrassenanschluss einer Fläche (Fachkonzept 04, M7): je
/// Seite eine Rolle. Seite `i` läuft von Ecke `i` zur nächsten Ecke (A — B
/// ist Seite 0), wie die Beschriftung der Zeichnung.
///
/// - **Angrenzende Seiten** (M7-01, 4.1): Seiten, die an bestehende
///   Bauelemente grenzen; sie werden grau dargestellt und stehen nicht
///   mehr für andere Rollen zur Wahl.
final class Anschluss {
  const Anschluss({this.angrenzend = const []});

  /// Liest die Tabelle am Ort [ort] ([schreibe]).
  factory Anschluss.lies(fb.BufferContext puffer, int ort) => Anschluss(
    angrenzend: List.unmodifiable(
      const fb.ListReader<int>(fb.Uint16Reader())
          .vTableGet(puffer, ort, _versatz(_angrenzendPlatz), const []),
    ),
  );

  /// Ohne Rollen (Vorgabe, F01).
  static const keiner = Anschluss();

  /// Seiten, die an Bauelemente grenzen – aufsteigend, ohne doppelte.
  final List<int> angrenzend;

  /// Ob gar keine Seite eine Rolle hat.
  bool get leer => angrenzend.isEmpty;

  /// Ob die Seite [seite] an ein Bauelement grenzt.
  bool grenztAn(int seite) => angrenzend.contains(seite);

  /// Kopie, in der die Seite [seite] an ein Bauelement grenzt ([an]) oder
  /// nicht.
  Anschluss mitAngrenzend(int seite, {required bool an}) =>
      Anschluss(angrenzend: _mitSeite(angrenzend, seite, an: an));

  /// [seiten] mit oder ohne [seite], aufsteigend.
  static List<int> _mitSeite(List<int> seiten, int seite, {required bool an}) =>
      List.unmodifiable(
        {...seiten.where((s) => s != seite), if (an) seite}.toList()..sort(),
      );

  /// Schreibt die Tabelle `{ 0: angrenzend ([uint16] Seiten) }` und gibt
  /// ihren Ort zurück. Neue Felder nur anhängen.
  int schreibe(fb.Builder fbb) {
    final angrenzendOrt = fbb.writeListUint16(angrenzend);
    fbb
      ..startTable(_angrenzendPlatz + 1)
      ..addOffset(_angrenzendPlatz, angrenzendOrt);
    return fbb.endTable();
  }

  static const _angrenzendPlatz = 0;

  @override
  bool operator ==(Object other) =>
      other is Anschluss && _gleich(other.angrenzend, angrenzend);

  @override
  int get hashCode => Object.hashAll(angrenzend);
}

bool _gleich(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

int _versatz(int platz) => 4 + 2 * platz;
