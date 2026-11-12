import 'dart:math' as math;

import '../artikel/einheiten.dart';
import '../holzart/holzart.dart';
import '../konfiguration/terrassenart.dart';
import 'planungsregeln.dart';

/// Höhenpunkte nach der Prüfung gegen die Aufbauhöhe (Fachkonzept 3.2,
/// M6-02): je Eckpunkt A, B … die Höhe von Oberkante Belag bis Boden.
final class Hoehenpunkte {
  Hoehenpunkte({
    required List<Millimeter> hoehen,
    this.aufbauhoehe,
    this.mindesthoehe,
    this.korrigiert = false,
    this.gedreht = false,
    this.hoechsthoehe,
    this.ungueltig = false,
    this.vorschlag,
  }) : hoehen = List.unmodifiable(hoehen);

  /// Ohne Höhenpunkte (offene Freiform).
  static final keine = Hoehenpunkte(hoehen: const []);

  /// Höhe je Eckpunkt, unter der [mindesthoehe] auf sie korrigiert.
  final List<Millimeter> hoehen;

  /// Höhe von Belag und Unterkonstruktion in der Lage, in der die UK
  /// eingebaut wird; `null`, solange Dielenstärke oder UK-Maße fehlen.
  final Millimeter? aufbauhoehe;

  /// Niedrigste mögliche Höhe: Belag plus UK flach (gedreht); `null` wie
  /// [aufbauhoehe].
  final Millimeter? mindesthoehe;

  /// Ob ein eingegebener Höhenpunkt die [mindesthoehe] unterschritt und
  /// korrigiert wurde.
  final bool korrigiert;

  /// Ob die UK zur Einhaltung der Aufbauhöhe gedreht wird – die kleinere
  /// Seite steht, Breite und Stärke sind tauschbar (B-034).
  final bool gedreht;

  /// Höchsthöhe mit Stellfüßen (Planungsregeln Alexander (Planungskern v6,
  /// 11.11.2026), Regel 3a.4): Aufbauhöhe + 1 mm Gummiband + 440 mm; nur
  /// bei der normalen Terrasse, sonst `null`.
  final Millimeter? hoechsthoehe;

  /// Ob ein eingegebener Höhenpunkt über der [hoechsthoehe] lag (Regel
  /// 3a.5): dann gilt überall der Standardaufbau, die Prüfliste zeigt
  /// „Höhe ungültig“.
  final bool ungueltig;

  /// Rückfrage „Meintest du … cm?“ zur ersten zu großen Eingabe (Regel
  /// 3a.5: 113 cm → 11,3 cm); `null`, wenn ein Zehntel auch nicht passt.
  final Millimeter? vorschlag;
}

/// Prüft die eingegebenen [hoehen] gegen die Aufbauhöhe (M6-02): Belag
/// ([dielenstaerke]) plus [Terrassenart.ukLagen] Lagen UK ([uk]), die UK
/// hochkant mit der größeren Seite als Höhe. Liegt ein Punkt darunter,
/// wird die UK gedreht (die kleinere Seite als Höhe, B-034); liegt er auch
/// darunter, wird er auf diese Mindesthöhe korrigiert. Auflager (Pads,
/// Stelzfüße) zählen nicht dazu (M6-08). Ohne Dielenstärke oder UK-Maße
/// bleiben die Höhen ungeprüft.
///
/// Bei der normalen Terrasse (Stellfüße) gilt die Höchsthöhe (Planungsregeln
/// Alexander (Planungskern v6, 11.11.2026), Regel 3a.4/3a.5): Liegt ein
/// Punkt über Aufbauhöhe + [gummiband] + [stellfussAusgleichBis], ist die
/// Eingabe ungültig – gerechnet wird überall mit dem Standardaufbau (UK
/// hochkant, Höhe = Aufbauhöhe + Gummiband, das dünnste Pad darunter), dazu
/// die Rückfrage „Meintest du … cm?“ mit einem Zehntel der Eingabe, wenn es
/// zwischen Mindest- und Höchsthöhe liegt. Hochterrasse und vorhandene UK
/// stehen auf Stützen bzw. der vorhandenen UK – dort keine Höchsthöhe
/// (offene Frage 24).
Hoehenpunkte pruefeHoehen(
  List<Millimeter> hoehen, {
  required Terrassenart art,
  bool doppelteUk = false,
  Millimeter? dielenstaerke,
  UkMasse? uk,
}) {
  if (dielenstaerke == null || uk == null) return Hoehenpunkte(hoehen: hoehen);
  final lagen = doppelteUk ? 2 : art.ukLagen;
  final hochkant = Millimeter(math.max(uk.a.mm, uk.b.mm));
  final flach = Millimeter(math.min(uk.a.mm, uk.b.mm));
  final stehend = dielenstaerke + hochkant * lagen;
  final liegend = dielenstaerke + flach * lagen;
  final hoechst = art == Terrassenart.normal
      ? stehend + gummiband + stellfussAusgleichBis
      : null;
  if (hoechst != null && hoehen.any((h) => h > hoechst)) {
    final zehntel = Millimeter(
      (hoehen.firstWhere((h) => h > hoechst).mm / 10).round(),
    );
    return Hoehenpunkte(
      hoehen: [for (final _ in hoehen) stehend + gummiband],
      aufbauhoehe: stehend,
      mindesthoehe: liegend,
      hoechsthoehe: hoechst,
      ungueltig: true,
      vorschlag: zehntel >= liegend && zehntel <= hoechst ? zehntel : null,
    );
  }
  final gedreht = flach < hochkant && hoehen.any((h) => h < stehend);
  return Hoehenpunkte(
    hoehen: [for (final h in hoehen) h < liegend ? liegend : h],
    aufbauhoehe: gedreht ? liegend : stehend,
    mindesthoehe: liegend,
    korrigiert: hoehen.any((h) => h < liegend),
    gedreht: gedreht,
    hoechsthoehe: hoechst,
  );
}
