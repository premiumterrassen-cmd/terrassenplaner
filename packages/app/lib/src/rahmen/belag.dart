import 'package:flutter/material.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../artikel/artikelbild_widget.dart';
import '../design/planer_design.dart';
import '../sprache/sprache.dart';
import 'steuerung.dart';

/// Lädt die Belagauswahl vom Server (M5-01); in Tests austauschbar.
typedef BelaegeLaden = Future<Belagauswahl> Function();

/// Hält die Beläge des Servers mit ihren Preisen (M5-01). Die App rechnet
/// nichts selbst und merkt sich nichts dauerhaft.
class BelagQuelle extends ChangeNotifier {
  BelagQuelle(this.lade) {
    ladeNeu();
  }

  final BelaegeLaden lade;

  Belagauswahl? _auswahl;
  Object? _fehler;

  /// Geladene Beläge; `null`, solange nichts geladen ist.
  Belagauswahl? get auswahl => _auswahl;

  /// Fehler des letzten Ladens; `null`, wenn es gelang.
  Object? get fehler => _fehler;

  Future<void> ladeNeu() async {
    _fehler = null;
    notifyListeners();
    try {
      _auswahl = await lade();
    } on Object catch (fehler) {
      _fehler = fehler;
    }
    notifyListeners();
  }
}

/// Maße eines Artikels in mm: Länge(n) × Breite × Stärke.
String belagMasse(Artikel a) {
  final masse = [
    if (a.abmessungen.laengen.isNotEmpty)
      a.abmessungen.laengen.map((l) => l.mm).join('/'),
    ?a.abmessungen.breite?.mm,
    ?a.abmessungen.staerke?.mm,
  ];
  return '${masse.join(' × ')} mm';
}

/// Unterpunkt „Terrassenbelag auswählen“: gewählter Belag mit Bild, Name,
/// Maßen und Fuge und der Knopf „Produktauswahl“ (Fachkonzept 2.1).
class BelagAnzeige extends StatelessWidget {
  const BelagAnzeige({
    required this.quelle,
    required this.planung,
    required this.onGeaendert,
    super.key,
  });

  final BelagQuelle quelle;
  final PlanungsSteuerung planung;

  /// Meldet eine Änderung des Belags (Standardwert-Hinweis, M3-05).
  final VoidCallback onGeaendert;

