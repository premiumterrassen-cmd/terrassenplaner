import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'grundriss_eingabe.dart';
import 'steuerung.dart';
import 'zeichnung.dart';

/// Maßeingabe der Freiform (Fachkonzept 1.1): Strecke (Länge und Winkel vom
/// vorletzten Punkt) oder Koordinaten des letzten Punkts.
enum Masseingabe { strecke, koordinaten }

/// Warum ein Schritt der Freiform nicht ging (Rückmeldung, M4-08).
enum FreiformFehler { mindestens3, kreuzt, kante }

/// Bedienzustand beim Zeichnen (M4-08) – keine Fachdaten: Einrastfunktion,
/// Zeichnungshilfe, Art der Maßeingabe und ausgewählte Ecke (M4-09).
class ZeichenModus extends ChangeNotifier {
  bool _einrasten = true;
  bool _zeichnungshilfe = true;
  Masseingabe _eingabe = Masseingabe.strecke;
  int? _auswahl;

  /// Ausgewählte Ecke der geschlossenen Form, `null` = keine.
  int? get auswahl => _auswahl;

  set auswahl(int? wert) {
    _auswahl = wert;
    notifyListeners();
  }

  bool get einrasten => _einrasten;
  bool get zeichnungshilfe => _zeichnungshilfe;
  Masseingabe get eingabe => _eingabe;

  set einrasten(bool wert) {
    _einrasten = wert;
    notifyListeners();
  }

  set zeichnungshilfe(bool wert) {
    _zeichnungshilfe = wert;
    notifyListeners();
  }

  set eingabe(Masseingabe wert) {
    _eingabe = wert;
    notifyListeners();
  }
}

/// Zeichnen der Freiform (M4-08) für Zeichenfläche und Menü: setzt Punkte
/// mit den Hilfen des [modus], schließt, entfernt und korrigiert.
class FreiformBedienung {
  FreiformBedienung({
    required this.planung,
    required this.modus,
    required this.onGeaendert,
  });

  final PlanungsSteuerung planung;
  final ZeichenModus modus;

  /// Meldet eine übernommene Eingabe (Standardwert-Hinweis, M3-05).
  final VoidCallback onGeaendert;

  /// Die Freiform, solange sie offen ist – sonst `null`.
  FreiformGrundriss? get offen => switch (planung.aktuell.grundriss) {
    final FreiformGrundriss f when !f.geschlossen => f,
    _ => null,
  };

  /// Setzt einen Punkt an [ort] (mm); Einrastfunktion und Zeichnungshilfe
  /// wirken, wenn eingeschaltet.
  FreiformFehler? setzePunkt(Punkt ort) {
    final f = offen!;
    var p = ort;
    if (modus.zeichnungshilfe && f.punkte.isNotEmpty) {
      p = Zeichenhilfe.ausrichten(f.punkte.last, p);
    }
    if (modus.einrasten) p = Zeichenhilfe.einrasten(p);
    return _setze(() => f.mitPunkt(p));
  }

  /// Schließt die Form (Taste x, Knopf „Form schließen“).
  FreiformFehler? schliesse() => _setze(() => offen!.geschlossene());

  /// Entfernt den letzten Punkt; eine geschlossene Form wird wieder offen.
  void entferneLetzten() {
    final f = planung.aktuell.grundriss as FreiformGrundriss;
    planung.setze(planung.aktuell.mitGrundriss(f.ohneLetztenPunkt()));
    onGeaendert();
  }

  /// Zeichnungshilfe per Maßeingabe: verlegt den letzten Punkt.
  FreiformFehler? korrigiere(Punkt neu) =>
      _setze(() => offen!.mitLetztemPunkt(neu));

  /// Die Ecken zum Bearbeiten (M4-09): jede Form mit Ecken, die nicht gerade
  /// gezeichnet wird; der Kreis hat keine (`null`).
  FreiformGrundriss? get bearbeitbar =>
      offen == null ? planung.aktuell.grundriss.alsFreiform : null;

  FreiformGrundriss? _vorZiehen;

  /// Zieht Ecke [index] um [versatz] mm (Summe seit Beginn); [beginn] legt
  /// einen Rückgängig-Schritt an, weitere Schritte ersetzen ihn. Eine feste
  /// Form wird dabei zur Freiform. Ungültige Zwischenstände bleiben aus.
  void ziehePunkt(int index, Punkt versatz, {required bool beginn}) =>
      _ziehe(beginn, (f) {
        var p = f.punkte[index] + versatz;
        if (modus.einrasten) p = Zeichenhilfe.einrasten(p);
        return f.mitPunktAn(index, p);
      });

