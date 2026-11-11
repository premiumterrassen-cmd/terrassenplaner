import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'berechnung_steuerung.dart';
import 'hoehenpunkte.dart';
import 'steuerung.dart';
import 'zeichnung.dart';

/// Wert in cm mit höchstens einer Nachkommastelle im Format der Sprache
/// („8,6“).
String cmText(PlanerTexte t, Millimeter mm) => zahlText(t, mm.cm, '0.#');

/// Liest eine Eingabe in cm („8,6“ oder „8.6“) als ganze mm; `null`, wenn
/// es keine Zahl ist.
Millimeter? cmAusText(String text) {
  final cm = num.tryParse(text.trim().replaceAll(',', '.'));
  return cm == null || !cm.isFinite ? null : Millimeter.ausCm(cm);
}

/// Unterpunkt „Art der Terrasse“ (Fachkonzept 3.1, M6-01): normale
/// Terrasse (Vorgabe), Hochterrasse oder vorhandene UK mit ihrer
/// Vorgabehöhe; bei vorhandener UK dazu das Feld „Spannweite“. Jede Wahl
/// ist ein Schritt für Rückgängig/Wiederherstellen.
class TerrassenartWahl extends StatelessWidget {
  const TerrassenartWahl({
    required this.planung,
    required this.onGeaendert,
    super.key,
  });

  final PlanungsSteuerung planung;

  /// Meldet eine Änderung (Standardwert-Hinweis, M3-05).
  final VoidCallback onGeaendert;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: planung,
    builder: (context, _) {
      final t = context.texte;
      final stand = planung.aktuell;
      final gewaehlt = stand.terrassenart;
      return Column(
        key: const ValueKey('terrassenart'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: PlanerAbstand.klein,
            children: [
              for (final art in Terrassenart.values)
                ChoiceChip(
                  key: ValueKey('terrassenart-${art.name}'),
                  label: Text(terrassenartText(t, art)),
                  selected: art == gewaehlt,
                  onSelected: (an) {
                    if (an) {
                      planung.setze(planung.aktuell.mitTerrassenart(art));
                      onGeaendert();
                    }
                  },
                ),
            ],
          ),
          Text(t.vorgabehoehe(cmText(t, gewaehlt.vorgabehoehe))),
          if (gewaehlt.mitSpannweite) ...[
            const SizedBox(height: PlanerAbstand.klein),
            Text(t.spannweiteFrage),
            CmFeld(
              key: const ValueKey('spannweite'),
              titel: t.spannweite,
              wert: stand.spannweite,
              gueltig: Terrassenart.spannweiteGueltig,
              fehler: t.spannweiteUngueltig,
              onGeaendert: (mm) {
                planung.setze(planung.aktuell.mitSpannweite(mm));
                onGeaendert();
              },
            ),
          ],
        ],
      );
    },
  );
}

/// Unterpunkt „Höhenpunkte“ (Fachkonzept 3.2, M6-02): ohne Gefälle eine
/// Höhe für alle Eckpunkte, mit Gefälle je Eckpunkt A, B … – gemessen von
/// Oberkante Belag bis Boden, Vorgabe die Höhe der Terrassenart. Prüfung,
/// Aufbauhöhe und Hinweise kommen vom Server (`pruefeHoehen`). Mit Gefälle
/// lassen sich weitere Höhenreferenzpunkte einplanen (M7-04).
class HoehenpunkteWahl extends StatelessWidget {
  const HoehenpunkteWahl({
    required this.planung,
    required this.onGeaendert,
    this.berechnung,
    this.weitere,
    super.key,
  });

  /// Bedienung der weiteren Höhenreferenzpunkte; ohne sie keine.
  final HoehenpunktBedienung? weitere;

  final PlanungsSteuerung planung;

  /// Berechnung des Servers; ohne sie keine Aufbauhöhe und keine Hinweise.
  final BerechnungsSteuerung? berechnung;

  /// Meldet eine Änderung (Standardwert-Hinweis, M3-05).
  final VoidCallback onGeaendert;

