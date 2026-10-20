/// Typsichere Einheiten des Fachmodells (M2-01): keine nackten Zahlen für
/// Maße, Gewichte und Preise.
library;

/// Länge in ganzen Millimetern.
extension type const Millimeter(int mm) implements Object {
  /// Aus Zentimetern, auf ganze Millimeter gerundet.
  Millimeter.ausCm(num cm) : mm = (cm * 10).round();

  /// Aus Metern, auf ganze Millimeter gerundet.
  Millimeter.ausM(num m) : mm = (m * 1000).round();

  double get cm => mm / 10;
  double get m => mm / 1000;

  Millimeter operator +(Millimeter andere) => Millimeter(mm + andere.mm);
  Millimeter operator -(Millimeter andere) => Millimeter(mm - andere.mm);
  Millimeter operator *(int faktor) => Millimeter(mm * faktor);
  bool operator <(Millimeter andere) => mm < andere.mm;
  bool operator <=(Millimeter andere) => mm <= andere.mm;
  bool operator >(Millimeter andere) => mm > andere.mm;
  bool operator >=(Millimeter andere) => mm >= andere.mm;
}

/// Gewicht in ganzen Gramm.
extension type const Gramm(int g) implements Object {
  /// Aus Kilogramm, auf ganze Gramm gerundet.
  Gramm.ausKg(num kg) : g = (kg * 1000).round();

  double get kg => g / 1000;

  Gramm operator +(Gramm andere) => Gramm(g + andere.g);
  Gramm operator *(num faktor) => Gramm((g * faktor).round());
}

/// Geldbetrag in ganzen Cent – im Planer nur Anzeige, führend ist das ERP
/// (B-055).
extension type const Cent(int cent) implements Object {
  /// Aus Euro, auf ganze Cent gerundet.
  Cent.ausEuro(num euro) : cent = (euro * 100).round();

  double get euro => cent / 100;

  Cent operator +(Cent andere) => Cent(cent + andere.cent);
  Cent operator *(num faktor) => Cent((cent * faktor).round());

  /// Deutsche Schreibweise mit Tausenderpunkt, z. B. „2.066,57 €“.
  String get anzeige {
    final negativ = cent < 0;
    final betrag = cent.abs();
    final euroTeil = (betrag ~/ 100).toString();
    final gruppen = <String>[];
    for (var ende = euroTeil.length; ende > 0; ende -= 3) {
      gruppen.insert(0, euroTeil.substring(ende < 3 ? 0 : ende - 3, ende));
    }
    final rest = (betrag % 100).toString().padLeft(2, '0');
    return '${negativ ? '-' : ''}${gruppen.join('.')},$rest €';
  }
}

/// Einheit, in der ein Artikel verkauft und gezählt wird.
enum Mengeneinheit {
  stueck('Stück'),
  laufmeter('lfm'),
  quadratmeter('m²'),
  verpackungseinheit('VPE'),
  karton('Karton'),
  set('Set'),
  kiste('Kiste'),
  liter('l');

  const Mengeneinheit(this.anzeige);

  /// Kurzform für Listen und Exporte.
  final String anzeige;

  /// Liest die Schreibweisen aus Master-Artikelliste und Exporten
  /// („Stück“, „St.“, „ST“, „lfm“, „VE“ …); `null`, wenn unbekannt.
  static Mengeneinheit? lies(String text) =>
      switch (text.trim().toLowerCase()) {
        'stück' || 'stk.' || 'stk' || 'st.' || 'st' => stueck,
        'lfm' => laufmeter,
        'm²' || 'm2' || 'qm' => quadratmeter,
        'vpe' || 've' => verpackungseinheit,
        'karton' => karton,
        'set' => set,
        'kiste' => kiste,
        'l' || 'liter' => liter,
        _ => null,
      };
}

/// Verkaufseinheit: z. B. „Karton zu 100 Stück“ oder „1 lfm“.
final class Verkaufseinheit {
  Verkaufseinheit(this.einheit, {this.inhalt = 1, this.inhaltEinheit}) {
    if (inhalt <= 0) {
      throw ArgumentError.value(inhalt, 'inhalt', 'muss größer als 0 sein');
    }
  }

  final Mengeneinheit einheit;

  /// Inhalt je Verkaufseinheit (z. B. 100 Clips je Karton).
  final num inhalt;

  /// Einheit des Inhalts (z. B. Stück je Karton); `null` = wie [einheit].
  final Mengeneinheit? inhaltEinheit;

  /// Anzahl Verkaufseinheiten für einen Bedarf (immer aufgerundet).
  int fuerBedarf(num bedarf) => bedarf <= 0 ? 0 : (bedarf / inhalt).ceil();

  @override
  bool operator ==(Object other) =>
      other is Verkaufseinheit &&
      other.einheit == einheit &&
      other.inhalt == inhalt &&
      other.inhaltEinheit == inhaltEinheit;

  @override
  int get hashCode => Object.hash(einheit, inhalt, inhaltEinheit);

  @override
  String toString() => inhalt == 1 && inhaltEinheit == null
      ? einheit.anzeige
      : '${einheit.anzeige} zu $inhalt ${(inhaltEinheit ?? einheit).anzeige}';
}
