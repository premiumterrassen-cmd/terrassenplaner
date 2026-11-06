import 'package:flat_buffers/flat_buffers.dart' as fb;

import '../artikel/einheiten.dart';

/// Art der Treppe (Fachkonzept 5.1, M7-05).
enum Treppenart {
  /// Gerade Stufen vor der Seite (Vorgabe).
  regulaer(0),

  /// Fächertreppe: Podest mit Stufen nach vorn und zu einer Seite.
  zweiteilig(1),

  /// Fächertreppe: Podest mit Stufen nach vorn und zu beiden Seiten.
  dreiteilig(2);

  const Treppenart(this.nummer);

  /// Nummer im Transportformat.
  final int nummer;

  /// Ob die Treppe ein Podest hat (Fächertreppe).
  bool get mitPodest => this != regulaer;

  /// Art zur [nummer] aus dem Transportformat.
  static Treppenart ausNummer(int nummer) => values.firstWhere(
    (a) => a.nummer == nummer,
    orElse: () => throw FormatException('unbekannte Treppenart $nummer'),
  );
}

/// Konstruktionsart der Treppe (Fachkonzept 5.1, R-D02).
enum Treppenbau {
  /// Der Planer erstellt und berechnet die Treppe konstruktiv (Vorgabe).
  konstruktion(0),

  /// Eine Betontreppe ist vorhanden und wird nur belegt.
  fundament(1);

  const Treppenbau(this.nummer);

  /// Nummer im Transportformat.
  final int nummer;

  /// Konstruktionsart zur [nummer] aus dem Transportformat.
  static Treppenbau ausNummer(int nummer) => values.firstWhere(
    (b) => b.nummer == nummer,
    orElse: () => throw FormatException('unbekannte Konstruktionsart $nummer'),
  );
}

/// Maße einer Stufe: Auftrittstiefe und Höhe.
typedef Stufenmass = ({Millimeter tiefe, Millimeter hoehe});

/// Maße des Podests einer Fächertreppe: [tiefe] längs der Seite, [breite]
/// nach außen, [hoehe] über der obersten Stufe.
typedef Podestmass = ({Millimeter tiefe, Millimeter breite, Millimeter hoehe});

/// Maße der ganzen Treppe wie „Treppenmaße in cm (L x B x H)“: [laenge]
/// längs der Seite, [breite] nach außen, [hoehe].
typedef Treppenmasse = ({
  Millimeter laenge,
  Millimeter breite,
  Millimeter hoehe,
});

/// Eine Treppe an einer Seite (M7-05, Fachkonzept 5.1). Seite `i` läuft
/// von Ecke `i` zur nächsten; die Treppe beginnt [abstand] nach der Ecke.
/// Ihre Höhe hängt nicht an der Terrassenhöhe (R-D03).
final class Treppe {
  const Treppe({
    this.seite = 0,
    this.abstand = const Millimeter(0),
    this.breite = vorgabeBreite,
    this.bau = Treppenbau.konstruktion,
    this.art = Treppenart.regulaer,
    this.individuell = false,
    this.anzahl = vorgabeAnzahl,
    this.stufe = vorgabeStufe,
    this.stufen = const [],
    this.podest = vorgabePodest,
  });

  /// Liest die Tabelle am Ort [ort] ([schreibe]).
  factory Treppe.lies(fb.BufferContext puffer, int ort) {
    int zahl(int platz, int vorgabe) =>
        const fb.Int32Reader().vTableGet(puffer, ort, _versatz(platz), vorgabe);
    Millimeter mm(int platz, Millimeter vorgabe) =>
        Millimeter(zahl(platz, vorgabe.mm));
    final einzeln = const fb.ListReader<int>(fb.Int32Reader())
        .vTableGet(puffer, ort, _versatz(_stufenPlatz), const []);
    return Treppe(
      seite: zahl(_seitePlatz, 0),
      abstand: mm(_abstandPlatz, const Millimeter(0)),
      breite: mm(_breitePlatz, vorgabeBreite),
      bau: Treppenbau.ausNummer(zahl(_bauPlatz, 0)),
      art: Treppenart.ausNummer(zahl(_artPlatz, 0)),
      individuell: const fb.BoolReader().vTableGet(
        puffer,
        ort,
        _versatz(_individuellPlatz),
        false,
      ),
      anzahl: zahl(_anzahlPlatz, vorgabeAnzahl),
      stufe: (
        tiefe: mm(_tiefePlatz, vorgabeStufe.tiefe),
        hoehe: mm(_hoehePlatz, vorgabeStufe.hoehe),
      ),
      stufen: List.unmodifiable([
        for (var i = 0; i < einzeln.length ~/ 2; i++)
          (
            tiefe: Millimeter(einzeln[2 * i]),
            hoehe: Millimeter(einzeln[2 * i + 1]),
          ),
      ]),
      podest: (
        tiefe: mm(_podestTiefePlatz, vorgabePodest.tiefe),
        breite: mm(_podestBreitePlatz, vorgabePodest.breite),
        hoehe: mm(_podestHoehePlatz, vorgabePodest.hoehe),
      ),
    );
  }