  void _setze(Planungsstand stand) {
    planung.setze(stand);
    onGeaendert();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([planung, berechnung]),
    builder: (context, _) {
      final t = context.texte;
      final stand = planung.aktuell;
      final punkte = berechnung?.ergebnis?.hoehenpunkte;
      return Column(
        key: const ValueKey('hoehenpunkte'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.hoehenpunkteHilfe),
          Wrap(
            spacing: PlanerAbstand.klein,
            children: [
              for (final (name, mit, text) in [
                ('ohne', false, t.ohneGefaelle),
                ('mit', true, t.mitGefaelle),
              ])
                ChoiceChip(
                  key: ValueKey('gefaelle-$name'),
                  label: Text(text),
                  selected: stand.gefaelle == mit,
                  onSelected: (an) {
                    if (an) _setze(planung.aktuell.mitGefaelle(mit));
                  },
                ),
            ],
          ),
          if (stand.gefaelle)
            for (final (i, hoehe) in stand.hoehen.indexed)
              CmFeld(
                key: ValueKey('hoehe-$i'),
                titel: ZeichnungsMaler.punktname(i),
                wert: hoehe,
                gueltig: Planungsstand.hoeheGueltig,
                fehler: t.hoeheUngueltig,
                onGeaendert: (mm) => _setze(planung.aktuell.mitEckhoehe(i, mm)),
              )
          else
            CmFeld(
              key: const ValueKey('hoehe-alle'),
              titel: t.hoeheAlle,
              wert: stand.alleHoehe,
              gueltig: Planungsstand.hoeheGueltig,
              fehler: t.hoeheUngueltig,
              onGeaendert: (mm) => _setze(planung.aktuell.mitHoehe(mm)),
            ),
          // offene Freiform: noch keine Fläche für weitere Punkte
          if (weitere case final w?
              when stand.gefaelle &&
                  (stand.seitenzahl > 0 || stand.grundriss is KreisGrundriss))
            HoehenpunktEingabe(bedienung: w),
          if (punkte?.aufbauhoehe case final a?)
            Padding(
              padding: const EdgeInsets.only(top: PlanerAbstand.klein),
              child: Text(t.aufbauhoehe(cmText(t, a))),
            ),
          if (punkte != null && punkte.gedreht)
            Hinweis(key: const ValueKey('uk-gedreht'), text: t.ukGedreht),
          if (punkte != null && punkte.korrigiert)
            Hinweis(
              key: const ValueKey('hoehe-korrigiert'),
              text: t.hoeheKorrigiert(cmText(t, punkte.mindesthoehe!)),
              warnung: true,
            ),
        ],
      );
    },
  );
}

/// Unterpunkt „Untergrund“ (Fachkonzept 3.5, M6-04): Schotter (Vorgabe),
/// Beton oder Bitumenabdichtung – nur Information für die Planer, ohne
/// Wirkung auf die Berechnung (R-C07). Jede Wahl ist ein Schritt für
/// Rückgängig/Wiederherstellen.
class UntergrundWahl extends StatelessWidget {
  const UntergrundWahl({
    required this.planung,
    required this.onGeaendert,
    super.key,
  });

  final PlanungsSteuerung planung;

  /// Meldet eine Änderung (Standardwert-Hinweis, M3-05).
  final VoidCallback onGeaendert;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: planung,
    builder: (context, _) {
      final t = context.texte;
      final gewaehlt = planung.aktuell.untergrund;
      return Column(
        key: const ValueKey('untergrund'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.untergrundFrage),
          Wrap(
            spacing: PlanerAbstand.klein,
            children: [
              for (final u in Untergrund.values)
                ChoiceChip(
                  key: ValueKey('untergrund-${u.name}'),
                  label: Text(untergrundText(t, u)),
                  selected: u == gewaehlt,
                  onSelected: (an) {
                    if (an) {
                      planung.setze(planung.aktuell.mitUntergrund(u));
                      onGeaendert();
                    }
                  },
                ),
            ],
          ),
          Hinweis(text: t.untergrundHinweis),
        ],
      );
    },
  );
}