  /// Verschiebt Kante [kante] parallel um den Anteil von [versatz] senkrecht
  /// zu ihr (Ziehen an der Kantenmitte).
  void zieheKante(int kante, Punkt versatz, {required bool beginn}) =>
      _ziehe(beginn, (f) => f.mitVerschobenerKante(kante, versatz));

  void _ziehe(bool beginn, FreiformGrundriss Function(FreiformGrundriss) neu) {
    if (beginn) _vorZiehen = bearbeitbar;
    final FreiformGrundriss f;
    try {
      f = neu(_vorZiehen!);
    } on ArgumentError {
      return;
    }
    final stand = planung.aktuell.mitGrundriss(f);
    if (beginn) {
      planung.setze(stand);
      onGeaendert();
    } else {
      planung.ersetze(stand);
    }
  }

  /// Neuer Punkt in der Mitte der Kante [kante] (Antippen der Kantenmitte).
  FreiformFehler? fuegePunktEin(int kante) =>
      _setze(() => bearbeitbar!.mitPunktAufKante(kante));

  /// Entfernt die Ecke [index]; mindestens drei bleiben.
  FreiformFehler? entfernePunkt(int index) {
    final fehler = _setze(() => bearbeitbar!.ohnePunkt(index));
    if (fehler == null) modus.auswahl = null;
    return fehler;
  }

  /// Maßeingabe für die ausgewählte Ecke [index].
  FreiformFehler? korrigierePunkt(int index, Punkt neu) =>
      _setze(() => bearbeitbar!.mitPunktAn(index, neu));

  FreiformFehler? _setze(FreiformGrundriss Function() neu) {
    final FreiformGrundriss f;
    try {
      f = neu();
    } on ArgumentError catch (e) {
      final text = '${e.message}';
      if (text.contains('mindestens 3')) return FreiformFehler.mindestens3;
      if (text.contains('kreuzen') || text.contains('Fläche')) {
        return FreiformFehler.kreuzt;
      }
      return FreiformFehler.kante;
    }
    planung.setze(planung.aktuell.mitGrundriss(f));
    onGeaendert();
    return null;
  }

  /// Rückmeldung zu einem [fehler] in der Sprache der Oberfläche.
  static String meldung(PlanerTexte t, FreiformFehler fehler) =>
      switch (fehler) {
        FreiformFehler.mindestens3 => t.freiformMindestens3,
        FreiformFehler.kreuzt => t.freiformKreuzt,
        FreiformFehler.kante => t.freiformKante(
          FreiformGrundriss.kleinsteKante.mm ~/ 10,
          Grundriss.groessteSeite.mm ~/ 10,
        ),
      };

  /// Zeigt die Rückmeldung, falls es einen [fehler] gab.
  static void melde(BuildContext context, FreiformFehler? fehler) {
    if (fehler == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(meldung(context.texte, fehler))));
  }
}

/// Eingaben der Freiform unter 1.2 (M4-08): Schalter für Einrastfunktion
/// und Zeichnungshilfe, Maßeingabe Strecke | Koordinaten für den letzten
/// Punkt, letzten Punkt entfernen, Form schließen.
class FreiformEingabe extends StatelessWidget {
  const FreiformEingabe({required this.bedienung, super.key});

  final FreiformBedienung bedienung;

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    final modus = bedienung.modus;
    final f = bedienung.planung.aktuell.grundriss as FreiformGrundriss;
    return ListenableBuilder(
      listenable: modus,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SwitchListTile(
            key: const ValueKey('einrastfunktion'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t.einrastfunktion),
            value: modus.einrasten,
            onChanged: (wert) => modus.einrasten = wert,
          ),
          SwitchListTile(
            key: const ValueKey('zeichnungshilfe'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(t.zeichnungshilfe),
            value: modus.zeichnungshilfe,
            onChanged: (wert) => modus.zeichnungshilfe = wert,
          ),
          if (f.geschlossen) ...[
            Text(t.formGeschlossen, key: const ValueKey('form-geschlossen')),
            ..._auswahl(context, t, modus),
          ] else ...[
            _eingabeArt(t, modus),
            const SizedBox(height: PlanerAbstand.klein),
            _Masse(
              key: ValueKey(modus.eingabe),
              bedienung: bedienung,
              eingabe: modus.eingabe,
            ),
            FilledButton.tonal(
              key: const ValueKey('form-schliessen'),
              onPressed: () =>
                  FreiformBedienung.melde(context, bedienung.schliesse()),
              child: Text(t.formSchliessen),
            ),
          ],
          TextButton(
            key: const ValueKey('punkt-entfernen'),
            onPressed: f.punkte.isEmpty ? null : bedienung.entferneLetzten,
            child: Text(t.letztenPunktEntfernen),
          ),
        ],
      ),
    );
  }
}