  /// Breite der regulären Treppe (Fachkonzept 5.1): 100 cm.
  static const vorgabeBreite = Millimeter(1000);

  /// Anzahl der Stufen: 2.
  static const vorgabeAnzahl = 2;

  /// Stufenmaß: Tiefe 27 cm, Höhe 15,6 cm.
  static const vorgabeStufe = (tiefe: Millimeter(270), hoehe: Millimeter(156));

  /// Podest der Fächertreppe (F41): Tiefe 50, Breite 54, Höhe 15,6 cm.
  static const vorgabePodest = (
    tiefe: Millimeter(500),
    breite: Millimeter(540),
    hoehe: Millimeter(156),
  );

  final int seite;

  /// Abstand vom Anfang der Seite („Seite“, Vorgabe 0).
  final Millimeter abstand;

  /// Breite der regulären Treppe längs der Seite.
  final Millimeter breite;
  final Treppenbau bau;
  final Treppenart art;

  /// „Individuelle Stufenmaße?“ – dann gelten [stufen] je Stufe.
  final bool individuell;

  /// Anzahl der Stufen (ohne Podest).
  final int anzahl;

  /// Maß aller Stufen ohne individuelle Maße.
  final Stufenmass stufe;

  /// Individuelle Maße je Stufe von oben; fehlt eine, gilt [stufe]. Sie
  /// bleiben beim Ausschalten erhalten.
  final List<Stufenmass> stufen;

  /// Podest der Fächertreppe; ohne Wirkung bei der regulären.
  final Podestmass podest;

  /// Maße je Stufe von oben, wie sie gelten.
  List<Stufenmass> get stufenmasse => [
    for (var i = 0; i < anzahl; i++)
      individuell && i < stufen.length ? stufen[i] : stufe,
  ];

  /// „Treppenmaße in cm (L x B x H)“ (Fachkonzept 5.1): regulär Breite ×
  /// Summe der Tiefen × Summe der Höhen (100 × 54 × 31,2); Fächertreppe
  /// mit Podest, 2-teilig Länge Podest + Stufen (104 × 108 × 46,8),
  /// 3-teilig Podest + zweimal Stufen (158 × 108 × 46,8).
  Treppenmasse get masse {
    final masse = stufenmasse;
    final tiefe = masse.fold(const Millimeter(0), (s, m) => s + m.tiefe);
    final hoehe = masse.fold(const Millimeter(0), (s, m) => s + m.hoehe);
    return switch (art) {
      Treppenart.regulaer => (laenge: breite, breite: tiefe, hoehe: hoehe),
      Treppenart.zweiteilig => (
        laenge: podest.tiefe + tiefe,
        breite: podest.breite + tiefe,
        hoehe: podest.hoehe + hoehe,
      ),
      Treppenart.dreiteilig => (
        laenge: podest.tiefe + tiefe * 2,
        breite: podest.breite + tiefe,
        hoehe: podest.hoehe + hoehe,
      ),
    };
  }

  /// Ob [abstand] als Abstand vom Anfang der Seite gilt: 0 bis 300 m.
  static bool abstandErlaubt(Millimeter abstand) =>
      abstand.mm >= 0 && abstand.mm <= 300000;

  /// Ob [mass] als Breite oder Podestmaß gilt: 10 bis 1000 cm.
  static bool massErlaubt(Millimeter mass) =>
      mass.mm >= 100 && mass.mm <= 10000;

  /// Ob [tiefe] als Auftrittstiefe gilt: 5 bis 100 cm.
  static bool tiefeErlaubt(Millimeter tiefe) =>
      tiefe.mm >= 50 && tiefe.mm <= 1000;

  /// Ob [hoehe] als Stufen- oder Podesthöhe gilt: 1 bis 50 cm.
  static bool hoeheErlaubt(Millimeter hoehe) =>
      hoehe.mm >= 10 && hoehe.mm <= 500;

  /// Ob [anzahl] als Anzahl der Stufen gilt: 1 bis 20.
  static bool anzahlErlaubt(int anzahl) => anzahl >= 1 && anzahl <= 20;

