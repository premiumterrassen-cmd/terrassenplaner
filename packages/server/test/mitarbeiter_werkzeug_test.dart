import 'package:connectanum_core/connectanum_core.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';
import 'package:test/test.dart';

/// Werkzeug mit aufgezeichneten Aufrufen, vorgegebenen Eingabezeilen und
/// einer Schlüsselableitung ohne Rechenaufwand.
final class _Lauf {
  _Lauf({
    List<String?> eingabe = const [],
    this.antwort = const [],
    this.ablehnung,
    bool interaktiv = false,
  }) : _eingabe = [...eingabe] {
    werkzeug = MitarbeiterWerkzeug(
      rufe: (prozedur, argumente) async {
        aufrufe.add((prozedur, argumente));
        if (ablehnung case final a?) throw VerwaltungsFehler(a);
        return antwort;
      },
      passwortLesen: (frage) {
        fragen.add(frage);
        return _eingabe.isEmpty ? null : _eingabe.removeAt(0);
      },
      ausgabe: ausgaben.add,
      fehler: fehler.add,
      interaktiv: interaktiv,
      ableiten: (email, passwort) async {
        passwoerter.add(passwort);
        return MitarbeiterZugang(
          authId: email,
          salt: 'salz',
          storedKey: 'k-$passwort',
          serverKey: 'v',
        );
      },
    );
  }

  final List<String?> _eingabe;
  final List<Object?> antwort;
  final String? ablehnung;
  late final MitarbeiterWerkzeug werkzeug;
  final aufrufe = <(String, List<Object?>)>[];
  final fragen = <String>[];
  final ausgaben = <String>[];
  final fehler = <String>[];
  final passwoerter = <String>[];

  Future<int> call(List<String> argumente) => werkzeug.fuehreAus(argumente);
}

const _passwort = 'lang-genug-123';

