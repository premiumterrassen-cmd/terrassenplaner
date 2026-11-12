import 'dart:math' as math;

import 'package:flat_buffers/flat_buffers.dart' as fb;
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:test/test.dart';

/// Planungsregeln Alexander (Planungskern v12, 12.11.2026), Abschnitt 14:
/// Maß der Bögen im Plan, Riegel im UK-Plan und Hinweise zur Blende am
/// Bogen in den Planungsunterlagen.
void main() {
  const de = Unterlagentexte.deutsch;
  const en = Unterlagentexte.englisch;
  // F01 mit Bogen R 2,00 m an B — C: Sehne 309 cm, Stich 73 cm
  final stich = 2000 - math.sqrt(2000 * 2000 - 1545 * 1545);
  final laenge = 2000 * 2 * math.asin(1545 / 2000);
  final aussen = Planungsstand.start.mitRundungen(
    Rundungen.keine.mitRadius(1, const Millimeter(2000)),
  );

  group('Bogenmaß (Regel 14.1.3)', () {
    test('Länge, Radius, Scheitel und außen – nach außen und nach innen', () {
      final b = bogenmasse(aussen).single;
      expect(b.seite, 1);
      expect(b.laenge, closeTo(laenge, 1e-6));
      expect(b.radius, closeTo(2000, 1e-6));
      expect(b.scheitel.gleich(Punkt(4800 + stich, 1545), 1e-6), isTrue);
      expect(b.aussen.gleich(const Punkt(1, 0), 1e-9), isTrue);
      final innen = bogenmasse(
        Planungsstand.start.mitRundungen(
          Rundungen.keine.mitRadius(1, const Millimeter(2000), innen: true),
        ),
      ).single;
      expect(innen.scheitel.gleich(Punkt(4800 - stich, 1545), 1e-6), isTrue);
      expect(innen.aussen.gleich(const Punkt(1, 0), 1e-9), isTrue);
      // auch ein Stich (alter Planer) ist ein Bogen; ohne Rundung keiner
      expect(
        bogenmasse(
          Planungsstand.start.mitRundungen(
            Rundungen.keine.mitSeite(0, const Millimeter(300)),
          ),
        ).single.aussen.gleich(const Punkt(0, -1), 1e-9),
        isTrue,
      );
      expect(bogenmasse(Planungsstand.start), isEmpty);
    });

    test('Planbild: Bögen und Riegel hin und zurück; ältere Tabelle ohne', () {
      final p = Planbild(
        boegen: bogenmasse(aussen),
        riegel: const [(von: Punkt(1, 2), bis: Punkt(3, 4))],
      );
      final fbb = fb.Builder();
      fbb.finish(p.schreibe(fbb));
      final zurueck = Planbild.lies(
        fb.BufferContext.fromBytes(fbb.buffer),
        fb.BufferContext.fromBytes(fbb.buffer).derefObject(0),
      );
      expect(zurueck.boegen, p.boegen);
      expect(zurueck.riegel, p.riegel);
      expect(p.boegen.clear, throwsUnsupportedError);
      expect(p.riegel.clear, throwsUnsupportedError);
      final alt = fb.Builder();
      alt.finish((alt..startTable(3)).endTable());
      final leer = Planbild.lies(
        fb.BufferContext.fromBytes(alt.buffer),
        fb.BufferContext.fromBytes(alt.buffer).derefObject(0),
      );
      expect(leer.boegen, isEmpty);
      expect(leer.riegel, isEmpty);
      expect(Planbild.leer.boegen, isEmpty);
    });
  });

  group('Texte', () {
    test('Bogen … · R … in m', () {
      expect(de.bogen(3530.4, 2000), 'Bogen 3,53 m · R 2,00 m');
      expect(en.bogen(3530.4, 2000), 'Arc 3.53 m · R 2.00 m');
      expect(de.riegelHinweis, startsWith('Rand-UK am Bogen von Latte zu'));
      expect(en.riegelHinweis, startsWith('Edge substructure along the arc'));
    });

    test('Hinweise zur Blende am Bogen, andere Meldungen nicht', () {
      expect(
        de.anschlusshinweis(Anschlussmeldung.bogenblende),
        startsWith('Blende am Bogen aus senkrechten Stücken'),
      );
      expect(
        en.anschlusshinweis(Anschlussmeldung.bogenblende),
        startsWith('Cladding along the arc made of vertical pieces'),
      );
      expect(
        de.anschlusshinweis(Anschlussmeldung.bogenblendeRiegel),
        startsWith('Blende am Bogen höher als 30 cm'),
      );
      expect(
        en.anschlusshinweis(Anschlussmeldung.bogenblendeRiegel),
        startsWith('Cladding along the arc higher than 30 cm'),
      );
      for (final m in Anschlussmeldung.values) {
        if (m.nummer < 20) {
          expect(de.anschlusshinweis(m), isNull);
          expect(en.anschlusshinweis(m), isNull);
        }
      }
    });
  });

  group('Planungsunterlagen', () {
    final umriss = aussen.kontur.vieleck();
    final ecken = aussen.grundriss.ecken;
    Berechnung berechnung({
      List<Strecke> riegel = const [],
      List<Anschlussmeldung> meldungen = const [],
    }) => Berechnung(
      umriss: umriss,
      ecken: ecken,
      flaeche: aussen.kontur.flaeche,
      unterbau: Unterbau(
        holzbreite: const Millimeter(40),
        hoelzer: const [
          (von: Punkt(20, 0), bis: Punkt(20, 3090), farbe: Stueckfarbe.blau),
        ],
      ),
      anschluss: Anschlussergebnis(meldungen: meldungen),
      planbild: Planbild(boegen: bogenmasse(aussen), riegel: riegel),
    );
    Planungsunterlagen erzeuge(Berechnung b) => planungsunterlagen(
      planung: Planung([Terrassenflaeche(aussen)]),
      gesamt: b,
      flaechen: [Flaechenunterlage(b)],
      datum: DateTime(2026, 11, 12),
    );

    test('am Bogen „Bogen … · R …“ außen am Scheitel statt der Sehne', () {
      final b = berechnung();
      final texte = umrissbeschriftung(de, b);
      expect(
        [for (final t in texte) t.text],
        [
          'A',
          'B',
          'C',
          'D',
          '4,80 m',
          'Bogen 3,53 m · R 2,00 m',
          '4,80 m',
          '3,09 m',
        ],
      );
      final h = Huellrechteck.um(umriss);
      final a = math.max(h.breite, h.hoehe) * beschriftungsanteil;
      // quer zur Schrift um die halbe Textbreite (23 Zeichen à 0,2 a) weiter
      expect(zeichenbreite, 0.2);
      expect(
        texte[5].ort.gleich(
          Punkt(4800 + stich + a * (1 + 23 * 0.1), 1545),
          1e-6,
        ),
        isTrue,
      );
      // nach oben bzw. unten nur um die halbe Zeile (a / 4)
      final oben = umrissbeschriftung(
        de,
        Berechnung(
          umriss: umriss,
          ecken: ecken,
          flaeche: 1,
          planbild: Planbild(
            boegen: const [
              (
                seite: 0,
                laenge: 1000,
                radius: 2000,
                scheitel: Punkt(2400, -100),
                aussen: Punkt(0, -1),
              ),
            ],
          ),
        ),
      );
      expect(oben[4].text, 'Bogen 1,00 m · R 2,00 m');
      expect(oben[4].ort.gleich(Punkt(2400, -100 - a * 1.25), 1e-6), isTrue);
    });

    test('UK-Plan: Riegel grün umrandet mit Hinweis; Hinweise zur Blende am '
        'Bogen', () {
      final u = erzeuge(
        berechnung(
          riegel: const [(von: Punkt(40, 1000), bis: Punkt(395, 1000))],
          meldungen: const [
            Anschlussmeldung.unterlueftung,
            Anschlussmeldung.bogenblende,
            Anschlussmeldung.bogenblendeRiegel,
          ],
        ),
      );
      final uk = u.kapitel.singleWhere(
        (k) => k.titel.endsWith('Unterkonstruktion'),
      );
      final plan = uk.inhalt.whereType<Plan>().single;
      final gruen = plan.linien.where(
        (l) => l.argb == Stueckfarbe.gruen.argb && !l.gefuellt,
      );
      expect(gruen.single.punkte, const [
        Punkt(20, 980),
        Punkt(415, 980),
        Punkt(415, 1020),
        Punkt(20, 1020),
      ]);
      expect(
        uk.inhalt.whereType<Absatz>().map((a) => a.text),
        contains(de.riegelHinweis),
      );
      final hinweise = u.kapitel.singleWhere(
        (k) => k.titel == 'Hinweise zur Planung',
      );
      expect(hinweise.inhalt.whereType<Absatz>().map((a) => a.text), [
        '• ${de.anschlusshinweis(Anschlussmeldung.bogenblende)}',
        '• ${de.anschlusshinweis(Anschlussmeldung.bogenblendeRiegel)}',
      ]);
      // ohne Riegel kein Hinweis
      final ohne = erzeuge(berechnung());
      expect(
        ohne.kapitel
            .singleWhere((k) => k.titel.endsWith('Unterkonstruktion'))
            .inhalt
            .whereType<Absatz>()
            .map((a) => a.text),
        isNot(contains(de.riegelHinweis)),
      );
    });
  });
}
