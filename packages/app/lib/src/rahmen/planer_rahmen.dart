import 'package:flutter/material.dart';

import '../design/planer_design.dart';
import 'planer_schritt.dart';
import 'rahmen_zustand.dart';
import 'steuerung.dart';
import 'zeichenflaeche.dart';

/// Rahmen der Planer-Oberfläche (M3-01): Kopfzeile, Schrittleiste,
/// Bearbeitungsmenü, Zeichenfläche mit Kennzahlen und Statuszeile.
class PlanerRahmen extends StatefulWidget {
  const PlanerRahmen({
    required this.status,
    super.key,
    this.zustand,
    this.planung,
    this.ansicht,
  });

  /// Inhalt der Statuszeile (z. B. Verbindung zum Server).
  final Widget status;

  /// Von außen vorgegebener Zustand (Tests); sonst ein eigener.
  final RahmenZustand? zustand;
  final PlanungsSteuerung? planung;
  final AnsichtSteuerung? ansicht;

  static const titel = 'TERRASSENKONFIGURATOR';

  @override
  State<PlanerRahmen> createState() => _PlanerRahmenState();
}

class _PlanerRahmenState extends State<PlanerRahmen> {
  late final RahmenZustand _zustand = widget.zustand ?? RahmenZustand();
  late final PlanungsSteuerung _planung = widget.planung ?? PlanungsSteuerung();
  late final AnsichtSteuerung _ansicht = widget.ansicht ?? AnsichtSteuerung();

  @override
  void dispose() {
    if (widget.planung == null) _planung.dispose();
    if (widget.ansicht == null) _ansicht.dispose();
    super.dispose();
  }

  Future<void> _zuruecksetzen() async {
    final bestaetigt = await showDialog<bool>(
      context: context,
      builder: (_) => const ZuruecksetzenDialog(),
    );
    if (bestaetigt ?? false) {
      _planung.zuruecksetzen();
      _ansicht.zentriere();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListenableBuilder(
      listenable: _zustand,
      builder: (context, _) => LayoutBuilder(
        builder: (context, raum) {
          final desktop = PlanerLayout.istDesktop(raum.maxWidth);
          final menuOffen = _zustand.menuOffen(desktop: desktop);
          final menu = Bearbeitungsmenue(zustand: _zustand);
          return Column(
            children: [
              Kopfzeile(onZuruecksetzen: _zuruecksetzen),
              Schrittleiste(zustand: _zustand),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (menuOffen && desktop) menu,
                    MenuGriff(
                      offen: menuOffen,
                      onTap: () => _zustand.schalteMenu(desktop: desktop),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Zeichenflaeche(
                              planung: _planung,
                              ansicht: _ansicht,
                            ),
                          ),
                          const Positioned(
                            top: PlanerAbstand.mittel,
                            right: PlanerAbstand.mittel,
                            child: Kennzahlen(),
                          ),
                          // Tablet: Menü liegt über der Zeichenfläche.
                          if (menuOffen && !desktop)
                            Positioned(
                              top: 0,
                              bottom: 0,
                              left: 0,
                              child: Material(elevation: 8, child: menu),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Statuszeile(child: widget.status),
            ],
          );
        },
      ),
    ),
  );
}

/// Kopfzeile mit Logo und Titel.
class Kopfzeile extends StatelessWidget {
  const Kopfzeile({required this.onZuruecksetzen, super.key});

  final VoidCallback onZuruecksetzen;

  static const zuruecksetzen = 'ZURÜCKSETZEN';

  static const logo = 'assets/bilder/robinienwelt_logo.png';

  @override
  Widget build(BuildContext context) => Container(
    height: 64,
    padding: const EdgeInsets.symmetric(horizontal: PlanerAbstand.mittel),
    decoration: const BoxDecoration(
      color: PlanerFarben.weiss,
      border: Border(bottom: BorderSide(color: PlanerFarben.linie)),
    ),
    child: Row(
      children: [
        Image.asset(logo, height: 48, semanticLabel: 'RobinienWelt'),
        const SizedBox(width: PlanerAbstand.mittel),
        Text(
          PlanerRahmen.titel,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: PlanerFarben.braun,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
          ),
        ),
        const Spacer(),
        TextButton.icon(
          key: const ValueKey('zuruecksetzen'),
          onPressed: onZuruecksetzen,
          icon: const Icon(Icons.restart_alt),
          label: const Text(zuruecksetzen),
        ),
      ],
    ),
  );
}

/// Schrittleiste mit sieben Stationen und Fortschritt.
class Schrittleiste extends StatelessWidget {
  const Schrittleiste({required this.zustand, super.key});

  final RahmenZustand zustand;

  @override
  Widget build(BuildContext context) => Container(
    color: PlanerFarben.sand,
    padding: const EdgeInsets.symmetric(vertical: PlanerAbstand.klein),
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final schritt in PlanerSchritt.values)
              Expanded(
                child: Station(
                  schritt: schritt,
                  aktiv: schritt == zustand.aktiv,
                  besucht: zustand.besucht.contains(schritt),
                  onTap: () => zustand.waehle(schritt),
                ),
              ),
          ],
        ),
        const SizedBox(height: PlanerAbstand.klein),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PlanerAbstand.mittel),
          child: LinearProgressIndicator(
            value: zustand.fortschritt,
            color: PlanerFarben.gruen,
            backgroundColor: PlanerFarben.linie,
            semanticsLabel: 'Fortschritt',
          ),
        ),
      ],
    ),
  );
}

/// Eine Station der Schrittleiste.
class Station extends StatelessWidget {
  const Station({
    required this.schritt,
    required this.aktiv,
    required this.besucht,
    required this.onTap,
    super.key,
  });