void main() {
  test('Mindestlänge und Aufruf', () {
    expect(MitarbeiterWerkzeug.mindestlaenge, 12);
    expect(
      MitarbeiterWerkzeug.aufruf,
      'Aufruf: mitarbeiter anlegen|passwort|sperren|entsperren <email> '
      '| mitarbeiter liste',
    );
    expect(const VerwaltungsFehler('x').toString(), 'x');
    expect(
      [
        MitarbeiterVerwaltung.anlegen,
        MitarbeiterVerwaltung.passwort,
        MitarbeiterVerwaltung.sperren,
        MitarbeiterVerwaltung.entsperren,
        MitarbeiterVerwaltung.liste,
        MitarbeiterVerwaltung.fehler,
      ],
      [
        for (final n in [
          'anlegen',
          'passwort',
          'sperren',
          'entsperren',
          'liste',
          'fehler',
        ])
          'verwaltung.mitarbeiter.$n',
      ],
    );
  });

  test('anlegen: Passwort über stdin, nur Schlüssel zum Server', () async {
    final lauf = _Lauf(eingabe: [_passwort]);
    expect(await lauf(['anlegen', ' Anna@Example.TEST ']), 0);
    expect(lauf.fragen, ['Passwort für anna@example.test: ']);
    expect(lauf.passwoerter, [_passwort]);
    final (prozedur, argumente) = lauf.aufrufe.single;
    expect(prozedur, MitarbeiterVerwaltung.anlegen);
    final json = argumente.single! as Map<String, Object?>;
    expect(json['authid'], 'anna@example.test');
    expect(json['stored_key'], 'k-$_passwort');
    expect(json.values, isNot(contains(_passwort)));
    expect(lauf.ausgaben, ['Konto anna@example.test angelegt']);
    expect(lauf.fehler, isEmpty);
  });

  test('ohne eigene Ableitung: Argon2id mit Standardkosten', () async {
    final gesendet = <Object?>[];
    final werkzeug = MitarbeiterWerkzeug(
      rufe: (_, argumente) async {
        gesendet.addAll(argumente);
        return const [];
      },
      passwortLesen: (_) => _passwort,
      ausgabe: (_) {},
      fehler: (_) {},
    );
    expect(await werkzeug.fuehreAus(['anlegen', 'anna@example.test']), 0);
    final json = gesendet.single! as Map<String, Object?>;
    expect(json['kdf'], 'argon2id13');
    expect(json['iterationen'], MitarbeiterZugang.standardIterationen);
    expect(json['speicher'], MitarbeiterZugang.standardSpeicher);
    final erwartet = ScramAuthentication.deriveServerSecrets(
      secret: _passwort,
      salt: json['salt']! as String,
      kdf: ScramAuthentication.kdfArgon,
      iterations: MitarbeiterZugang.standardIterationen,
      memory: MitarbeiterZugang.standardSpeicher,
    );
    expect(json['stored_key'], erwartet.storedKey);
  });

  test('passwort: interaktiv zweimal abgefragt', () async {
    final lauf = _Lauf(eingabe: [_passwort, _passwort], interaktiv: true);
    expect(await lauf(['passwort', 'anna@example.test']), 0);
    expect(lauf.fragen, ['Passwort für anna@example.test: ', 'Wiederholen: ']);
    expect(lauf.aufrufe.single.$1, MitarbeiterVerwaltung.passwort);
    expect(lauf.ausgaben, ['Passwort für anna@example.test gesetzt']);
  });

  test('abweichende Wiederholung: nichts gesendet', () async {
    final lauf = _Lauf(eingabe: [_passwort, '${_passwort}x'], interaktiv: true);
    expect(await lauf(['anlegen', 'anna@example.test']), 64);
    expect(lauf.aufrufe, isEmpty);
    expect(lauf.fehler, ['Passwörter stimmen nicht überein: Wiederholung']);
  });

  test('zu kurzes oder fehlendes Passwort: nichts gesendet', () async {
    for (final eingabe in <String?>['a' * 11, null]) {
      final lauf = _Lauf(eingabe: [eingabe]);
      expect(await lauf(['anlegen', 'anna@example.test']), 64);
      expect(lauf.aufrufe, isEmpty);
      expect(lauf.passwoerter, isEmpty);
      expect(lauf.fehler, [
        'Passwort zu kurz (mindestens 12 Zeichen): '
            '${eingabe?.length ?? 0} Zeichen',
      ]);
    }
    final genau = _Lauf(eingabe: ['a' * 12]);
    expect(await genau(['anlegen', 'anna@example.test']), 0);
  });

  test('sperren und entsperren', () async {
    for (final (befehl, prozedur, meldung) in [
      ('sperren', MitarbeiterVerwaltung.sperren, 'gesperrt'),
      ('entsperren', MitarbeiterVerwaltung.entsperren, 'entsperrt'),
    ]) {
      final lauf = _Lauf();
      expect(await lauf([befehl, 'Anna@Example.test']), 0);
      expect(lauf.aufrufe.single.$1, prozedur);
      expect(lauf.aufrufe.single.$2, ['anna@example.test']);
      expect(lauf.fragen, isEmpty);
      expect(lauf.ausgaben, ['Konto anna@example.test $meldung']);
    }
  });

  test('liste mit Sperrvermerk', () async {
    final lauf = _Lauf(
      antwort: [
        ['anna@x.de', false],
        ['bob@x.de', true],
      ],
    );
    expect(await lauf(['liste']), 0);
    expect(lauf.aufrufe.single.$1, MitarbeiterVerwaltung.liste);
    expect(lauf.aufrufe.single.$2, isEmpty);
    expect(lauf.ausgaben, ['anna@x.de', 'bob@x.de (gesperrt)']);
  });

  test('falscher Aufruf: Exit-Code 64', () async {
    for (final argumente in [
      <String>[],
      ['liste', 'x'],
      ['anlegen'],
      ['loeschen', 'anna@x.de'],
      ['sperren', 'a', 'b'],
    ]) {
      final lauf = _Lauf();
      expect(await lauf(argumente), 64, reason: '$argumente');
      expect(lauf.fehler, [MitarbeiterWerkzeug.aufruf]);
      expect(lauf.aufrufe, isEmpty);
    }
  });

  test('keine E-Mail-Adresse: Exit-Code 64', () async {
    final lauf = _Lauf(eingabe: [_passwort]);
    expect(await lauf(['anlegen', 'anna']), 64);
    expect(lauf.fehler, ['keine E-Mail-Adresse: anna']);
    expect(lauf.fragen, isEmpty);
  });

  test('Ablehnung des Servers: Exit-Code 1', () async {
    final lauf = _Lauf(ablehnung: 'Konto anna@x.de gibt es nicht');
    expect(await lauf(['sperren', 'anna@x.de']), 1);
    expect(lauf.fehler, ['Abgelehnt: Konto anna@x.de gibt es nicht']);
    expect(lauf.ausgaben, isEmpty);
  });
}