  /// Kopie, in der nur die angegebenen Felder anders sind; Werte außerhalb
  /// der Grenzen werden abgewiesen (`ArgumentError`).
  Treppe mit({
    int? seite,
    Millimeter? abstand,
    Millimeter? breite,
    Treppenbau? bau,
    Treppenart? art,
    bool? individuell,
    int? anzahl,
    Stufenmass? stufe,
    List<Stufenmass>? stufen,
    Podestmass? podest,
  }) {
    if (abstand != null) {
      _pruefe(abstandErlaubt(abstand), abstand.mm, 'abstand');
    }
    if (breite != null) _pruefe(massErlaubt(breite), breite.mm, 'breite');
    if (anzahl != null) _pruefe(anzahlErlaubt(anzahl), anzahl, 'anzahl');
    for (final s in [?stufe, ...?stufen]) {
      _pruefe(tiefeErlaubt(s.tiefe), s.tiefe.mm, 'tiefe');
      _pruefe(hoeheErlaubt(s.hoehe), s.hoehe.mm, 'hoehe');
    }
    if (podest != null) {
      _pruefe(massErlaubt(podest.tiefe), podest.tiefe.mm, 'podest');
      _pruefe(massErlaubt(podest.breite), podest.breite.mm, 'podest');
      _pruefe(hoeheErlaubt(podest.hoehe), podest.hoehe.mm, 'podest');
    }
    return Treppe(
      seite: seite ?? this.seite,
      abstand: abstand ?? this.abstand,
      breite: breite ?? this.breite,
      bau: bau ?? this.bau,
      art: art ?? this.art,
      individuell: individuell ?? this.individuell,
      anzahl: anzahl ?? this.anzahl,
      stufe: stufe ?? this.stufe,
      stufen: stufen == null ? this.stufen : List.unmodifiable(stufen),
      podest: podest ?? this.podest,
    );
  }

  static void _pruefe(bool erlaubt, Object wert, String name) {
    if (!erlaubt) {
      throw ArgumentError.value(wert, name, 'außerhalb der Grenzen');
    }
  }

  /// Kopie mit dem Maß [mass] für die Stufe [index] (von oben); schaltet die
  /// individuellen Stufenmaße ein, die übrigen Stufen behalten ihr Maß.
  Treppe mitStufe(int index, Stufenmass mass) {
    RangeError.checkValidIndex(index, stufenmasse, 'index');
    return mit(individuell: true, stufen: [...stufenmasse]..[index] = mass);
  }

  /// Schreibt die Tabelle `{ 0: seite, 1: abstand, 2: breite, 3: bau,
  /// 4: art (int32), 5: individuell (bool), 6: anzahl, 7: tiefe, 8: hoehe
  /// (int32 mm), 9: stufen ([int32] Tiefe und Höhe je Stufe), 10–12:
  /// Podest Tiefe, Breite, Höhe (int32 mm) }` und gibt ihren Ort zurück.
  int schreibe(fb.Builder fbb) {
    final stufenOrt = fbb.writeListInt32([
      for (final s in stufen) ...[s.tiefe.mm, s.hoehe.mm],
    ]);
    fbb
      ..startTable(_podestHoehePlatz + 1)
      ..addInt32(_seitePlatz, seite)
      ..addInt32(_abstandPlatz, abstand.mm)
      ..addInt32(_breitePlatz, breite.mm)
      ..addInt32(_bauPlatz, bau.nummer)
      ..addInt32(_artPlatz, art.nummer)
      ..addBool(_individuellPlatz, individuell)
      ..addInt32(_anzahlPlatz, anzahl)
      ..addInt32(_tiefePlatz, stufe.tiefe.mm)
      ..addInt32(_hoehePlatz, stufe.hoehe.mm)
      ..addOffset(_stufenPlatz, stufenOrt)
      ..addInt32(_podestTiefePlatz, podest.tiefe.mm)
      ..addInt32(_podestBreitePlatz, podest.breite.mm)
      ..addInt32(_podestHoehePlatz, podest.hoehe.mm);
    return fbb.endTable();
  }

  static const _seitePlatz = 0;
  static const _abstandPlatz = 1;
  static const _breitePlatz = 2;
  static const _bauPlatz = 3;
  static const _artPlatz = 4;
  static const _individuellPlatz = 5;
  static const _anzahlPlatz = 6;
  static const _tiefePlatz = 7;
  static const _hoehePlatz = 8;
  static const _stufenPlatz = 9;
  static const _podestTiefePlatz = 10;
  static const _podestBreitePlatz = 11;
  static const _podestHoehePlatz = 12;

  @override
  bool operator ==(Object other) {
    if (other is! Treppe ||
        other.seite != seite ||
        other.abstand != abstand ||
        other.breite != breite ||
        other.bau != bau ||
        other.art != art ||
        other.individuell != individuell ||
        other.anzahl != anzahl ||
        other.stufe != stufe ||
        other.podest != podest ||
        other.stufen.length != stufen.length) {
      return false;
    }
    for (var i = 0; i < stufen.length; i++) {
      if (other.stufen[i] != stufen[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    seite,
    abstand,
    breite,
    bau,
    art,
    individuell,
    anzahl,
    stufe,
    Object.hashAll(stufen),
    podest,
  );
}

int _versatz(int platz) => 4 + 2 * platz;
