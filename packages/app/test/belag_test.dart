import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/artikel/artikelbild_widget.dart';
import 'package:terrassenplaner_app/src/design/planer_design.dart';
import 'package:terrassenplaner_app/src/rahmen/belag.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_rahmen.dart';
import 'package:terrassenplaner_app/src/rahmen/planer_schritt.dart';
import 'package:terrassenplaner_app/src/rahmen/rahmen_zustand.dart';
import 'package:terrassenplaner_app/src/rahmen/steuerung.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import 'hilfe.dart';

Artikel _diele(
  String nummer,
  String titel, {
  Serie serie = premiumSelect,
  Profil profil = Profil.genutet,
  Oberseite oberseite = Oberseite.bombiert,
  int breite = 60,
  int staerke = 22,
  List<int> laengen = const [3000, 4000],
  List<String> bilder = const [],
}) => Artikel(
  nummer: Artikelnummer(nummer),
  titel: titel,
  art: Artikelart.diele,
  einheit: Verkaufseinheit(Mengeneinheit.laufmeter),
  abmessungen: Abmessungen(
    breite: Millimeter(breite),
    staerke: Millimeter(staerke),
    laengen: [for (final l in laengen) Millimeter(l)],
  ),
  holzart: robinie,
  serie: serie,
  profil: profil,
  oberseite: oberseite,
  bilder: bilder,
);

final _vorgabe = Belagangebot(
  _diele('10-10-060-R', 'Diele genutet 60', bilder: ['a.jpg', 'b.jpg']),
  preisJeLfm: const Cent(1250),
  preisJeM2: const Cent(19231),
);
final _glattkant = Belagangebot(
  _diele(
    '10-20-100',
    'Diele glattkant 100',
    serie: basic,
    profil: Profil.glattkant,
    oberseite: Oberseite.glatt,
    breite: 100,
    staerke: 26,
    laengen: [5000],
  ),
);
final _fliese = Belagangebot(
  Artikel(
    nummer: const Artikelnummer('70-10-001'),
    titel: 'Terrassenfliese',
    art: Artikelart.holzfliese,
    einheit: Verkaufseinheit(Mengeneinheit.stueck),
  ),
  preisJeM2: const Cent(5446),
);
final _auswahl = Belagauswahl('v1', [_vorgabe, _glattkant, _fliese]);

