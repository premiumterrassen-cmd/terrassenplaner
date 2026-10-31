import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;

import '../artikel/artikel.dart';
import '../artikel/einheiten.dart';
import '../geometrie/kontur.dart';
import 'ausschnitt.dart';
import 'grundriss.dart';
import 'rundungen.dart';

/// Eingaben einer Planung zu einem Zeitpunkt (M3-03) – unveränderlich, damit
/// Rückgängig exakt auf einen früheren Stand springen kann. Seit M4-02 mit
/// Grundriss, seit M4-06 mit Ausschnitten, seit M5-01 mit Belag, seit M5-02
/// mit Dielenlänge; Unterkonstruktion usw. folgen als weitere Felder.
/// Berechnet wird daraus auf dem Server.
final class Planungsstand {
  const Planungsstand({
    this.grundriss = RechteckGrundriss.start,
    this.ausschnitte = const [],
    this.rundungen = Rundungen.keine,
    this.belag,
    this.dielenlaenge,
  });

  /// Liest einen Planungsstand aus dem Transportformat ([zuBytes]).
  factory Planungsstand.ausBytes(Uint8List bytes) {
    final puffer = fb.BufferContext.fromBytes(bytes);
    final wurzel = puffer.derefObject(0);
    final grundriss = const _GrundrissLeser().vTableGetNullable(
      puffer,
      wurzel,
      _versatz(_grundrissPlatz),
    );
    if (grundriss == null) {
      throw const FormatException('Planungsstand ohne Grundriss');
    }
    return Planungsstand(
      grundriss: grundriss,
      ausschnitte: [
        ...const fb.ListReader<Ausschnitt>(_AusschnittLeser())
            .vTableGet(puffer, wurzel, _versatz(_ausschnittePlatz), const []),
      ],
      rundungen: Rundungen.aus(
        const fb.ListReader<int>(fb.Int32Reader())
            .vTableGet(puffer, wurzel, _versatz(_rundungenPlatz), const []),
      ),
      belag: switch (const fb.StringReader().vTableGetNullable(
        puffer,
        wurzel,
        _versatz(_belagPlatz),
      )) {
        final nummer? => Artikelnummer(nummer),
        null => null,
      },
      dielenlaenge: switch (const fb.Int32Reader().vTableGetNullable(
        puffer,
        wurzel,
        _versatz(_dielenlaengePlatz),
      )) {
        final mm? => Millimeter(mm),
        null => null,
      },
    );
  }

  /// Startkonfiguration des alten Planers (F01) – auch nach „Zurücksetzen“.
  static const start = Planungsstand();

  final Grundriss grundriss;

  /// Ausschnitte im Grundriss (Fachkonzept 1.4), in der Reihenfolge A1, A2 …
  final List<Ausschnitt> ausschnitte;

  /// Rundungen an Ecken und Seiten (Fachkonzept 1.3, M4-11).
  final Rundungen rundungen;

  /// Gewählter Belag (M5-01); `null` = Vorgabe, der erste Belag der
  /// Artikeldaten.
  final Artikelnummer? belag;

  /// Erzwungene Lieferlänge (M5-02, R-B10); `null` = automatisch. Gilt nur,
  /// solange der Belag sie liefert (`lieferlaengenFuer`).
  final Millimeter? dielenlaenge;

  /// Kontur des Grundrisses samt Rundungen.
  Kontur get kontur => rundungen.kontur(grundriss);

  /// Kopie mit geändertem Grundriss; die Rundungen bleiben, solange es
  /// gleich viele Ecken sind und sie weiter passen.
  Planungsstand mitGrundriss(Grundriss grundriss) => Planungsstand(
    grundriss: grundriss,
    ausschnitte: ausschnitte,
    rundungen: _passend(grundriss) ? rundungen : Rundungen.keine,
    belag: belag,
    dielenlaenge: dielenlaenge,
  );

  bool _passend(Grundriss neu) {
    if (rundungen.leer) return true;
    if (neu.ecken.length != grundriss.ecken.length) return false;
    try {
      rundungen.kontur(neu);
      return true;
    } on ArgumentError {
      return false;
    }
  }

  /// Kopie mit anderen Rundungen (die App prüft sie vorher über [kontur]).
  Planungsstand mitRundungen(Rundungen rundungen) => Planungsstand(
    grundriss: grundriss,
    ausschnitte: ausschnitte,
    rundungen: rundungen,
    belag: belag,
    dielenlaenge: dielenlaenge,
  );

