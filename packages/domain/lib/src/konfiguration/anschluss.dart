import 'package:flat_buffers/flat_buffers.dart' as fb;

import '../artikel/einheiten.dart';

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

/// Farbe der Entwässerungsrinne RELO V (Planungsregeln Alexander,
/// Planungskern v11, Regel 13.1.5): eloxiert (Vorgabe) oder anthrazit – die
/// Farbe wählt die Artikel von Profil und Auflagerprofilen (`rinnensatz`).
enum Rinnenfarbe {
  /// Aluminium eloxiert, Auflagerprofile blank – Vorgabe.
  eloxiert(0),

  /// Anthrazit (ähnlich RAL 7016).
  anthrazit(1);

  const Rinnenfarbe(this.nummer);

  /// Nummer im Transportformat.
  final int nummer;

  /// Farbe zur [nummer] aus dem Transportformat.
  static Rinnenfarbe ausNummer(int nummer) => values.firstWhere(
    (f) => f.nummer == nummer,
    orElse: () => throw FormatException('unbekannte Rinnenfarbe $nummer'),
  );
}

/// Rinne an einer Seite.
typedef Rinne = ({int seite, Rinnenlage lage});

/// Blendenhöhe einer verblendeten Seite (Planungskern v7, Regel 9.4).
typedef Blendenhoehe = ({int seite, Millimeter hoehe});