void main() {
  group('BelagQuelle', () {
    test('lädt beim Anlegen, Fehler und erneutes Laden', () async {
      var versuche = 0;
      final quelle = BelagQuelle(() async {
        versuche++;
        if (versuche == 1) throw StateError('weg');
        return _auswahl;
      });
      addTearDown(quelle.dispose);
      var meldungen = 0;
      quelle.addListener(() => meldungen++);
      expect(quelle.auswahl, isNull);
      await pumpEventQueue();
      expect(quelle.fehler, isA<StateError>());
      expect(quelle.auswahl, isNull);
      expect(meldungen, 1);
      final laden = quelle.ladeNeu();
      expect(quelle.fehler, isNull);
      expect(meldungen, 2);
      await laden;
      expect(quelle.auswahl, _auswahl);
      expect(meldungen, 3);
    });
  });

  test('Maße: Längen × Breite × Stärke in mm', () {
    expect(belagMasse(_vorgabe.artikel), '3000/4000 × 60 × 22 mm');
    expect(belagMasse(_fliese.artikel), ' mm');
    expect(
      belagMasse(
        Artikel(
          nummer: const Artikelnummer('1'),
          titel: 'x',
          art: Artikelart.holzfliese,
          einheit: Verkaufseinheit(Mengeneinheit.stueck),
          abmessungen: Abmessungen(
            breite: const Millimeter(606),
            laengen: [const Millimeter(606)],
          ),
        ),
      ),
      '606 × 606 mm',
    );
  });

  group('Belaganzeige', () {
    Future<({PlanungsSteuerung planung, List<int> geaendert})> zeige(
      WidgetTester tester,
      BelagQuelle quelle,
    ) async {
      final planung = PlanungsSteuerung();
      addTearDown(planung.dispose);
      addTearDown(quelle.dispose);
      final geaendert = <int>[];
      await tester.pumpWidget(
        testApp(
          theme: planerThema(),
          home: Scaffold(
            body: BelagAnzeige(
              quelle: quelle,
              planung: planung,
              onGeaendert: () => geaendert.add(1),
            ),
          ),
        ),
      );
      return (planung: planung, geaendert: geaendert);
    }

    testWidgets('lädt, dann Vorgabe mit Maßen und Fuge', (tester) async {
      final fertig = Completer<Belagauswahl>();
      await zeige(tester, BelagQuelle(() => fertig.future));
      expect(find.text(de.belagLaedt), findsOneWidget);
      fertig.complete(_auswahl);
      await tester.pumpAndSettle();
      expect(find.text('Diele genutet 60'), findsOneWidget);
      expect(find.text('Maße: 3000/4000 × 60 × 22 mm'), findsOneWidget);
      expect(find.text('Fuge: 5 mm'), findsOneWidget);
      expect(find.text('Produktauswahl'), findsOneWidget);
      expect(tester.widget<Artikelbild>(find.byType(Artikelbild)).groesse, 64);
    });

    testWidgets('keine Beläge in den Artikeldaten', (tester) async {
      await zeige(tester, BelagQuelle(() async => Belagauswahl('v0', [])));
      await tester.pumpAndSettle();
      expect(find.text(de.belagKeine), findsOneWidget);
    });

    testWidgets('Fehler mit „Erneut versuchen“', (tester) async {
      var versuche = 0;
      await zeige(
        tester,
        BelagQuelle(() async {
          if (versuche++ == 0) throw StateError('weg');
          return _auswahl;
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text(de.belagFehler), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('belag-neu-laden')));
      await tester.pumpAndSettle();
      expect(find.text('Diele genutet 60'), findsOneWidget);
    });

    testWidgets('Produktauswahl: Karte wählt den Belag', (tester) async {
      tester.view
        ..physicalSize = const Size(1440, 1400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = await zeige(tester, BelagQuelle(() async => _auswahl));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('produktauswahl')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('belag-dialog')), findsOneWidget);
      expect(find.text(de.belagDialogTitel), findsOneWidget);
      // die Vorgabe ist markiert
      expect(find.text(de.gewaehlt), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('belag-10-20-100')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('belag-dialog')), findsNothing);
      expect(s.planung.aktuell.belag, const Artikelnummer('10-20-100'));
      expect(s.planung.kannRueckgaengig, isTrue);
      expect(s.geaendert, [1]);
      expect(find.text('Diele glattkant 100'), findsOneWidget);
      expect(find.text('Maße: 5000 × 100 × 26 mm'), findsOneWidget);

      // „Zurück zur Konfiguration“ ändert nichts
      await tester.tap(find.byKey(const ValueKey('produktauswahl')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('zurueck-zur-konfiguration')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('belag-dialog')), findsNothing);
      expect(s.planung.aktuell.belag, const Artikelnummer('10-20-100'));
      expect(s.geaendert, [1]);
    });
  });

  group('Dialog „Terrassenbelag auswählen“', () {
    Future<void> zeige(WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(1440, 1400)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testApp(
          theme: planerThema(),
          home: Scaffold(body: BelagDialog(auswahl: _auswahl)),
        ),
      );
    }

    bool sichtbar(String nummer) =>
        find.byKey(ValueKey('belag-$nummer')).evaluate().isNotEmpty;

    List<bool> karten() => [
      sichtbar('10-10-060-R'),
      sichtbar('10-20-100'),
      sichtbar('70-10-001'),
    ];

    testWidgets('Karten mit Abmessungen und Preisen', (tester) async {
      await zeige(tester);
      expect(karten(), [true, true, true]);
      expect(find.text(de.gewaehlt), findsNothing);
      expect(find.text('Abmessungen: 3000/4000 × 60 × 22 mm'), findsOneWidget);
      expect(find.text('Preis je lfm: 12,50 € inkl. MwSt.'), findsOneWidget);
      expect(find.text('Preis je m²: 192,31 € inkl. MwSt.'), findsOneWidget);
      expect(find.text('Preis je m²: 54,46 € inkl. MwSt.'), findsOneWidget);
      expect(find.textContaining('Preis je lfm'), findsOneWidget);
    });

    testWidgets('Kategorien: wählen und wieder abwählen', (tester) async {
      await zeige(tester);
      for (final (k, text) in [
        ('unsichtbar', 'Unsichtbar befestigt'),
        ('sichtbar', 'Sichtbar befestigt'),
        ('holzfliese', 'Holzfliese'),
      ]) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('kategorie-$k')),
            matching: find.text(text),
          ),
          findsOneWidget,
        );
      }
      await tester.tap(find.byKey(const ValueKey('kategorie-sichtbar')));
      await tester.pump();
      expect(karten(), [false, true, false]);
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('kategorie-sichtbar')),
            )
            .selected,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('kategorie-holzfliese')));
      await tester.pump();
      expect(karten(), [false, false, true]);
      await tester.tap(find.byKey(const ValueKey('kategorie-holzfliese')));
      await tester.pump();
      expect(karten(), [true, true, true]);
    });

    testWidgets('Filter mit Mehrfachauswahl', (tester) async {
      await zeige(tester);
      Future<void> tippe(String schluessel) async {
        await tester.tap(find.byKey(ValueKey('filter-$schluessel')));
        await tester.pump();
      }

      expect(find.text(de.filterMaterial), findsOneWidget);
      await tippe('material-BASIC');
      expect(karten(), [false, true, false]);
      await tippe('material-PREMIUM SELECT');
      expect(karten(), [true, true, false]);
      expect(
        tester
            .widget<FilterChip>(
              find.byKey(const ValueKey('filter-material-BASIC')),
            )
            .selected,
        isTrue,
      );
      await tippe('material-BASIC');
      expect(karten(), [true, false, false]);
      await tippe('material-PREMIUM SELECT');
      expect(karten(), [true, true, true]);

      await tippe('oberseite-glatt');
      expect(karten(), [false, true, false]);
      await tippe('oberseite-glatt');
      expect(find.byKey(const ValueKey('filter-oberseite-bombiert')), findsOne);

      await tippe('breite-60 mm');
      expect(karten(), [true, false, false]);
      await tippe('breite-60 mm');
      await tippe('staerke-26 mm');
      expect(karten(), [false, true, false]);
      await tippe('staerke-26 mm');
      await tippe('laenge-3000 mm');
      expect(karten(), [true, false, false]);
      await tippe('laenge-5000 mm');
      expect(karten(), [true, true, false]);
      await tippe('laenge-3000 mm');
      await tippe('laenge-5000 mm');
      expect(karten(), [true, true, true]);
    });

    testWidgets('Suche und „Filter zurücksetzen“', (tester) async {
      await zeige(tester);
      await tester.enterText(
        find.byKey(const ValueKey('belag-suche')),
        'fliese',
      );
      await tester.pump();
      expect(karten(), [false, false, true]);
      await tester.enterText(
        find.byKey(const ValueKey('belag-suche')),
        'gibt es nicht',
      );
      await tester.pump();
      expect(karten(), [false, false, false]);
      expect(find.text(de.belagKeinTreffer), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('kategorie-sichtbar')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('filter-zuruecksetzen')));
      await tester.pump();
      // die Suche bleibt im Feld stehen, der Filter ist leer
      expect(karten(), [true, true, true]);
      expect(find.text(de.belagKeinTreffer), findsNothing);
    });

    testWidgets('Infobox mit allen Feldern', (tester) async {
      await zeige(tester);
      await tester.tap(find.byKey(const ValueKey('info-10-10-060-R')));
      await tester.pumpAndSettle();
      final info = find.byKey(const ValueKey('belag-info'));
      expect(info, findsOneWidget);
      Finder inInfo(String text) =>
          find.descendant(of: info, matching: find.text(text));
      for (final text in [
        'Diele genutet 60',
        'Material: Robinie PREMIUM SELECT',
        'Profil: genutet',
        'Oberseite: bombiert',
        'Abmessungen: 3000/4000 × 60 × 22 mm',
        'Preis je lfm: 12,50 € inkl. MwSt.',
        'Preis je m²: 192,31 € inkl. MwSt.',
        'Artikelnummer: 10-10-060-R',
      ]) {
        expect(inInfo(text), findsOneWidget, reason: text);
      }
      final bilder = tester
          .widgetList<Artikelbild>(
            find.descendant(of: info, matching: find.byType(Artikelbild)),
          )
          .map((b) => (b.nummer, b.groesse));
      expect(bilder, [(0, 160), (1, 160)]);
      await tester.tap(
        find.descendant(of: info, matching: find.byType(TextButton)),
      );
      await tester.pumpAndSettle();
      expect(info, findsNothing);
      // Info öffnen wählt nichts aus: der Dialog bleibt offen
      expect(karten(), [true, true, true]);
    });

    testWidgets('Infobox ohne Holzangaben und ohne Bild', (tester) async {
      await zeige(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('info-70-10-001')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('info-70-10-001')));
      await tester.pumpAndSettle();
      final info = find.byKey(const ValueKey('belag-info'));
      expect(
        find.descendant(of: info, matching: find.textContaining('Material')),
        findsNothing,
      );
      expect(
        find.descendant(of: info, matching: find.textContaining('Profil')),
        findsNothing,
      );
      expect(
        find.descendant(of: info, matching: find.textContaining('Oberseite')),
        findsNothing,
      );
      expect(
        find.descendant(of: info, matching: find.byType(Artikelbild)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: info,
          matching: find.text('Artikelnummer: 70-10-001'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('Texte auf Englisch', (tester) async {
      expect(en.produktauswahl, 'Product selection');
      expect(kategorieText(en, Belagkategorie.holzfliese), 'Wood tile');
      expect(oberseiteText(en, Oberseite.bombiert), 'convex');
      expect(profilText(en, Profil.glattkant), 'square edge');
    });
  });

  testWidgets('im Rahmen: Unterpunkt „Terrassenbelag auswählen“', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(1440, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final zustand = RahmenZustand();
    await tester.pumpWidget(
      testApp(
        theme: planerThema(),
        home: PlanerRahmen(
          status: const Text('Status'),
          zustand: zustand,
          belaege: () async => _auswahl,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('belag-anzeige')), findsNothing);
    zustand.waehle(PlanerSchritt.terrassenbelag);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('belag-anzeige')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('produktauswahl')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('belag-70-10-001')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('belag-70-10-001')));
    await tester.pumpAndSettle();
    expect(find.text('Terrassenfliese'), findsOneWidget);
    expect(zustand.unveraendert, isNot(contains(PlanerSchritt.terrassenbelag)));
    // Ohne Belagquelle zeigt der Schritt nur seine Unterpunkte.
    await tester.pumpWidget(
      testApp(
        theme: planerThema(),
        home: PlanerRahmen(
          key: const ValueKey('ohne-belaege'),
          status: const Text('Status'),
          zustand: zustand,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('belag-anzeige')), findsNothing);
  });
}