  /// Neue Form mit ihren Vorgabemaßen; die O-Form bringt ihren Ausschnitt
  /// mit, alle anderen beginnen ohne (Fachkonzept 1.1).
  Planungsstand mitForm(Terrassenform form) => Planungsstand(
    grundriss: form.vorgabe,
    ausschnitte: [if (form == Terrassenform.oForm) Ausschnitt.oForm],
    belag: belag,
    dielenlaenge: dielenlaenge,
  );

  /// Grundriss um [grad] gedreht (M4-10); die Ausschnitte werden dabei
  /// zurückgesetzt – die App fragt vorher nach.
  Planungsstand gedreht(double grad) => Planungsstand(
    grundriss: grundriss.gedreht(grad),
    belag: belag,
    dielenlaenge: dielenlaenge,
  );

  /// Mit einer weiteren Fläche (180 × 120 cm, Bezeichnung A1, A2 …) mitten
  /// im Grundriss („Weitere Flächen hinzufügen“, Fachkonzept 1.4).
  Planungsstand mitNeuemAusschnitt() {
    final namen = {for (final a in ausschnitte) a.bezeichnung};
    var nummer = 1;
    while (namen.contains('A$nummer')) {
      nummer++;
    }
    final mitte = kontur.huellrechteck.mitte;
    return Planungsstand(
      grundriss: grundriss,
      ausschnitte: [
        ...ausschnitte,
        Ausschnitt(
          bezeichnung: 'A$nummer',
          x: Millimeter((mitte.x - Ausschnitt.vorgabeLaenge.mm / 2).round()),
          y: Millimeter((mitte.y - Ausschnitt.vorgabeBreite.mm / 2).round()),
          laenge: Ausschnitt.vorgabeLaenge,
          breite: Ausschnitt.vorgabeBreite,
        ),
      ],
      rundungen: rundungen,
      belag: belag,
      dielenlaenge: dielenlaenge,
    );
  }

  /// Ohne den Ausschnitt [index].
  Planungsstand ohneAusschnitt(int index) => Planungsstand(
    grundriss: grundriss,
    ausschnitte: [...ausschnitte]..removeAt(index),
    rundungen: rundungen,
    belag: belag,
    dielenlaenge: dielenlaenge,
  );

  /// Kopie, in der der Ausschnitt [index] durch [ausschnitt] ersetzt ist.
  Planungsstand mitAusschnitt(int index, Ausschnitt ausschnitt) =>
      Planungsstand(
        grundriss: grundriss,
        ausschnitte: [...ausschnitte]..[index] = ausschnitt,
        rundungen: rundungen,
        belag: belag,
        dielenlaenge: dielenlaenge,
      );

  /// Kopie mit anderem Belag; die übrigen Eingaben bleiben.
  Planungsstand mitBelag(Artikelnummer belag) => Planungsstand(
    grundriss: grundriss,
    ausschnitte: ausschnitte,
    rundungen: rundungen,
    belag: belag,
    dielenlaenge: dielenlaenge,
  );

  /// Kopie mit erzwungener Lieferlänge; `null` = automatisch.
  Planungsstand mitDielenlaenge(Millimeter? dielenlaenge) => Planungsstand(
    grundriss: grundriss,
    ausschnitte: ausschnitte,
    rundungen: rundungen,
    belag: belag,
    dielenlaenge: dielenlaenge,
  );

  /// FlatBuffer für den Weg zum Server (#110):
  /// `{ 0: schema (uint16), 1: grundriss { 0: form (uint8), 1: masse ([int32] mm) },
  /// 2: ausschnitte ([{ 0: bezeichnung (string), 1: masse ([int32] mm) }]),
  /// 3: rundungen ([int32] je Art, Nummer, mm), 4: belag (string),
  /// 5: dielenlaenge (int32 mm) }`.
  /// Neue Felder nur anhängen (docs/architektur/datenmodell.md).
  Uint8List zuBytes() {
    final fbb = fb.Builder();
    final masseOrt = fbb.writeListInt32([
      for (final m in grundriss.masse) m.mm,
    ]);
    fbb
      ..startTable(2)
      ..addUint8(0, grundriss.form.nummer)
      ..addOffset(1, masseOrt);
    final grundrissOrt = fbb.endTable();
    final ausschnitteOrt = fbb.writeList([
      for (final a in ausschnitte) _ausschnitt(fbb, a),
    ]);
    final rundungenOrt = fbb.writeListInt32(rundungen.masse);
    final belagOrt = switch (belag) {
      final nummer? => fbb.writeString(nummer.wert),
      null => null,
    };
    fbb
      ..startTable(6)
      ..addUint16(_schemaPlatz, schema)
      ..addOffset(_grundrissPlatz, grundrissOrt)
      ..addOffset(_ausschnittePlatz, ausschnitteOrt)
      ..addOffset(_rundungenPlatz, rundungenOrt)
      ..addOffset(_belagPlatz, belagOrt)
      ..addInt32(_dielenlaengePlatz, dielenlaenge?.mm);
    fbb.finish(fbb.endTable());
    return fbb.buffer;
  }

