import 'package:flutter/widgets.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import 'steuerung.dart';
import 'zeichnung.dart';

/// Berechnet eine Planung auf dem Server (M4-02, mehrere Flächen M4-14); in
/// Tests austauschbar.
typedef PlanungBerechnen = Future<Berechnung> Function(Planung planung);

/// Der Server bricht die Berechnung ab, weil die Planung zu aufwendig ist
/// (Rechenzeit über der Höchstdauer, M10-02) – kein Verbindungsfehler.
final class PlanungZuAufwendig implements Exception {}

/// Hält die Berechnung des Servers zum aktuellen Planungsstand (M4-02): bei
/// jeder Änderung neu angefragt; kommt eine Antwort zu einem älteren Stand
/// erst nach einer neueren, wird sie verworfen. Die App rechnet nichts selbst.
class BerechnungsSteuerung extends ChangeNotifier {
  BerechnungsSteuerung({required this.planung, required this.berechne}) {
    planung.addListener(_frage);
    _frage();
  }

  final PlanungsSteuerung planung;
  final PlanungBerechnen berechne;

  Berechnung? _ergebnis;
  Object? _fehler;
  var _anfrage = 0;

  /// Letzte gültige Berechnung; `null`, solange keine vorliegt.
  Berechnung? get ergebnis => _ergebnis;

  /// Fehler der letzten Anfrage; `null`, wenn sie gelang.
  Object? get fehler => _fehler;

  /// Was die Zeichenfläche zeigt.
  Zeichnung get zeichnung => switch (_ergebnis) {
    final b? => Zeichnung(
      umriss: _offsets(b.umriss),
      ecken: _offsets(b.ecken),
      geschlossen: b.geschlossen,
      ausschnitte: [for (final a in b.ausschnitte) _offsets(a)],
      ausschnittDarstellung: [
        for (final a in planung.aktuell.ausschnitte)
          (name: a.bezeichnung, farbe: farbe(a)),
      ],
      dielen: [for (final d in b.dielen) _offsets(d)],
      nummern: b.nummern,
      dielenfarben: [for (final f in b.stueckfarben) Color(f.argb)],
      querstreben: [
        for (final s in b.querstreben)
          (Offset(s.von.x, s.von.y), Offset(s.bis.x, s.bis.y)),
      ],
      ukHoelzer: [
        for (final h in b.unterbau.hoelzer)
          (
            Offset(h.von.x, h.von.y),
            Offset(h.bis.x, h.bis.y),
            Color(h.farbe.argb),
          ),
      ],
      ukBreite: (b.unterbau.holzbreite?.mm ?? 0).toDouble(),
      auflager: [
        for (final p in b.unterbau.auflagerpunkte)
          (
            ort: Offset(p.ort.x, p.ort.y),
            spalt: p.spalt,
            zeile: p.zeile,
            // wie im UK-Plan der Unterlagen: Auflager 5 mm über das Holz
            richtung: _offset(
              fusshoehenRichtung(
                p.ort,
                b.unterbau.hoelzer,
                (b.unterbau.holzbreite?.mm ?? 40) / 2 + 5,
              ),
            ),
          ),
      ],
      seiten: [
        for (final s in b.anschluss.seiten)
          (Offset(s.von.x, s.von.y), Offset(s.bis.x, s.bis.y), s.rolle),
      ],
      treppen: [
        for (final t in b.anschluss.treppen)
          for (final teil in t.teile) _offsets(teil),
      ],
      ablaeufe: [
        for (final p in b.anschluss.hoehenpunkte) Offset(p.ort.x, p.ort.y),
      ],
      ausgangspunkt: switch (b.ausgangspunkt) {
        final p? => Offset(p.x, p.y),
        null => null,
      },
      // Pläne nach dem Planungskern (R-E01 bis R-E03)
      namen: b.eckbuchstaben,
      stoesse: [
        for (final s in b.planbild.stoesse)
          (Offset(s.von.x, s.von.y), Offset(s.bis.x, s.bis.y)),
      ],
      achsen: switch (b.planbild.achsen) {
        final k? => (
          marken: _offsets(k.marken),
          normale: Offset(k.normale.x, k.normale.y),
        ),
        null => null,
      },
    ),
    null => Zeichnung.leer,
  };

