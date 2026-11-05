import 'package:flat_buffers/flat_buffers.dart' as fb;

/// Eingaben zum Terrassenanschluss einer Fläche (Fachkonzept 04, M7): je
/// Seite eine Rolle. Seite `i` läuft von Ecke `i` zur nächsten Ecke (A — B
/// ist Seite 0), wie die Beschriftung der Zeichnung.
///
/// - **Angrenzende Seiten** (M7-01, 4.1): Seiten, die an bestehende
///   Bauelemente grenzen; sie werden grau dargestellt und stehen nicht
///   mehr für andere Rollen zur Wahl.
/// - **Verblendete Seiten** (M7-02, 4.2): gelb dargestellt; beim Kreis
///   steht Seite 0 für „Fläche verblenden“.
///
/// Eine Seite hat nur eine Rolle: wer sie in einer Frage wählt, nimmt sie
/// aus den anderen (Fachkonzept 04).
final class Anschluss {
  const Anschluss({this.angrenzend = const [], this.verblendet = const []});

  /// Liest die Tabelle am Ort [ort] ([schreibe]).
  factory Anschluss.lies(fb.BufferContext puffer, int ort) => Anschluss(
    angrenzend: List.unmodifiable(
      const fb.ListReader<int>(fb.Uint16Reader())
          .vTableGet(puffer, ort, _versatz(_angrenzendPlatz), const []),
    ),
    verblendet: List.unmodifiable(
      const fb.ListReader<int>(fb.Uint16Reader())
          .vTableGet(puffer, ort, _versatz(_verblendetPlatz), const []),
    ),
  );

  /// Ohne Rollen (Vorgabe, F01).
  static const keiner = Anschluss();

  /// Seiten, die an Bauelemente grenzen – aufsteigend, ohne doppelte.
  final List<int> angrenzend;

  /// Verblendete Seiten – aufsteigend, ohne doppelte.
  final List<int> verblendet;

  /// Ob gar keine Seite eine Rolle hat.
  bool get leer => angrenzend.isEmpty && verblendet.isEmpty;

  /// Ob die Seite [seite] an ein Bauelement grenzt.
  bool grenztAn(int seite) => angrenzend.contains(seite);

  /// Kopie, in der die Seite [seite] an ein Bauelement grenzt ([an]) oder
  /// nicht.
  Anschluss mitAngrenzend(int seite, {required bool an}) => Anschluss(
    angrenzend: _mitSeite(angrenzend, seite, an: an),
    verblendet: an ? _mitSeite(verblendet, seite, an: false) : verblendet,
  );

  /// Ob die Seite [seite] verblendet ist.
  bool verblendetAn(int seite) => verblendet.contains(seite);

  /// Kopie, in der die Seite [seite] verblendet ist ([an]) oder nicht; sie
  /// grenzt dann nicht mehr an ein Bauelement.
  Anschluss mitVerblendet(int seite, {required bool an}) => Anschluss(
    angrenzend: an ? _mitSeite(angrenzend, seite, an: false) : angrenzend,
    verblendet: _mitSeite(verblendet, seite, an: an),
  );

  /// [seiten] mit oder ohne [seite], aufsteigend.
  static List<int> _mitSeite(List<int> seiten, int seite, {required bool an}) =>
      List.unmodifiable(
        {...seiten.where((s) => s != seite), if (an) seite}.toList()..sort(),
      );

  /// Schreibt die Tabelle `{ 0: angrenzend ([uint16] Seiten), 1: verblendet
  /// ([uint16] Seiten, M7-02) }` und gibt ihren Ort zurück. Neue Felder nur
  /// anhängen.
  int schreibe(fb.Builder fbb) {
    final angrenzendOrt = fbb.writeListUint16(angrenzend);
    final verblendetOrt = fbb.writeListUint16(verblendet);
    fbb
      ..startTable(_verblendetPlatz + 1)
      ..addOffset(_angrenzendPlatz, angrenzendOrt)
      ..addOffset(_verblendetPlatz, verblendetOrt);
    return fbb.endTable();
  }

  static const _angrenzendPlatz = 0;
  static const _verblendetPlatz = 1;

  @override
  bool operator ==(Object other) =>
      other is Anschluss &&
      _gleich(other.angrenzend, angrenzend) &&
      _gleich(other.verblendet, verblendet);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(angrenzend), Object.hashAll(verblendet));
}

bool _gleich(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

int _versatz(int platz) => 4 + 2 * platz;