  final PlanerSchritt schritt;
  final bool aktiv;
  final bool besucht;
  final VoidCallback onTap;

  /// Unter dieser Breite (px) werden lange Titel getrennt.
  static const schmalUnter = 160.0;

  @override
  Widget build(BuildContext context) => InkWell(
    key: ValueKey('station-${schritt.name}'),
    onTap: onTap,
    child: Semantics(
      button: true,
      selected: aktiv,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: aktiv
                  ? PlanerFarben.gruen
                  : besucht
                  ? PlanerFarben.braun
                  : PlanerFarben.linie,
              child: Text(
                '${schritt.nummer}',
                style: const TextStyle(color: PlanerFarben.weiss, fontSize: 13),
              ),
            ),
            const SizedBox(height: 4),
            LayoutBuilder(
              builder: (context, raum) => Text(
                raum.maxWidth < Station.schmalUnter
                    ? schritt.getrennterTitel
                    : schritt.titel,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: aktiv ? FontWeight.w700 : FontWeight.w400,
                  color: PlanerFarben.text,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Nummeriertes Bearbeitungsmenü: je Schritt ein Abschnitt, der aktive ist
/// aufgeklappt und zeigt seine Unterpunkte.
class Bearbeitungsmenue extends StatelessWidget {
  const Bearbeitungsmenue({required this.zustand, super.key});

  final RahmenZustand zustand;

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const ValueKey('bearbeitungsmenue'),
    width: PlanerLayout.menuBreite,
    child: Material(
      color: PlanerFarben.weiss,
      child: ListView(
        children: [
          for (final schritt in PlanerSchritt.values) ...[
            ListTile(
              key: ValueKey('menu-${schritt.name}'),
              selected: schritt == zustand.aktiv,
              selectedColor: PlanerFarben.braun,
              title: Text(
                '${schritt.nummer}. ${schritt.titel}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              trailing: Icon(
                schritt == zustand.aktiv
                    ? Icons.expand_less
                    : Icons.expand_more,
              ),
              onTap: () => zustand.waehle(schritt),
            ),
            if (schritt == zustand.aktiv)
              for (final punkt in schritt.nummerierteUnterpunkte)
                Padding(
                  padding: const EdgeInsets.only(
                    left: PlanerAbstand.gross,
                    right: PlanerAbstand.mittel,
                    bottom: PlanerAbstand.klein,
                  ),
                  child: Text(punkt),
                ),
            const Divider(height: 1),
          ],
        ],
      ),
    ),
  );
}

/// Grüner Griff zum Ein- und Ausklappen des Menüs.
class MenuGriff extends StatelessWidget {
  const MenuGriff({required this.offen, required this.onTap, super.key});

  final bool offen;
  final VoidCallback onTap;

  static const einklappen = 'Menü einklappen';
  static const ausklappen = 'Menü ausklappen';

  @override
  Widget build(BuildContext context) => Material(
    color: PlanerFarben.gruen,
    child: InkWell(
      key: const ValueKey('menu-griff'),
      onTap: onTap,
      child: SizedBox(
        width: 20,
        child: Icon(
          offen ? Icons.chevron_left : Icons.chevron_right,
          color: PlanerFarben.weiss,
          semanticLabel: offen ? einklappen : ausklappen,
        ),
      ),
    ),
  );
}

/// Kennzahlen rechts oben: Fläche und Volumen (Werte kommen ab M4/M5 vom
/// Server).
class Kennzahlen extends StatelessWidget {
  const Kennzahlen({super.key, this.flaeche, this.volumen});

  /// Fläche in m², `null` = noch nicht berechnet.
  final double? flaeche;

  /// Holzvolumen in m³, `null` = noch nicht berechnet.
  final double? volumen;

  static String zahl(double? wert, String einheit) => wert == null
      ? '– $einheit'
      : '${wert.toStringAsFixed(2).replaceAll('.', ',')} $einheit';

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('kennzahlen'),
    child: Padding(
      padding: const EdgeInsets.all(PlanerAbstand.klein),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('Fläche: ${zahl(flaeche, 'm²')}'),
          Text('Volumen: ${zahl(volumen, 'm³')}'),
        ],
      ),
    ),
  );
}

/// Statuszeile am unteren Rand.
class Statuszeile extends StatelessWidget {
  const Statuszeile({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    height: 28,
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: PlanerAbstand.mittel),
    decoration: const BoxDecoration(
      color: PlanerFarben.sand,
      border: Border(top: BorderSide(color: PlanerFarben.linie)),
    ),
    child: DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 12, color: PlanerFarben.text),
      child: child,
    ),
  );
}

/// Sicherheitsabfrage vor dem Zurücksetzen (Fachkonzept 08).
class ZuruecksetzenDialog extends StatelessWidget {
  const ZuruecksetzenDialog({super.key});

  static const titel = 'Planung zurücksetzen?';
  static const text =
      'Sind Sie sicher, dass Sie die Planung zurücksetzen möchten? Dadurch '
      'geht Ihr Fortschritt verloren. Stellen Sie sicher, dass Sie die '
      'Konfiguration gespeichert und die Konfigurationsnummer notiert haben.';
  static const zurueck = 'Zurück zur Konfiguration';
  static const bestaetigen = 'Konfiguration zurücksetzen';

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const ValueKey('zuruecksetzen-dialog'),
    title: const Text(titel),
    content: const Text(text),
    actions: [
      TextButton(
        key: const ValueKey('zuruecksetzen-abbrechen'),
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text(zurueck),
      ),
      FilledButton(
        key: const ValueKey('zuruecksetzen-bestaetigen'),
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
        onPressed: () => Navigator.of(context).pop(true),
        child: const Text(bestaetigen),
      ),
    ],
  );
}
