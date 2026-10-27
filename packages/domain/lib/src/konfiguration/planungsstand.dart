import 'dart:typed_data';

import 'package:flat_buffers/flat_buffers.dart' as fb;

import '../artikel/einheiten.dart';
import 'ausschnitt.dart';
import 'grundriss.dart';

/// Eingaben einer Planung zu einem Zeitpunkt (M3-03) – unveränderlich, damit
/// Rückgängig exakt auf einen früheren Stand springen kann. Seit M4-02 mit
/// Grundriss, seit M4-06 mit Ausschnitten; Belag, Unterkonstruktion usw.
/// folgen als weitere Felder. Berechnet wird daraus auf dem Server.
final class Planungsstand {
  const Planungsstand({
    this.grundriss = RechteckGrundriss.start,
    this.ausschnitte = const [],
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
    );
  }

  /// Startkonfiguration des alten Planers (F01) – auch nach „Zurücksetzen“.
  static const start = Planungsstand();

  final Grundriss grundriss;

  /// Ausschnitte im Grundriss (Fachkonzept 1.4), in der Reihenfolge A1, A2 …
  final List<Ausschnitt> ausschnitte;

  /// Kopie mit geändertem Grundriss.
  Planungsstand mitGrundriss(Grundriss grundriss) =>
      Planungsstand(grundriss: grundriss, ausschnitte: ausschnitte);

  /// Neue Form mit ihren Vorgabemaßen; die O-Form bringt ihren Ausschnitt
  /// mit, alle anderen beginnen ohne (Fachkonzept 1.1).
  Planungsstand mitForm(Terrassenform form) => Planungsstand(
    grundriss: form.vorgabe,
    ausschnitte: [if (form == Terrassenform.oForm) Ausschnitt.oForm],
  );

  /// Grundriss um [grad] gedreht (M4-10); die Ausschnitte werden dabei
  /// zurückgesetzt – die App fragt vorher nach.
  Planungsstand gedreht(double grad) =>
      Planungsstand(grundriss: grundriss.gedreht(grad));

  /// Kopie, in der der Ausschnitt [index] durch [ausschnitt] ersetzt ist.
  Planungsstand mitAusschnitt(int index, Ausschnitt ausschnitt) =>
      Planungsstand(
        grundriss: grundriss,
        ausschnitte: [...ausschnitte]..[index] = ausschnitt,
      );

  /// FlatBuffer für den Weg zum Server (#110):
  /// `{ 0: schema (uint16), 1: grundriss { 0: form (uint8), 1: masse ([int32] mm) },
  /// 2: ausschnitte ([{ 0: bezeichnung (string), 1: masse ([int32] mm) }]) }`.
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
    fbb
      ..startTable(3)
      ..addUint16(_schemaPlatz, schema)
      ..addOffset(_grundrissPlatz, grundrissOrt)
      ..addOffset(_ausschnittePlatz, ausschnitteOrt);
    fbb.finish(fbb.endTable());
    return fbb.buffer;
  }

  static int _ausschnitt(fb.Builder fbb, Ausschnitt a) {
    final bezeichnungOrt = fbb.writeString(a.bezeichnung);
    final masseOrt = fbb.writeListInt32([for (final m in a.masse) m.mm]);
    fbb
      ..startTable(2)
      ..addOffset(0, bezeichnungOrt)
      ..addOffset(1, masseOrt);
    return fbb.endTable();
  }

  /// Version des Transportformats.
  static const schema = 1;

  static const _schemaPlatz = 0;
  static const _grundrissPlatz = 1;
  static const _ausschnittePlatz = 2;

  @override
  bool operator ==(Object other) {
    if (other is! Planungsstand ||
        other.grundriss != grundriss ||
        other.ausschnitte.length != ausschnitte.length) {
      return false;
    }
    for (var i = 0; i < ausschnitte.length; i++) {
      if (other.ausschnitte[i] != ausschnitte[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(grundriss, Object.hashAll(ausschnitte));
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
    );
  }
}