/// Unterpunkt „Art der Terrassennutzung“ (Fachkonzept 3.6, M6-05): die fünf
/// Arten als Chips (Vorgabe schwimmende Verlegung) und bei schwimmender
/// Verlegung die Warnung zur Verwindung ohne Bodenbefestigung. Das Holz für
/// Rahmen, zweite Lage und Leiterverband rechnet der Server
/// (`ukZusatz`); es steht in Material- und Stückliste. Bei Hochterrasse und
/// vorhandener UK gibt es den Unterpunkt nicht (M6-01).
class NutzungsartWahl extends StatelessWidget {
  const NutzungsartWahl({
    required this.planung,
    required this.onGeaendert,
    super.key,
  });

  final PlanungsSteuerung planung;

  /// Meldet eine Änderung (Standardwert-Hinweis, M3-05).
  final VoidCallback onGeaendert;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: planung,
    builder: (context, _) {
      final t = context.texte;
      final gewaehlt = planung.aktuell.nutzungsart;
      return Column(
        key: const ValueKey('nutzungsart'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: PlanerAbstand.klein,
            children: [
              for (final art in Nutzungsart.values)
                ChoiceChip(
                  key: ValueKey('nutzungsart-${art.name}'),
                  label: Text(nutzungsartText(t, art)),
                  selected: art == gewaehlt,
                  onSelected: (an) {
                    if (an) {
                      planung.setze(planung.aktuell.mitNutzungsart(art));
                      onGeaendert();
                    }
                  },
                ),
            ],
          ),
          if (gewaehlt.verwindungsgefahr)
            Hinweis(
              key: const ValueKey('verwindung'),
              text: t.nutzungsartVerwindung,
              warnung: true,
            ),
        ],
      );
    },
  );
}

/// Unterpunkt „Querstreben“ (Fachkonzept 3.7, M6-06): „Möchten Sie
/// zusätzliche Querstreben hinzufügen?“ mit Nein (Vorgabe) und Ja; mit Ja
/// das Feld „Anzahl der Quertraversen“ – leer bzw. „Automatisch“ rechnet der
/// Server mit 60 cm Abstand (R-C03), eine eingegebene Zahl gilt fest. Die
/// Querstreben erscheinen in der Zeichnung (Ebene UK) und in Material- und
/// Stückliste. Jede Eingabe ist ein Schritt für Rückgängig/Wiederherstellen.
class QuerstrebenWahl extends StatelessWidget {
  const QuerstrebenWahl({
    required this.planung,
    required this.onGeaendert,
    this.berechnung,
    super.key,
  });

  final PlanungsSteuerung planung;

  /// Berechnung des Servers für die wirksame Anzahl der Reihen.
  final BerechnungsSteuerung? berechnung;

  /// Meldet eine Änderung (Standardwert-Hinweis, M3-05).
  final VoidCallback onGeaendert;

  void _setze(Planungsstand stand) {
    planung.setze(stand);
    onGeaendert();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([planung, berechnung]),
    builder: (context, _) {
      final t = context.texte;
      final stand = planung.aktuell;
      final reihen = berechnung?.ergebnis?.querstrebenReihen;
      return Column(
        key: const ValueKey('querstreben'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.querstrebenFrage),
          Wrap(
            spacing: PlanerAbstand.klein,
            children: [
              for (final (name, mit, text) in [
                ('nein', false, t.nein),
                ('ja', true, t.ja),
              ])
                ChoiceChip(
                  key: ValueKey('querstreben-$name'),
                  label: Text(text),
                  selected: stand.querstreben == mit,
                  onSelected: (an) {
                    if (an) _setze(planung.aktuell.mitQuerstreben(mit));
                  },
                ),
            ],
          ),
          if (stand.querstreben) ...[
            Text(t.querstrebenAbstand),
            Wrap(
              spacing: PlanerAbstand.klein,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  key: const ValueKey('querstreben-automatisch'),
                  label: Text(t.automatisch),
                  selected: stand.querstrebenReihen == null,
                  onSelected: (an) {
                    if (an) {
                      _setze(planung.aktuell.mitQuerstrebenReihen(null));
                    }
                  },
                ),
              ],
            ),
            AnzahlFeld(
              key: const ValueKey('querstreben-anzahl'),
              titel: t.querstrebenAnzahl,
              wert: stand.querstrebenReihen ?? reihen,
              gueltig: Planungsstand.querstrebenReihenGueltig,
              fehler: t.querstrebenAnzahlUngueltig,
              onGeaendert: (n) =>
                  _setze(planung.aktuell.mitQuerstrebenReihen(n)),
            ),
          ],
        ],
      );
    },
  );
}

