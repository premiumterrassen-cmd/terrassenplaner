import 'package:flat_buffers/flat_buffers.dart' as fb;

/// Lage einer Entwässerungsrinne (Fachkonzept 4.3, M7-03). Lage und
/// bodentiefes Element sind fest im Artikel verankert: die Lage wählt die
/// Artikelvariante (R-D01).
enum Rinnenlage {
  /// Gesamte Seite (innen) – Vorgabe.
  gesamteSeite(0),

  /// Im bodentiefen Element.
  imElement(1),

  /// Außerhalb des bodentiefen Elements.
  ausserhalbElement(2),

  /// Nur vor dem bodentiefen Element.
  vorElement(3);

  const Rinnenlage(this.nummer);

  /// Nummer im Transportformat.
  final int nummer;

  /// Lage zur [nummer] aus dem Transportformat.
  static Rinnenlage ausNummer(int nummer) => values.firstWhere(
    (l) => l.nummer == nummer,
    orElse: () => throw FormatException('unbekannte Rinnenlage $nummer'),
  );
}

/// Rinne an einer Seite.
typedef Rinne = ({int seite, Rinnenlage lage});

/// Eingaben zum Terrassenanschluss einer Fläche (Fachkonzept 04, M7): je
/// Seite eine Rolle. Seite `i` läuft von Ecke `i` zur nächsten Ecke (A — B
/// ist Seite 0), wie die Beschriftung der Zeichnung.
///
/// - **Angrenzende Seiten** (M7-01, 4.1): Seiten, die an bestehende
///   Bauelemente grenzen; sie werden grau dargestellt und stehen nicht
///   mehr für andere Rollen zur Wahl.
/// - **Verblendete Seiten** (M7-02, 4.2): gelb dargestellt; beim Kreis
///   steht Seite 0 für „Fläche verblenden“.
/// - **Rinnen** (M7-03, 4.3): je Seite eine Entwässerungsrinne mit Lage.
///
/// Eine Seite hat nur eine Rolle: wer sie in einer Frage wählt, nimmt sie
/// aus den anderen (Fachkonzept 04). Nur die Rinne bleibt an Seiten an
/// Bauelementen wählbar (F38).
final class Anschluss {
  const Anschluss({
    this.angrenzend = const [],
    this.verblendet = const [],
    this.rinnen = const [],
  });

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
    rinnen: _liesRinnen(
      const fb.ListReader<int>(fb.Uint16Reader())
          .vTableGet(puffer, ort, _versatz(_rinnenPlatz), const []),
    ),
  );

  static List<Rinne> _liesRinnen(List<int> werte) => List.unmodifiable([
    for (var i = 0; i < werte.length ~/ 2; i++)
      (seite: werte[2 * i], lage: Rinnenlage.ausNummer(werte[2 * i + 1])),
  ]);

  /// Ohne Rollen (Vorgabe, F01).
  static const keiner = Anschluss();

  /// Seiten, die an Bauelemente grenzen – aufsteigend, ohne doppelte.
  final List<int> angrenzend;

  /// Verblendete Seiten – aufsteigend, ohne doppelte.
  final List<int> verblendet;

  /// Rinnen nach Seiten aufsteigend, je Seite höchstens eine.
  final List<Rinne> rinnen;

  /// Ob gar keine Seite eine Rolle hat.
  bool get leer => angrenzend.isEmpty && verblendet.isEmpty && rinnen.isEmpty;

  /// Ob die Seite [seite] an ein Bauelement grenzt.
  bool grenztAn(int seite) => angrenzend.contains(seite);

  /// Kopie, in der die Seite [seite] an ein Bauelement grenzt ([an]) oder
  /// nicht.
  Anschluss mitAngrenzend(int seite, {required bool an}) => Anschluss(
    angrenzend: _mitSeite(angrenzend, seite, an: an),
    verblendet: an ? _mitSeite(verblendet, seite, an: false) : verblendet,
    rinnen: rinnen,
  );

  /// Ob die Seite [seite] verblendet ist.
  bool verblendetAn(int seite) => verblendet.contains(seite);

  /// Kopie, in der die Seite [seite] verblendet ist ([an]) oder nicht; sie
  /// grenzt dann nicht mehr an ein Bauelement.
  Anschluss mitVerblendet(int seite, {required bool an}) => Anschluss(
    angrenzend: an ? _mitSeite(angrenzend, seite, an: false) : angrenzend,
    verblendet: _mitSeite(verblendet, seite, an: an),
    rinnen: an ? _mitRinne(seite, null) : rinnen,
  );

  /// Lage der Rinne an der Seite [seite]; `null` = keine Rinne.
  Rinnenlage? rinneAn(int seite) =>
      rinnen.where((r) => r.seite == seite).firstOrNull?.lage;

  /// Kopie mit einer Rinne in der Lage [lage] an der Seite [seite]
  /// (`null` = ohne Rinne); die Seite ist dann nicht mehr verblendet.
  Anschluss mitRinne(int seite, Rinnenlage? lage) => Anschluss(
    angrenzend: angrenzend,
    verblendet: lage == null
        ? verblendet
        : _mitSeite(verblendet, seite, an: false),
    rinnen: _mitRinne(seite, lage),
  );

  List<Rinne> _mitRinne(int seite, Rinnenlage? lage) => List.unmodifiable(
    <Rinne>[
      ...rinnen.where((r) => r.seite != seite),
      if (lage != null) (seite: seite, lage: lage),
    ]..sort((a, b) => a.seite.compareTo(b.seite)),
  );

  /// [seiten] mit oder ohne [seite], aufsteigend.
  static List<int> _mitSeite(List<int> seiten, int seite, {required bool an}) =>
      List.unmodifiable(
        {...seiten.where((s) => s != seite), if (an) seite}.toList()..sort(),
      );

  /// Schreibt die Tabelle `{ 0: angrenzend ([uint16] Seiten), 1: verblendet
  /// ([uint16] Seiten, M7-02), 2: rinnen ([uint16] Seite und Lage je Rinne,
  /// M7-03) }` und gibt ihren Ort zurück. Neue Felder nur anhängen.
  int schreibe(fb.Builder fbb) {
    final angrenzendOrt = fbb.writeListUint16(angrenzend);
    final verblendetOrt = fbb.writeListUint16(verblendet);
    final rinnenOrt = fbb.writeListUint16(_rinnenwerte);
    fbb
      ..startTable(_rinnenPlatz + 1)
      ..addOffset(_angrenzendPlatz, angrenzendOrt)
      ..addOffset(_verblendetPlatz, verblendetOrt)
      ..addOffset(_rinnenPlatz, rinnenOrt);
    return fbb.endTable();
  }

  List<int> get _rinnenwerte => [
    for (final r in rinnen) ...[r.seite, r.lage.nummer],
  ];

  static const _angrenzendPlatz = 0;
  static const _verblendetPlatz = 1;
  static const _rinnenPlatz = 2;

  @override
  bool operator ==(Object other) =>
      other is Anschluss &&
      _gleich(other.angrenzend, angrenzend) &&
      _gleich(other.verblendet, verblendet) &&
      _gleich(other._rinnenwerte, _rinnenwerte);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(angrenzend),
    Object.hashAll(verblendet),
    Object.hashAll(_rinnenwerte),
  );
}

bool _gleich(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

int _versatz(int platz) => 4 + 2 * platz;
