/// Aufrufparameter von `bin/lasttest.dart` (M10-02).
///
/// ```text
/// lasttest.dart artikeldatei <pfad>
/// lasttest.dart lauf --url ws://127.0.0.1:8080/ws [--pid <server-pid>]
///   [--dauer <s>] [--faktor <x>] [--szenario <name>]… [--ausgabe <datei>]
/// ```
sealed class LasttestOptionen {
  const LasttestOptionen();

  static const hilfe =
      'Aufruf: lasttest.dart artikeldatei <pfad>\n'
      '       lasttest.dart lauf --url <ws-url> [--pid <server-pid>] '
      '[--dauer <s>] [--faktor <x>] [--szenario <name>]… [--ausgabe <datei>]';

  /// Liest [argumente]; wirft [FormatException] mit [hilfe] bei Fehlern.
  static LasttestOptionen lies(List<String> argumente) => switch (argumente) {
    ['artikeldatei', final pfad] => ArtikeldateiSchreiben(pfad),
    ['lauf', ...final rest] => Lauf._lies(rest),
    _ => throw const FormatException(hilfe),
  };
}

/// Erfundene Artikeldatei für den Server schreiben.
final class ArtikeldateiSchreiben extends LasttestOptionen {
  const ArtikeldateiSchreiben(this.pfad);

  final String pfad;
}

/// Lasttest gegen einen laufenden Router.
final class Lauf extends LasttestOptionen {
  const Lauf({
    required this.url,
    this.pid,
    this.dauer = const Duration(seconds: 60),
    this.faktor = 1,
    this.szenarien = const [],
    this.ausgabe,
  });

  factory Lauf._lies(List<String> rest) {
    if (rest.length.isOdd) throw const FormatException(LasttestOptionen.hilfe);
    String? url;
    int? pid;
    var dauer = const Duration(seconds: 60);
    var faktor = 1.0;
    final szenarien = <String>[];
    String? ausgabe;
    for (var i = 0; i < rest.length; i += 2) {
      final wert = rest[i + 1];
      switch (rest[i]) {
        case '--url':
          url = wert;
        case '--pid':
          pid = int.parse(wert);
        case '--dauer':
          dauer = Duration(seconds: int.parse(wert));
        case '--faktor':
          faktor = double.parse(wert);
        case '--szenario':
          szenarien.add(wert);
        case '--ausgabe':
          ausgabe = wert;
        default:
          throw const FormatException(LasttestOptionen.hilfe);
      }
    }
    if (url == null) throw const FormatException(LasttestOptionen.hilfe);
    return Lauf(
      url: url,
      pid: pid,
      dauer: dauer,
      faktor: faktor,
      szenarien: szenarien,
      ausgabe: ausgabe,
    );
  }

  final String url;

  /// Prozess des Routers für Speicher und CPU; ohne nicht gemessen.
  final int? pid;
  final Duration dauer;
  final double faktor;

  /// Nur diese Szenarien; leer = alle.
  final List<String> szenarien;

  /// JSON-Bericht hierhin; ohne nur auf die Konsole.
  final String? ausgabe;
}