/// Eingabefeld für eine ganze Zahl: der aktuelle Wert steht als Platzhalter
/// darin, Enter übernimmt eine gültige Eingabe, sonst erscheint [fehler].
class AnzahlFeld extends StatefulWidget {
  const AnzahlFeld({
    required this.titel,
    required this.wert,
    required this.gueltig,
    required this.fehler,
    required this.onGeaendert,
    super.key,
  });

  final String titel;

  /// Aktueller Wert; `null` = noch keiner bekannt.
  final int? wert;
  final bool Function(int anzahl) gueltig;
  final String fehler;
  final ValueChanged<int> onGeaendert;

  @override
  State<AnzahlFeld> createState() => _AnzahlFeldState();
}

class _AnzahlFeldState extends State<AnzahlFeld> {
  final _feld = TextEditingController();
  String? _fehler;

  @override
  void dispose() {
    _feld.dispose();
    super.dispose();
  }

  void _uebernimm(String text) {
    final n = int.tryParse(text.trim());
    if (n == null || !widget.gueltig(n)) {
      setState(() => _fehler = widget.fehler);
      return;
    }
    widget.onGeaendert(n);
    _feld.clear();
    setState(() => _fehler = null);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: PlanerAbstand.klein),
    child: TextField(
      key: const ValueKey('feld'),
      controller: _feld,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        isDense: true,
        border: const OutlineInputBorder(),
        labelText: widget.titel,
        hintText: widget.wert?.toString(),
        errorText: _fehler,
      ),
      onSubmitted: _uebernimm,
    ),
  );
}

/// Unterpunkt „Nutzung privat oder gewerblich“ (Fachkonzept 3.8, M6-07):
/// private Nutzung (Vorgabe) oder gewerbliche Nutzung; darunter die
/// Stellfüße, die das Regelwerk der Artikeldaten für die gewählte UK und
/// Nutzung vorsieht (Server, `Regelwerk.stellfuesse`). Jede Wahl ist ein
/// Schritt für Rückgängig/Wiederherstellen.
class GewerblichWahl extends StatelessWidget {
  const GewerblichWahl({
    required this.planung,
    required this.onGeaendert,
    this.berechnung,
    super.key,
  });

  final PlanungsSteuerung planung;

  /// Berechnung des Servers mit den Stellfüßen; ohne sie keine Liste.
  final BerechnungsSteuerung? berechnung;