  Future<void> _waehle(BuildContext context, Belagauswahl auswahl) async {
    final gewaehlt = await showDialog<Belagangebot>(
      context: context,
      builder: (_) => BelagDialog(
        auswahl: auswahl,
        gewaehlt: auswahl.gewaehlt(planung.aktuell.belag),
      ),
    );
    if (gewaehlt == null) return;
    planung.setze(planung.aktuell.mitBelag(gewaehlt.artikel.nummer));
    onGeaendert();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([quelle, planung]),
    builder: (context, _) {
      final t = context.texte;
      if (quelle.fehler != null) {
        return Row(
          children: [
            Expanded(child: Text(t.belagFehler)),
            TextButton(
              key: const ValueKey('belag-neu-laden'),
              onPressed: quelle.ladeNeu,
              child: Text(t.erneutVersuchen),
            ),
          ],
        );
      }
      final auswahl = quelle.auswahl;
      if (auswahl == null) return Text(t.belagLaedt);
      final belag = auswahl.gewaehlt(planung.aktuell.belag);
      if (belag == null) return Text(t.belagKeine);
      final a = belag.artikel;
      return Padding(
        key: const ValueKey('belag-anzeige'),
        padding: const EdgeInsets.symmetric(vertical: PlanerAbstand.klein),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Artikelbild(a, groesse: 64),
            const SizedBox(width: PlanerAbstand.mittel),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.titel,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(t.belagMasse(belagMasse(a))),
                  Text(t.belagFuge(fuge.mm)),
                  const SizedBox(height: PlanerAbstand.klein),
                  OutlinedButton(
                    key: const ValueKey('produktauswahl'),
                    onPressed: () => _waehle(context, auswahl),
                    child: Text(t.produktauswahl),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Dialog „Terrassenbelag auswählen“ (Fachkonzept 2.1): Kategorien, Filter
/// mit Mehrfachauswahl, Suche und Produktkarten. Ein Klick auf eine Karte
/// wählt den Belag.
class BelagDialog extends StatefulWidget {
  const BelagDialog({required this.auswahl, this.gewaehlt, super.key});

  final Belagauswahl auswahl;
  final Belagangebot? gewaehlt;

  @override
  State<BelagDialog> createState() => _BelagDialogState();
}

class _BelagDialogState extends State<BelagDialog> {
  var _filter = const Belagfilter();

  void _setze(Belagfilter filter) => setState(() => _filter = filter);

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    final auswahl = widget.auswahl;
    final treffer = auswahl.gefiltert(_filter);
    return Dialog(
      key: const ValueKey('belag-dialog'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960, maxHeight: 800),
        child: Padding(
          padding: const EdgeInsets.all(PlanerAbstand.gross),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                t.belagDialogTitel,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: PlanerAbstand.mittel),
              Wrap(
                spacing: PlanerAbstand.klein,
                children: [
                  for (final k in auswahl.kategorien)
                    ChoiceChip(
                      key: ValueKey('kategorie-${k.name}'),
                      label: Text(kategorieText(t, k)),
                      selected: _filter.kategorie == k,
                      onSelected: (an) => _setze(
                        an
                            ? _filter.kopie(kategorie: k)
                            : _filter.kopie(ohneKategorie: true),
                      ),
                    ),
                ],
              ),
              TextField(
                key: const ValueKey('belag-suche'),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  labelText: t.belagSuche,
                ),
                onChanged: (text) => _setze(_filter.kopie(suche: text)),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Filter(
                        name: 'material',
                        titel: t.filterMaterial,
                        werte: auswahl.serien,
                        text: (s) => s.name,
                        gewaehlt: _filter.serien,
                        onGeaendert: (s) => _setze(_filter.kopie(serien: s)),
                      ),
                      _Filter(
                        name: 'oberseite',
                        titel: t.filterOberseite,
                        werte: auswahl.oberseiten,
                        text: (o) => oberseiteText(t, o),
                        gewaehlt: _filter.oberseiten,
                        onGeaendert: (o) =>
                            _setze(_filter.kopie(oberseiten: o)),
                      ),
                      _MassFilter(
                        name: 'breite',
                        titel: t.filterBreite,
                        werte: auswahl.breiten,
                        gewaehlt: _filter.breiten,
                        onGeaendert: (w) => _setze(_filter.kopie(breiten: w)),
                      ),
                      _MassFilter(
                        name: 'staerke',
                        titel: t.filterStaerke,
                        werte: auswahl.staerken,
                        gewaehlt: _filter.staerken,
                        onGeaendert: (w) => _setze(_filter.kopie(staerken: w)),
                      ),
                      _MassFilter(
                        name: 'laenge',
                        titel: t.filterLaenge,
                        werte: auswahl.laengen,
                        gewaehlt: _filter.laengen,
                        onGeaendert: (w) => _setze(_filter.kopie(laengen: w)),
                      ),
                      const Divider(),
                      if (treffer.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(PlanerAbstand.mittel),
                          child: Text(t.belagKeinTreffer),
                        ),
                      for (final b in treffer)
                        Belagkarte(
                          angebot: b,
                          gewaehlt: b.artikel == widget.gewaehlt?.artikel,
                          onTap: () => Navigator.of(context).pop(b),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: PlanerAbstand.mittel),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: const ValueKey('filter-zuruecksetzen'),
                    onPressed: () => _setze(const Belagfilter()),
                    child: Text(t.filterZuruecksetzen),
                  ),
                  FilledButton(
                    key: const ValueKey('zurueck-zur-konfiguration'),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(t.zurueckZurKonfiguration),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mehrfachauswahl eines Merkmals als Filterchips.
class _Filter<T> extends StatelessWidget {
  const _Filter({
    required this.name,
    required this.titel,
    required this.werte,
    required this.text,
    required this.gewaehlt,
    required this.onGeaendert,
  });

  final String name;
  final String titel;
  final List<T> werte;
  final String Function(T) text;
  final Set<T> gewaehlt;
  final ValueChanged<Set<T>> onGeaendert;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: PlanerAbstand.klein),
    child: Wrap(
      spacing: PlanerAbstand.klein,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(width: 96, child: Text(titel)),
        for (final w in werte)
          FilterChip(
            key: ValueKey('filter-$name-${text(w)}'),
            label: Text(text(w)),
            selected: gewaehlt.contains(w),
            onSelected: (an) =>
                onGeaendert(an ? {...gewaehlt, w} : ({...gewaehlt}..remove(w))),
          ),
      ],
    ),
  );
}

/// Mehrfachauswahl eines Maßes in mm.
class _MassFilter extends _Filter<Millimeter> {
  _MassFilter({
    required super.name,
    required super.titel,
    required super.werte,
    required super.gewaehlt,
    required super.onGeaendert,
  }) : super(text: (m) => '${m.mm} mm');
}

/// Produktkarte: Bild, Titel, Abmessungen, Preise und der Knopf für die
/// Infobox.
class Belagkarte extends StatelessWidget {
  const Belagkarte({
    required this.angebot,
    required this.gewaehlt,
    required this.onTap,
    super.key,
  });

  final Belagangebot angebot;
  final bool gewaehlt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    final a = angebot.artikel;
    return Card(
      key: ValueKey('belag-${a.nummer.wert}'),
      shape: gewaehlt
          ? RoundedRectangleBorder(
              side: const BorderSide(color: PlanerFarben.braun, width: 2),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(PlanerAbstand.mittel),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Artikelbild(a),
              const SizedBox(width: PlanerAbstand.mittel),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.titel,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    if (gewaehlt) Text(t.gewaehlt),
                    Text(t.abmessungen(belagMasse(a))),
                    ...preisZeilen(t, angebot),
                  ],
                ),
              ),
              IconButton(
                key: ValueKey('info-${a.nummer.wert}'),
                tooltip: t.artikelinfo,
                icon: const Icon(Icons.info_outline),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => BelagInfo(angebot: angebot),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Infobox eines Belags: Artikelinfo, Abbildungen (Ober-/Unterseite,
/// Stirnseite), Abmessungen, Preise und Artikelnummer.
class BelagInfo extends StatelessWidget {
  const BelagInfo({required this.angebot, super.key});

  final Belagangebot angebot;

  @override
  Widget build(BuildContext context) {
    final t = context.texte;
    final a = angebot.artikel;
    return AlertDialog(
      key: const ValueKey('belag-info'),
      title: Text(a.titel),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: PlanerAbstand.klein,
              children: [
                if (a.bilder.isEmpty) Artikelbild(a, groesse: 160),
                for (final (i, _) in a.bilder.indexed)
                  Artikelbild(a, groesse: 160, nummer: i),
              ],
            ),
            const SizedBox(height: PlanerAbstand.mittel),
            if (a.holzart case final h?)
              Text(t.materialAngabe('${h.name} ${a.serie!.name}')),
            if (a.profil case final p?) Text(t.profilAngabe(profilText(t, p))),
            if (a.oberseite case final o?)
              Text(t.oberseiteAngabe(oberseiteText(t, o))),
            Text(t.abmessungen(belagMasse(a))),
            ...preisZeilen(t, angebot),
            Text(t.artikelnummer(a.nummer.wert)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).closeButtonLabel),
        ),
      ],
    );
  }
}

/// Preis je lfm und je m², soweit der Server sie berechnen konnte.
List<Widget> preisZeilen(PlanerTexte t, Belagangebot b) => [
  if (b.preisJeLfm case final p?) Text(t.preisJeLfm(p.anzeige)),
  if (b.preisJeM2 case final p?) Text(t.preisJeM2(p.anzeige)),
];

String kategorieText(PlanerTexte t, Belagkategorie k) => switch (k) {
  Belagkategorie.unsichtbar => t.belagUnsichtbar,
  Belagkategorie.sichtbar => t.belagSichtbar,
  Belagkategorie.holzfliese => t.belagHolzfliese,
};

String oberseiteText(PlanerTexte t, Oberseite o) => switch (o) {
  Oberseite.glatt => t.oberseiteGlatt,
  Oberseite.bombiert => t.oberseiteBombiert,
};

String profilText(PlanerTexte t, Profil p) => switch (p) {
  Profil.genutet => t.profilGenutet,
  Profil.glattkant => t.profilGlattkant,
};