  static int _ausschnitt(fb.Builder fbb, Ausschnitt a) {
    final bezeichnungOrt = fbb.writeString(a.bezeichnung);
    final masseOrt = fbb.writeListInt32([for (final m in a.masse) m.mm]);
    fbb
      ..startTable(5)
      ..addOffset(0, bezeichnungOrt)
      ..addOffset(1, masseOrt)
      ..addUint8(2, a.form.nummer)
      ..addUint8(3, a.funktion.nummer)
      ..addUint8(4, a.inhalt.nummer);
    return fbb.endTable();
  }

  /// Version des Transportformats.
  static const schema = 1;

  static const _schemaPlatz = 0;
  static const _grundrissPlatz = 1;
  static const _ausschnittePlatz = 2;
  static const _rundungenPlatz = 3;
  static const _belagPlatz = 4;
  static const _dielenlaengePlatz = 5;

  @override
  bool operator ==(Object other) {
    if (other is! Planungsstand ||
        other.grundriss != grundriss ||
        other.rundungen != rundungen ||
        other.belag != belag ||
        other.dielenlaenge != dielenlaenge ||
        other.ausschnitte.length != ausschnitte.length) {
      return false;
    }
    for (var i = 0; i < ausschnitte.length; i++) {
      if (other.ausschnitte[i] != ausschnitte[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    grundriss,
    Object.hashAll(ausschnitte),
    rundungen,
    belag,
    dielenlaenge,
  );
}

/// vtable-Versatz eines Feldplatzes.
int _versatz(int platz) => 4 + 2 * platz;

List<Millimeter> _masse(fb.BufferContext puffer, int ort) => [
  for (final mm in const fb.ListReader<int>(
    fb.Int32Reader(),
  ).vTableGet(puffer, ort, _versatz(1), const []))
    Millimeter(mm),
];

final class _GrundrissLeser extends fb.TableReader<Grundriss> {
  const _GrundrissLeser();

  @override
  Grundriss createObject(fb.BufferContext puffer, int ort) {
    final nummer = const fb.Uint8Reader().vTableGet(
      puffer,
      ort,
      _versatz(0),
      0,
    );
    final form = Terrassenform.values.firstWhere(
      (f) => f.nummer == nummer,
      orElse: () => throw FormatException('unbekannte Terrassenform $nummer'),
    );
    return Grundriss.aus(form, _masse(puffer, ort));
  }
}

final class _AusschnittLeser extends fb.TableReader<Ausschnitt> {
  const _AusschnittLeser();

  @override
  Ausschnitt createObject(fb.BufferContext puffer, int ort) {
    final masse = _masse(puffer, ort);
    if (masse.length != 4) {
      throw FormatException('Ausschnitt braucht 4 Maße, nicht ${masse.length}');
    }
    return Ausschnitt(
      bezeichnung: const fb.StringReader().vTableGet(
        puffer,
        ort,
        _versatz(0),
        '',
      ),
      x: masse[0],
      y: masse[1],
      laenge: masse[2],
      breite: masse[3],
      form: _wert(Ausschnittform.values, (f) => f.nummer, puffer, ort, 2),
      funktion: _wert(
        Ausschnittfunktion.values,
        (f) => f.nummer,
        puffer,
        ort,
        3,
      ),
      inhalt: _wert(Ausschnittinhalt.values, (i) => i.nummer, puffer, ort, 4),
    );
  }

  /// Eintrag aus [werte] zur Nummer im Feldplatz [platz] (fehlt er: 0).
  static T _wert<T>(
    List<T> werte,
    int Function(T) nummer,
    fb.BufferContext puffer,
    int ort,
    int platz,
  ) {
    final n = const fb.Uint8Reader().vTableGet(puffer, ort, _versatz(platz), 0);
    return werte.firstWhere(
      (w) => nummer(w) == n,
      orElse: () => throw FormatException('unbekannte Nummer $n'),
    );
  }
}