  /// Meldet eine Änderung (Standardwert-Hinweis, M3-05).
  final VoidCallback onGeaendert;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([planung, berechnung]),
    builder: (context, _) {
      final t = context.texte;
      final gewerblich = planung.aktuell.gewerblich;
      final fuesse = berechnung?.ergebnis?.stellfuesse ?? const <Stellfuss>[];
      return Column(
        key: const ValueKey('nutzung'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: PlanerAbstand.klein,
            children: [
              for (final (name, wert, text) in [
                ('privat', false, t.nutzungPrivat),
                ('gewerblich', true, t.nutzungGewerblich),
              ])
                ChoiceChip(
                  key: ValueKey('nutzung-$name'),
                  label: Text(text),
                  selected: gewerblich == wert,
                  onSelected: (an) {
                    if (an) {
                      planung.setze(planung.aktuell.mitGewerblich(wert));
                      onGeaendert();
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: PlanerAbstand.klein),
          if (fuesse.isEmpty)
            Text(t.stellfuesseKeine, key: const ValueKey('stellfuesse-keine'))
          else ...[
            Text(t.stellfuesse),
            for (final f in fuesse)
              Text('• ${f.titel}', key: ValueKey('stellfuss-${f.nummer.wert}')),
          ],
        ],
      );
    },
  );
}

/// Unterpunkt „Auflagen“ (Fachkonzept 3.9, M6-08): mit Stelzfüßen oder
/// mit Stelzfüßen und Pads (Vorgabe); darunter der Abstand der Auflager
/// und ihre Höhenbereiche aus dem Regelwerk der UK, die mögliche Höhe und
/// die Meldungen zu den Höhengrenzen – alles vom Server (`Unterbau`). Bei
/// Hochterrasse und vorhandener UK ein Hinweis auf Stützen bzw.
/// Bodenanker. Darunter die Tabelle der Höhenzuordnung (M6-11): je
/// Auflager-Art die Anzahl und der Spalt unter der UK, dazu die Auflager
/// ohne passende Höhe. Jede Wahl ist ein Schritt für
/// Rückgängig/Wiederherstellen.
class AuflagenWahl extends StatelessWidget {
  const AuflagenWahl({
    required this.planung,
    required this.onGeaendert,
    this.berechnung,
    super.key,
  });

  final PlanungsSteuerung planung;

  /// Berechnung des Servers mit dem Unterbau; ohne sie nur die Wahl.
  final BerechnungsSteuerung? berechnung;

  /// Meldet eine Änderung (Standardwert-Hinweis, M3-05).
  final VoidCallback onGeaendert;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([planung, berechnung]),
    builder: (context, _) {
      final t = context.texte;
      final stand = planung.aktuell;
      final unterbau = berechnung?.ergebnis?.unterbau ?? Unterbau.leer;
      return Column(
        key: const ValueKey('auflagen'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: PlanerAbstand.klein,
            children: [
              for (final (auflagen, text) in [
                (Auflagen.stelzfuesse, t.auflagenStelzfuesse),
                (Auflagen.stelzfuesseUndPads, t.auflagenStelzfuesseUndPads),
              ])
                ChoiceChip(
                  key: ValueKey('auflagen-${auflagen.name}'),
                  label: Text(text),
                  selected: stand.auflagen == auflagen,
                  onSelected: (an) {
                    if (an) {
                      planung.setze(stand.mitAuflagen(auflagen));
                      onGeaendert();
                    }
                  },
                ),
            ],
          ),
          if (unterbau.auflagerabstand case final abstand?)
            Hinweis(
              key: const ValueKey('auflager-abstand'),
              text: t.auflagerAbstand(cmText(t, abstand)),
            ),
          ...switch (stand.terrassenart) {
            Terrassenart.hochterrasse => [
              Hinweis(text: t.auflagerHochterrasse),
            ],
            Terrassenart.vorhandeneUk => [
              Hinweis(text: t.auflagerVorhandeneUk),
            ],
            Terrassenart.normal => _bereiche(t, unterbau),
          },
          ..._zuordnung(t, unterbau),
        ],
      );
    },
  );

  /// Tabelle der Höhenzuordnung (M6-11) und Auflager ohne passende Höhe.
  List<Widget> _zuordnung(PlanerTexte t, Unterbau unterbau) {
    final ohne = unterbau.auflagerpunkte.where((p) => p.zeile == null).length;
    return [
      if (unterbau.zuordnung.isNotEmpty) ...[
        const SizedBox(height: PlanerAbstand.klein),
        Text(t.hoehenzuordnung, key: const ValueKey('hoehenzuordnung')),
        for (final z in unterbau.zuordnung)
          Text(
            '• ${t.hoehenzuordnungZeile(z.titel, z.anzahl, z.von.mm, z.bis.mm)}',
          ),
      ],
      if (ohne > 0)
        Hinweis(
          key: const ValueKey('auflager-ohne-hoehe'),
          warnung: true,
          text: t.auflagerOhneHoehe(ohne),
        ),
    ];
  }

