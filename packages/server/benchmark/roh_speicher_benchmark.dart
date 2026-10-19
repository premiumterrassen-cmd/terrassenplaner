import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';
import 'package:terrassenplaner_server/objectbox.g.dart';
import 'package:terrassenplaner_server/terrassenplaner_server.dart';

/// #110 Schritt 3: 500 empfangene Änderungen (Stapel) in ObjectBox speichern –
/// über Dart-Objekte (`putMany`) gegen roh über objectbox-c (`RohSpeicher`).
/// Jeder Durchlauf leert die Box danach wieder (für beide Varianten gleich).
/// Store im Arbeitsspeicher (`memory:`), damit nicht das fsync der Platte die
/// Verarbeitung überdeckt.
abstract class SpeicherBenchmark extends BenchmarkBase {
  SpeicherBenchmark(String variante)
    : super('server.ObjectBox.stapelSpeichern.$variante');

  late Store store;
  late Box<Aenderung> box;
  late Stapel stapel;

  @override
  void setup() {
    store = openStore(directory: 'memory:bench-${runtimeType.hashCode}');
    box = store.box<Aenderung>();
    stapel = Stapel(
      Stapel.baue(AenderungSicht.schemaName, [
        for (var i = 0; i < 500; i++)
          baueAenderung(
            schluessel: 'k:$i',
            knoten: 'k',
            seq: i,
            entitaet: 'Benutzer',
            uid: 'u-$i',
            partition: 'global',
            hlc: 'h-$i',
            art: 'anlegen',
          ),
      ]),
    );
  }

  @override
  void teardown() {
    store.close();
  }
}

class ObjektSpeichern extends SpeicherBenchmark {
  ObjektSpeichern() : super('objekte');

  @override
  void run() {
    box
      ..putMany([
        for (final daten in stapel.eintraege) _alsObjekt(AenderungSicht(daten)),
      ])
      ..removeAll();
  }

  static Aenderung _alsObjekt(AenderungSicht s) => Aenderung(
    knoten: s.knoten,
    seq: s.seq,
    entitaet: s.entitaet,
    uid: s.uid,
    partition: s.partition,
    hlc: s.hlc,
    art: s.art,
  );
}

class RohSpeichern extends SpeicherBenchmark {
  RohSpeichern() : super('roh');

  late RohSpeicher _roh;
  late int _entitaet;

  @override
  void setup() {
    super.setup();
    _roh = RohSpeicher(store);
    _entitaet = RohSpeicher.entitaetId<Aenderung>(store);
  }

  @override
  void run() {
    _roh.speichere(_entitaet, stapel.eintraege);
    box.removeAll();
  }

  @override
  void teardown() {
    _roh.schliesse();
    super.teardown();
  }
}

void main() {
  ObjektSpeichern().report();
  RohSpeichern().report();
}
