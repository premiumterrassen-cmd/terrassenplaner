import '../holzart/holzart.dart';

/// Befestigungsart des Belags auf der Unterkonstruktion (Fachkonzept 2.6,
/// M5-09). Welche Arten wählbar sind, folgt aus dem Profil der Diele: Clips
/// nur bei genuteten Dielen (B-094), glattkante Dielen werden von oben
/// verschraubt (B-090) – direkt oder mit Abstandshaltern zwischen Diele und
/// Unterkonstruktion.
enum Befestigungsart {
  /// Verdeckt mit Clips in der Nut (Vorgabe, CLIP-FIXX bzw. DUO-CLIP-FIXX).
  clips(0),

  /// Von oben direkt auf die Unterkonstruktion verschraubt.
  verschraubt(1),

  /// Von oben verschraubt, je Befestigungspunkt ein Abstandshalter.
  verschraubtMitAbstandshaltern(2);

  const Befestigungsart(this.nummer);

  /// Nummer im Transportformat (Planungsstand, Berechnung).
  final int nummer;

  /// Wählbare Arten für ein Profil, die erste ist die Vorgabe; ohne Profil
  /// (Holzfliese) keine.
  static List<Befestigungsart> fuer(Profil? profil) => switch (profil) {
    Profil.genutet => const [clips],
    Profil.glattkant => const [verschraubt, verschraubtMitAbstandshaltern],
    null => const [],
  };

  /// Die Art, die für [profil] gilt: diese, wenn sie wählbar ist, sonst die
  /// Vorgabe des Profils; `null` ohne wählbare Art. So bleibt eine Wahl
  /// erhalten, wenn zwischendurch ein Belag mit anderem Profil gewählt war.
  Befestigungsart? wirksam(Profil? profil) {
    final arten = fuer(profil);
    return arten.contains(this) ? this : arten.firstOrNull;
  }

  /// Art zur [nummer] aus dem Transportformat.
  static Befestigungsart ausNummer(int nummer) => values.firstWhere(
    (a) => a.nummer == nummer,
    orElse: () => throw FormatException('unbekannte Befestigungsart $nummer'),
  );
}