  /// Höhenbereiche, mögliche Höhe und Meldungen der normalen Terrasse.
  List<Widget> _bereiche(PlanerTexte t, Unterbau unterbau) => [
    if (unterbau.auflager.isEmpty)
      Text(t.auflagerKeine, key: const ValueKey('auflager-keine'))
    else ...[
      const SizedBox(height: PlanerAbstand.klein),
      Text(t.auflagerListe),
      for (final a in unterbau.auflager)
        Text(
          '• ${a.pad ? t.auflagerPad(a.titel, a.bis.mm) : t.auflagerBereich(a.titel, a.von.mm, a.bis.mm)}',
        ),
    ],
    if ((unterbau.hoeheVon, unterbau.hoeheBis) case (final von?, final bis?))
      Hinweis(
        key: const ValueKey('auflager-hoehen'),
        text: t.auflagerHoehen(cmText(t, von), cmText(t, bis)),
      ),
    for (final m in unterbau.meldungen)
      Hinweis(
        key: ValueKey('auflager-${m.name}'),
        warnung: true,
        text: switch (m) {
          Auflagermeldung.unterMindesthoehe => t.auflagerUnter(
            cmText(t, unterbau.hoeheVon!),
          ),
          Auflagermeldung.ueberHoechsthoehe => t.auflagerUeber(
            cmText(t, unterbau.hoeheBis!),
          ),
        },
      ),
  ];
}

/// Unterpunkt „Maximale Feldbreite“ (Fachkonzept 3.10, M6-09):
/// „Automatisch“ (Vorgabe, die höchste erlaubte) oder eine der Feldbreiten,
/// die der Server für den Belag erlaubt (R-C01: Robinie 30, 35, 40 cm);
/// dazu der Hinweis zur Firmenregel und – wenn eine gespeicherte Wahl
/// darüber liegt – die Meldung, mit welcher Breite gerechnet wird. Dazu je
/// Rand-UK, die die Selbstkontrolle ergänzt hat, ein Hinweis (Planungsregeln
/// 3.4). Jede Wahl ist ein Schritt für Rückgängig/Wiederherstellen.
class FeldbreiteWahl extends StatelessWidget {
  const FeldbreiteWahl({
    required this.planung,
    required this.onGeaendert,
    this.berechnung,
    super.key,
  });

  final PlanungsSteuerung planung;

  /// Berechnung des Servers mit den wählbaren Feldbreiten.
  final BerechnungsSteuerung? berechnung;

  /// Meldet eine Änderung (Standardwert-Hinweis, M3-05).
  final VoidCallback onGeaendert;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([planung, berechnung]),
    builder: (context, _) {
      final t = context.texte;
      final stand = planung.aktuell;
      final unterbau = berechnung?.ergebnis?.unterbau ?? Unterbau.leer;
      void waehle(Millimeter? feldbreite) {
        planung.setze(stand.mitFeldbreite(feldbreite));
        onGeaendert();
      }

      return Column(
        key: const ValueKey('feldbreite'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (unterbau.feldbreiten.isEmpty)
            Text(t.feldbreiteOhneBelag, key: const ValueKey('feldbreite-leer'))
          else
            Wrap(
              spacing: PlanerAbstand.klein,
              children: [
                ChoiceChip(
                  key: const ValueKey('feldbreite-automatisch'),
                  label: Text(t.automatisch),
                  selected: stand.feldbreite == null,
                  onSelected: (an) {
                    if (an) waehle(null);
                  },
                ),
                for (final f in unterbau.feldbreiten)
                  ChoiceChip(
                    key: ValueKey('feldbreite-${f.mm}'),
                    label: Text(t.feldbreiteCm(cmText(t, f))),
                    selected: stand.feldbreite == f,
                    onSelected: (an) {
                      if (an) waehle(f);
                    },
                  ),
              ],
            ),
          Hinweis(text: t.feldbreiteHinweis),
          if ((unterbau.feldbreiteBegrenzt, unterbau.feldbreite) case (
            true,
            final wirksam?,
          ))
            Hinweis(
              key: const ValueKey('feldbreite-begrenzt'),
              warnung: true,
              text: t.feldbreiteBegrenzt(cmText(t, wirksam)),
            ),
          for (final (i, laenge) in unterbau.randErgaenzt.indexed)
            Hinweis(
              key: ValueKey('rand-uk-$i'),
              text: t.randUkErgaenzt(cmText(t, laenge)),
            ),
        ],
      );
    },
  );
}