  /// Füllung eines Ausschnitts (Fachkonzept 1.4: nur Darstellung).
  static Color farbe(Ausschnitt a) => switch ((a.funktion, a.inhalt)) {
    (Ausschnittfunktion.andererBelag, _) => PlanerFarben.belagAnders,
    (_, Ausschnittinhalt.leer) => PlanerFarben.weiss,
    (_, Ausschnittinhalt.kiesHell) => const Color(0xFFD8D4CC),
    (_, Ausschnittinhalt.steinDunkel) => const Color(0xFF6E6A66),
    (_, Ausschnittinhalt.pool) => const Color(0xFF7FC4E8),
    (_, Ausschnittinhalt.rasen) => const Color(0xFF8DC26F),
    (_, Ausschnittinhalt.erde) => const Color(0xFF8B6A4E),
  };

  static List<Offset> _offsets(List<Punkt> punkte) => [
    for (final p in punkte) _offset(p),
  ];

  static Offset _offset(Punkt p) => Offset(p.x, p.y);

  /// Terrassenfläche in m² für die Kennzahlen.
  /// Offene Freiform (M4-08): keine Fläche.
  double? get flaeche => switch (_ergebnis) {
    final b? when b.geschlossen => b.flaecheQuadratmeter,
    _ => null,
  };

  /// Summe aller Flächen mal Häufigkeit in m² (M4-14); `null` bei nur einer
  /// Fläche, die einmal gebaut wird – dann ist sie gleich der [flaeche].
  double? get gesamtflaeche => switch (_ergebnis) {
    final b?
        when planung.planung.flaechen.length > 1 ||
            planung.planung.haeufigkeit > 1 =>
      b.gesamtflaecheQuadratmeter,
    _ => null,
  };

  /// Verschnitt der ganzen Planung als Anteil (M5-08); `null` ohne
  /// verlegte Dielen.
  double? get verschnitt => _ergebnis?.verschnitt;

  /// Holzvolumen der ganzen Planung in m³ (M6-10); `null` ohne Holz.
  double? get volumen => _ergebnis?.volumen;

  /// Benötigte Dielen der ganzen Planung je Belag und Lieferlänge (M5-08).
  List<Lieferposition> get dielenliste => _ergebnis?.dielenliste ?? const [];

  /// Materialliste der ganzen Planung (M9-03); leer, solange keine
  /// Berechnung vorliegt.
  Materialliste get materialliste =>
      _ergebnis?.materialliste ?? Materialliste.leer;

  /// Stückliste der bearbeiteten Fläche (M9-04); leer, solange keine
  /// Berechnung vorliegt.
  Stueckliste get stueckliste => _ergebnis?.stueckliste ?? Stueckliste.leer;

  /// Zuschnittplan des Belags der ganzen Planung (M9-02); leer, solange
  /// keine Berechnung vorliegt.
  Zuschnittplan get zuschnittBelag =>
      _ergebnis?.zuschnittBelag ?? Zuschnittplan.leer;

  /// Zuschnittplan der Unterkonstruktion der ganzen Planung (M9-02).
  Zuschnittplan get zuschnittUk => _ergebnis?.zuschnittUk ?? Zuschnittplan.leer;

  Future<void> _frage() async {
    final nummer = ++_anfrage;
    try {
      final ergebnis = await berechne(planung.planung);
      if (nummer != _anfrage) return;
      _ergebnis = ergebnis;
      _fehler = null;
    } on Object catch (fehler) {
      if (nummer != _anfrage) return;
      _fehler = fehler;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    // Antworten, die danach noch eintreffen, gelten als veraltet.
    _anfrage++;
    planung.removeListener(_frage);
    super.dispose();
  }
}