/// Ein verblendetes Stück einer Seite (Teilverblendung, Planungskern v7,
/// Regel 9.4): [von] bis [bis] in mm ab der ersten Ecke der Seite.
typedef Blendenteil = ({int seite, Millimeter von, Millimeter bis});

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
/// - **Seitenblende je Seite** (Planungskern v7, Regel 9.4): je verblendeter
///   Seite eine eigene Blendenhöhe und Teilstücke; ohne sie gilt die Höhe
///   der Fläche an der Seite und die ganze Seite.
///
/// Eine Seite hat nur eine Rolle: wer sie in einer Frage wählt, nimmt sie
/// aus den anderen (Fachkonzept 04). Nur die Rinne bleibt an Seiten an
/// Bauelementen wählbar (F38).
final class Anschluss {
  const Anschluss({
    this.angrenzend = const [],
    this.verblendet = const [],
    this.rinnen = const [],
    this.blendenhoehen = const [],
    this.blendenteile = const [],
    this.rinnenfarbe = Rinnenfarbe.eloxiert,
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
    blendenhoehen: _liesHoehen(
      const fb.ListReader<int>(fb.Int32Reader())
          .vTableGet(puffer, ort, _versatz(_blendenhoehenPlatz), const []),
    ),
    blendenteile: _liesTeile(
      const fb.ListReader<int>(fb.Int32Reader())
          .vTableGet(puffer, ort, _versatz(_blendenteilePlatz), const []),
    ),
    rinnenfarbe: Rinnenfarbe.ausNummer(
      const fb.Uint8Reader().vTableGet(
        puffer,
        ort,
        _versatz(_rinnenfarbePlatz),
        0,
      ),
    ),
  );

  static List<Blendenhoehe> _liesHoehen(List<int> werte) => List.unmodifiable([
    for (var i = 0; i < werte.length ~/ 2; i++)
      (seite: werte[2 * i], hoehe: Millimeter(werte[2 * i + 1])),
  ]);

  static List<Blendenteil> _liesTeile(List<int> werte) => List.unmodifiable([
    for (var i = 0; i < werte.length ~/ 3; i++)
      (
        seite: werte[3 * i],
        von: Millimeter(werte[3 * i + 1]),
        bis: Millimeter(werte[3 * i + 2]),
      ),
  ]);

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

  /// Eigene Blendenhöhen verblendeter Seiten, nach Seiten aufsteigend, je
  /// Seite höchstens eine (Regel 9.4).
  final List<Blendenhoehe> blendenhoehen;

  /// Teilstücke verblendeter Seiten nach Seite und Anfang (Regel 9.4);
  /// eine Seite ohne Teilstücke ist ganz verblendet.
  final List<Blendenteil> blendenteile;

  /// Farbe aller Rinnen der Fläche (Planungskern v11, Regel 13.1.5).
  final Rinnenfarbe rinnenfarbe;

  /// Ob gar keine Seite eine Rolle hat.
  bool get leer => angrenzend.isEmpty && verblendet.isEmpty && rinnen.isEmpty;

  /// Ob die Seite [seite] an ein Bauelement grenzt.
  bool grenztAn(int seite) => angrenzend.contains(seite);

  /// Kopie, in der die Seite [seite] an ein Bauelement grenzt ([an]) oder
  /// nicht.
  Anschluss mitAngrenzend(int seite, {required bool an}) => _neu(
    angrenzend: _mitSeite(angrenzend, seite, an: an),
    verblendet: an ? _mitSeite(verblendet, seite, an: false) : verblendet,
    rinnen: rinnen,
  );

  /// Ob die Seite [seite] verblendet ist.
  bool verblendetAn(int seite) => verblendet.contains(seite);

  /// Kopie, in der die Seite [seite] verblendet ist ([an]) oder nicht; sie
  /// grenzt dann nicht mehr an ein Bauelement.
  Anschluss mitVerblendet(int seite, {required bool an}) => _neu(
    angrenzend: an ? _mitSeite(angrenzend, seite, an: false) : angrenzend,
    verblendet: _mitSeite(verblendet, seite, an: an),
    rinnen: an ? _mitRinne(seite, null) : rinnen,
  );

  /// Lage der Rinne an der Seite [seite]; `null` = keine Rinne.
  Rinnenlage? rinneAn(int seite) =>
      rinnen.where((r) => r.seite == seite).firstOrNull?.lage;

  /// Kopie mit einer Rinne in der Lage [lage] an der Seite [seite]
  /// (`null` = ohne Rinne); die Seite ist dann nicht mehr verblendet.
  Anschluss mitRinne(int seite, Rinnenlage? lage) => _neu(
    angrenzend: angrenzend,
    verblendet: lage == null
        ? verblendet
        : _mitSeite(verblendet, seite, an: false),
    rinnen: _mitRinne(seite, lage),
  );

  /// Kopie mit der Rinnenfarbe [farbe] (Planungskern v11, Regel 13.1.5).
  Anschluss mitRinnenfarbe(Rinnenfarbe farbe) => Anschluss(
    angrenzend: angrenzend,
    verblendet: verblendet,
    rinnen: rinnen,
    blendenhoehen: blendenhoehen,
    blendenteile: blendenteile,
    rinnenfarbe: farbe,
  );

  /// Eigene Blendenhöhe der Seite [seite]; `null` = die Höhe der Fläche
  /// an ihrer niedrigsten Stelle (Regel 9.4).
  Millimeter? blendenhoeheAn(int seite) =>
      blendenhoehen.where((h) => h.seite == seite).firstOrNull?.hoehe;

  /// Teilstücke der Seite [seite] (`von`, `bis` ab ihrer ersten Ecke); leer
  /// = die ganze Seite.
  List<({Millimeter von, Millimeter bis})> teileAn(int seite) => [
    for (final t in blendenteile)
      if (t.seite == seite) (von: t.von, bis: t.bis),
  ];

  /// Kopie mit der Blendenhöhe [hoehe] an der verblendeten Seite [seite]
  /// (`null` = automatisch); an einer nicht verblendeten Seite unverändert.
  Anschluss mitBlendenhoehe(int seite, Millimeter? hoehe) => _neu(
    angrenzend: angrenzend,
    verblendet: verblendet,
    rinnen: rinnen,
    blendenhoehen: [
      ...blendenhoehen.where((h) => h.seite != seite),
      if (hoehe != null) (seite: seite, hoehe: hoehe),
    ],
  );

  /// Kopie mit den Teilstücken [teile] an der verblendeten Seite [seite]
  /// (leer = ganze Seite); an einer nicht verblendeten Seite unverändert.
  Anschluss mitBlendenteilen(
    int seite,
    List<({Millimeter von, Millimeter bis})> teile,
  ) => _neu(
    angrenzend: angrenzend,
    verblendet: verblendet,
    rinnen: rinnen,
    blendenteile: [
      ...blendenteile.where((t) => t.seite != seite),
      for (final t in teile) (seite: seite, von: t.von, bis: t.bis),
    ],
  );

  /// Neuer Anschluss; Blendenhöhen und Teilstücke bleiben nur an
  /// verblendeten Seiten, sortiert nach Seite (und Anfang).
  Anschluss _neu({
    required List<int> angrenzend,
    required List<int> verblendet,
    required List<Rinne> rinnen,
    List<Blendenhoehe>? blendenhoehen,
    List<Blendenteil>? blendenteile,
  }) => Anschluss(
    angrenzend: angrenzend,
    verblendet: verblendet,
    rinnen: rinnen,
    blendenhoehen: List<Blendenhoehe>.unmodifiable(
      <Blendenhoehe>[
        for (final h in blendenhoehen ?? this.blendenhoehen)
          if (verblendet.contains(h.seite)) h,
      ]..sort((a, b) => a.seite.compareTo(b.seite)),
    ),
    blendenteile: List<Blendenteil>.unmodifiable(
      <Blendenteil>[
        for (final t in blendenteile ?? this.blendenteile)
          if (verblendet.contains(t.seite)) t,
      ]..sort(_teilfolge),
    ),
    rinnenfarbe: rinnenfarbe,
  );

  static int _teilfolge(Blendenteil a, Blendenteil b) {
    final seite = a.seite.compareTo(b.seite);
    return seite != 0 ? seite : a.von.mm.compareTo(b.von.mm);
  }

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
  /// M7-03), 3: blendenhoehen ([int32] Seite und Höhe in mm, Regel 9.4),
  /// 4: blendenteile ([int32] Seite, von und bis in mm, Regel 9.4),
  /// 5: rinnenfarbe (uint8, Planungskern v11 Regel 13.1.5) }` und gibt
  /// ihren Ort zurück. Neue Felder nur anhängen.
  int schreibe(fb.Builder fbb) {
    final angrenzendOrt = fbb.writeListUint16(angrenzend);
    final verblendetOrt = fbb.writeListUint16(verblendet);
    final rinnenOrt = fbb.writeListUint16(_rinnenwerte);
    final hoehenOrt = blendenhoehen.isEmpty
        ? null
        : fbb.writeListInt32(_hoehenwerte);
    final teileOrt = blendenteile.isEmpty
        ? null
        : fbb.writeListInt32(_teilwerte);
    fbb
      ..startTable(_rinnenfarbePlatz + 1)
      ..addOffset(_angrenzendPlatz, angrenzendOrt)
      ..addOffset(_verblendetPlatz, verblendetOrt)
      ..addOffset(_rinnenPlatz, rinnenOrt)
      ..addOffset(_blendenhoehenPlatz, hoehenOrt)
      ..addOffset(_blendenteilePlatz, teileOrt)
      ..addUint8(_rinnenfarbePlatz, rinnenfarbe.nummer);
    return fbb.endTable();
  }

  List<int> get _rinnenwerte => [
    for (final r in rinnen) ...[r.seite, r.lage.nummer],
  ];

  List<int> get _hoehenwerte => [
    for (final h in blendenhoehen) ...[h.seite, h.hoehe.mm],
  ];

  List<int> get _teilwerte => [
    for (final t in blendenteile) ...[t.seite, t.von.mm, t.bis.mm],
  ];

  static const _angrenzendPlatz = 0;
  static const _verblendetPlatz = 1;
  static const _rinnenPlatz = 2;
  static const _blendenhoehenPlatz = 3;
  static const _blendenteilePlatz = 4;
  static const _rinnenfarbePlatz = 5;

  @override
  bool operator ==(Object other) =>
      other is Anschluss &&
      _gleich(other.angrenzend, angrenzend) &&
      _gleich(other.verblendet, verblendet) &&
      _gleich(other._rinnenwerte, _rinnenwerte) &&
      _gleich(other._hoehenwerte, _hoehenwerte) &&
      _gleich(other._teilwerte, _teilwerte) &&
      other.rinnenfarbe == rinnenfarbe;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(angrenzend),
    Object.hashAll(verblendet),
    Object.hashAll(_rinnenwerte),
    Object.hashAll(_hoehenwerte),
    Object.hashAll(_teilwerte),
    rinnenfarbe,
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