/// Hinweis mit Symbol; als [warnung] in der Fehlerfarbe.
class Hinweis extends StatelessWidget {
  const Hinweis({required this.text, this.warnung = false, super.key});

  final String text;
  final bool warnung;

  @override
  Widget build(BuildContext context) {
    final farbe = warnung ? context.farben.error : context.farben.onSurface;
    return Padding(
      padding: const EdgeInsets.only(top: PlanerAbstand.klein),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warnung ? Icons.warning_amber : Icons.info_outline,
            color: farbe,
          ),
          const SizedBox(width: PlanerAbstand.klein),
          Expanded(
            child: Text(text, style: TextStyle(color: farbe)),
          ),
        ],
      ),
    );
  }
}

/// Eingabefeld in cm: der aktuelle Wert steht als Platzhalter darin, Enter
/// übernimmt eine gültige Eingabe, sonst erscheint [fehler].
class CmFeld extends StatefulWidget {
  const CmFeld({
    required this.titel,
    required this.wert,
    required this.gueltig,
    required this.fehler,
    required this.onGeaendert,
    super.key,
  });

  final String titel;

  /// Aktueller Wert.
  final Millimeter wert;

  /// Prüft eine Eingabe in mm.
  final bool Function(Millimeter mm) gueltig;

  /// Meldung bei ungültiger Eingabe.
  final String fehler;

  final ValueChanged<Millimeter> onGeaendert;

  @override
  State<CmFeld> createState() => _CmFeldState();
}

class _CmFeldState extends State<CmFeld> {
  final _feld = TextEditingController();
  String? _fehler;

  @override
  void dispose() {
    _feld.dispose();
    super.dispose();
  }

  void _uebernimm(String text) {
    final mm = cmAusText(text);
    if (mm == null || !widget.gueltig(mm)) {
      setState(() => _fehler = widget.fehler);
      return;
    }
    widget.onGeaendert(mm);
    _feld.clear();
    setState(() => _fehler = null);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    return Padding(
      padding: const EdgeInsets.only(top: PlanerAbstand.klein),
      child: TextField(
        key: const ValueKey('feld'),
        controller: _feld,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(),
          labelText: widget.titel,
          hintText: cmText(t, widget.wert),
          suffixText: 'cm',
          errorText: _fehler,
        ),
        onSubmitted: _uebernimm,
      ),
    );
  }
}

String terrassenartText(PlanerTexte t, Terrassenart a) => switch (a) {
  Terrassenart.normal => t.terrassenartNormal,
  Terrassenart.hochterrasse => t.terrassenartHochterrasse,
  Terrassenart.vorhandeneUk => t.terrassenartVorhandeneUk,
};

String untergrundText(PlanerTexte t, Untergrund u) => switch (u) {
  Untergrund.schotter => t.untergrundSchotter,
  Untergrund.beton => t.untergrundBeton,
  Untergrund.bitumen => t.untergrundBitumen,
};

String nutzungsartText(PlanerTexte t, Nutzungsart a) => switch (a) {
  Nutzungsart.schwimmend => t.nutzungsartSchwimmend,
  Nutzungsart.versteifungOhneRahmen => t.nutzungsartVersteifungOhneRahmen,
  Nutzungsart.rahmen => t.nutzungsartRahmen,
  Nutzungsart.versteifungMitRahmen => t.nutzungsartVersteifungMitRahmen,
  Nutzungsart.doppelteUk => t.nutzungsartDoppelteUk,
};
