import 'dart:math' as math;

import '../artikel/einheiten.dart';
import '../holzart/holzart.dart';
import '../konfiguration/terrassenart.dart';

/// Höhenpunkte nach der Prüfung gegen die Aufbauhöhe (Fachkonzept 3.2,
/// M6-02): je Eckpunkt A, B … die Höhe von Oberkante Belag bis Boden.
final class Hoehenpunkte {
  Hoehenpunkte({
    required List<Millimeter> hoehen,
    this.aufbauhoehe,
    this.mindesthoehe,
    this.korrigiert = false,
    this.gedreht = false,
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
}

/// Prüft die eingegebenen [hoehen] gegen die Aufbauhöhe (M6-02): Belag
/// ([dielenstaerke]) plus [Terrassenart.ukLagen] Lagen UK ([uk]), die UK
/// hochkant mit der größeren Seite als Höhe. Liegt ein Punkt darunter,
/// wird die UK gedreht (die kleinere Seite als Höhe, B-034); liegt er auch
/// darunter, wird er auf diese Mindesthöhe korrigiert. Auflager (Pads,
/// Stelzfüße) zählen nicht dazu (M6-08). Ohne Dielenstärke oder UK-Maße
/// bleiben die Höhen ungeprüft.
Hoehenpunkte pruefeHoehen(
  List<Millimeter> hoehen, {
  required Terrassenart art,
  Millimeter? dielenstaerke,
  UkMasse? uk,
}) {
  if (dielenstaerke == null || uk == null) return Hoehenpunkte(hoehen: hoehen);
  final hochkant = Millimeter(math.max(uk.a.mm, uk.b.mm));
  final flach = Millimeter(math.min(uk.a.mm, uk.b.mm));
  final stehend = dielenstaerke + hochkant * art.ukLagen;
  final liegend = dielenstaerke + flach * art.ukLagen;
  final gedreht = flach < hochkant && hoehen.any((h) => h < stehend);
  return Hoehenpunkte(
    hoehen: [for (final h in hoehen) h < liegend ? liegend : h],
    aufbauhoehe: gedreht ? liegend : stehend,
    mindesthoehe: liegend,
    korrigiert: hoehen.any((h) => h < liegend),
    gedreht: gedreht,
  );
}