extension on FreiformEingabe {
  /// Geschlossene Form (M4-09): Hinweis oder die ausgewählte Ecke mit
  /// Maßeingabe und „Punkt entfernen“.
  List<Widget> _auswahl(BuildContext context, PlanerTexte t, ZeichenModus m) {
    final i = m.auswahl;
    if (i == null) {
      return [Text(t.eckeAntippen, key: const ValueKey('ecke-antippen'))];
    }
    return [
      Text(
        t.punktAusgewaehlt(ZeichnungsMaler.punktname(i)),
        key: const ValueKey('punkt-ausgewaehlt'),
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      _eingabeArt(t, m),
      const SizedBox(height: PlanerAbstand.klein),
      _Masse(
        key: ValueKey((i, m.eingabe)),
        bedienung: bedienung,
        eingabe: m.eingabe,
        index: i,
      ),
      TextButton(
        key: const ValueKey('ecke-entfernen'),
        onPressed: () =>
            FreiformBedienung.melde(context, bedienung.entfernePunkt(i)),
        child: Text(t.punktEntfernen),
      ),
    ];
  }
}

/// Umschalter Strecke | Koordinaten.
Widget _eingabeArt(PlanerTexte t, ZeichenModus modus) =>
    SegmentedButton<Masseingabe>(
      key: const ValueKey('masseingabe'),
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: Masseingabe.strecke,
          label: Text(t.eingabeStrecke),
        ),
        ButtonSegment(
          value: Masseingabe.koordinaten,
          label: Text(t.eingabeKoordinaten),
        ),
      ],
      selected: {modus.eingabe},
      onSelectionChanged: (auswahl) => modus.eingabe = auswahl.single,
    );

/// Felder der Maßeingabe: Strecke (Länge cm, Winkel °) vom vorherigen Punkt
/// oder Koordinaten (X, Y cm) – für den letzten Punkt beim Zeichnen oder die
/// ausgewählte Ecke [index] einer geschlossenen Form (M4-09).
class _Masse extends StatelessWidget {
  const _Masse({
    required this.bedienung,
    required this.eingabe,
    this.index,
    super.key,
  });

  final FreiformBedienung bedienung;
  final Masseingabe eingabe;
  final int? index;

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    final strecke = eingabe == Masseingabe.strecke;
    return MassFelder(
      schluessel: 'freiform',
      namen: strecke ? [t.feldLaenge, t.feldWinkel] : const ['X', 'Y'],
      kleinstes: FreiformGrundriss.kleinsteKante,
      platzhalter: strecke ? [null, t.winkelPlatzhalter(t.feldWinkel)] : null,
      uebernimm: (feld, wert) {
        final punkte = (bedienung.offen ?? bedienung.bearbeitbar)!.punkte;
        final n = punkte.length;
        final i = index ?? n - 1;
        final punkt = punkte[i];
        final Punkt neu;
        if (strecke) {
          // beim Zeichnen der vorletzte Punkt, sonst die Ecke davor
          final von = punkte[index == null ? n - 2 : (i + n - 1) % n];
          final laenge = feld == 0 ? wert.mm.toDouble() : punkt.abstand(von);
          // Winkel kommt als Zahl wie ein Maß in cm: 90 → 900 „mm“
          final winkel = feld == 1
              ? wert.mm / 10
              : Zeichenhilfe.winkelVon(von, punkt);
          neu = Zeichenhilfe.streckenpunkt(von, laenge, winkel);
        } else {
          neu = feld == 0
              ? Punkt(wert.mm.toDouble(), punkt.y)
              : Punkt(punkt.x, wert.mm.toDouble());
        }
        final fehler = index == null
            ? bedienung.korrigiere(neu)
            : bedienung.korrigierePunkt(i, neu);
        if (fehler != null) {
          throw ArgumentError(FreiformBedienung.meldung(t, fehler));
        }
      },
    );
  }
}
