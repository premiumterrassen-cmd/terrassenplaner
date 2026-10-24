import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:terrassenplaner_app/src/artikel/artikelbild_widget.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

Artikel _artikel(List<String> bilder) => Artikel(
  nummer: const Artikelnummer('80-10-001'),
  titel: 'CLIP-FIXX',
  art: Artikelart.clip,
  einheit: Verkaufseinheit(Mengeneinheit.stueck),
  bilder: bilder,
);

Widget _rahmen(Widget kind) => MaterialApp(home: Scaffold(body: kind));

void main() {
  testWidgets('ohne Bild: Platzhalter', (tester) async {
    await tester.pumpWidget(_rahmen(Artikelbild(_artikel(const []))));
    expect(find.byType(ArtikelbildPlatzhalter), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(find.bySemanticsLabel(ArtikelbildPlatzhalter.text), findsOneWidget);
    expect(
      tester.getSize(find.byType(ArtikelbildPlatzhalter)),
      const Size(96, 96),
    );
  });

  testWidgets('Platzhalter allein: 96 px', (tester) async {
    await tester.pumpWidget(_rahmen(const ArtikelbildPlatzhalter()));
    expect(
      tester.getSize(find.byType(ArtikelbildPlatzhalter)),
      const Size(96, 96),
    );
  });

  testWidgets('erstes Bild über die Bildadresse', (tester) async {
    await tester.pumpWidget(
      _rahmen(
        Artikelbild(_artikel(const ['clip.jpg', 'zwei.webp']), groesse: 64),
      ),
    );
    final bild = tester.widget<Image>(find.byType(Image));
    expect((bild.image as NetworkImage).url, 'artikelbilder/clip.webp');
    expect(
      [bild.width, bild.height, bild.fit, bild.semanticLabel],
      [64, 64, BoxFit.contain, 'CLIP-FIXX'],
    );
  });

  testWidgets('Ladefehler: Platzhalter in derselben Größe', (tester) async {
    await tester.pumpWidget(
      _rahmen(Artikelbild(_artikel(const ['clip.jpg']), groesse: 64)),
    );
    // Im Test liefert jede Netzwerkanfrage HTTP 400 – wie ein fehlendes Bild.
    await tester.pumpAndSettle();
    expect(find.byType(ArtikelbildPlatzhalter), findsOneWidget);
    expect(
      tester.getSize(find.byType(ArtikelbildPlatzhalter)),
      const Size(64, 64),
    );
    expect(tester.widget<Icon>(find.byType(Icon)).size, 32);
  });
}
