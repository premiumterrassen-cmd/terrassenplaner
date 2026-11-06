import 'dart:math';
import 'dart:typed_data';

import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

import '../../objectbox.g.dart';
import 'datenbank.dart';
import 'entitaeten.dart';

/// Konfigurationsnummer oder Version gibt es nicht – oder der Prüfcode
/// passt nicht (M9-05b): beides sieht von außen gleich aus, damit niemand
/// erfährt, ob eine Nummer vergeben ist.
final class KonfigurationUnbekannt implements Exception {
  const KonfigurationUnbekannt(this.nummer, [this.version]);

  final Konfigurationsnummer nummer;
  final int? version;

  @override
  String toString() => switch (version) {
    final v? => 'Konfiguration ${nummer.wert} Version $v unbekannt',
    null => 'Konfiguration ${nummer.wert} unbekannt',
  };
}

/// Ein automatisch zwischengespeicherter Stand: Planung im Transportformat
/// und die gespeicherte Konfiguration, auf der er beruht (`null` = noch nie
/// gespeichert).
typedef Entwurf = ({Uint8List inhalt, KonfigurationsStand? bezug});

/// Gespeicherte Konfigurationen und Entwürfe (M9-05), wie sie der
/// Konfigurationsdienst braucht.
abstract interface class KonfigurationsSpeicher {
  /// Speichert [inhalt] als neue Version (ohne [kennung]: neue Nummer mit
  /// neuem Prüfcode).
  KonfigurationsStand speichere(
    Uint8List inhalt, {
    Konfigurationskennung? kennung,
  });

  /// Inhalt der Version [stand]; unbekannt oder Prüfcode falsch:
  /// [KonfigurationUnbekannt].
  Uint8List lies(KonfigurationsStand stand);

  /// Vollständige Kennung (mit Prüfcode) zu [nummer] – nur für angemeldete
  /// Mitarbeiter, die ohne Prüfcode laden dürfen (M9-10); unbekannt:
  /// [KonfigurationUnbekannt].
  Konfigurationskennung kennung(Konfigurationsnummer nummer);

  /// Merkt [inhalt] als Entwurf der Sitzung [schluessel]; ein [bezug] mit
  /// falschem Prüfcode: [KonfigurationUnbekannt].
  void merkeEntwurf(
    String schluessel,
    Uint8List inhalt, {
    KonfigurationsStand? bezug,
  });

  /// Entwurf der Sitzung [schluessel] oder `null`.
  Entwurf? entwurf(String schluessel);
}

/// [KonfigurationsSpeicher] in ObjectBox (docs/architektur/datenmodell.md):
/// Versionen werden nur angehängt, jede Schreibtransaktion protokolliert
/// ihre Änderungen.
final class Konfigurationsablage implements KonfigurationsSpeicher {
  Konfigurationsablage(
    this._db, {
    this.uhr = DateTime.now,
    this.entwurfFrist = standardFrist,
    Random? zufall,
  }) : _zufall = zufall ?? Random.secure();

  final Datenbank _db;

  /// Quelle der Prüfcodes – kryptografisch sicher (M9-05b).
  final Random _zufall;

  /// Liefert „jetzt“ – Ortszeit des Servers bestimmt den Tag der Nummer.
  final DateTime Function() uhr;

  /// So lange bleibt ein unveränderter Entwurf abrufbar.
  final Duration entwurfFrist;

  static const standardFrist = Duration(days: 30);

  /// Speichert [inhalt] als neue Version: ohne [kennung] als Version 1
  /// einer neuen Konfigurationsnummer des heutigen Tages mit neuem
  /// Prüfcode, sonst als nächste Version von [kennung] (Prüfcode muss
  /// passen). Gleicht [inhalt] der letzten Version, entsteht keine neue –
  /// es bleibt bei deren Stand.
  @override
  KonfigurationsStand speichere(
    Uint8List inhalt, {
    Konfigurationskennung? kennung,
  }) => _db.transaktion(() {
    final kopf = switch (kennung) {
      null => _neuerKopf(),
      final k => _kopfMit(k) ?? (throw KonfigurationUnbekannt(k.nummer)),
    };
    final letzte = kopf.aktuelleVersion;
    if (letzte > 0 && _gleich(_version(kopf.nummer, letzte)!.inhalt, inhalt)) {
      return _stand(kopf, letzte);
    }
    final version = _db.speichere(
      KonfigurationsVersion(
        nummer: kopf.nummer,
        version: letzte + 1,
        inhalt: inhalt,
      ),
    );
    if (kopf.erstelltAm.isEmpty) kopf.erstelltAm = version.hlc;
    _db.speichere(kopf..aktuelleVersion = version.version);
    return _stand(kopf, version.version);
  });

  /// Inhalt der Version [stand] – unverändert, wie gespeichert.
  @override
  Uint8List lies(KonfigurationsStand stand) {
    final kopf = _kopfMit(stand.kennung);
    return (kopf == null ? null : _version(kopf.nummer, stand.version))
            ?.inhalt ??
        (throw KonfigurationUnbekannt(stand.nummer, stand.version));
  }

  @override
  Konfigurationskennung kennung(Konfigurationsnummer nummer) =>
      switch (_kopf(nummer)) {
        final kopf? => _kennung(kopf),
        null => throw KonfigurationUnbekannt(nummer),
      };

  /// Merkt [inhalt] als Entwurf von [schluessel] und verlängert die Frist.
  /// Unverändert (gleicher Inhalt und Bezug) wird nichts geschrieben.
  @override
  void merkeEntwurf(
    String schluessel,
    Uint8List inhalt, {
    KonfigurationsStand? bezug,
  }) => _db.transaktion(() {
    if (bezug != null && _kopfMit(bezug.kennung) == null) {
      throw KonfigurationUnbekannt(bezug.nummer, bezug.version);
    }
    final nummer = bezug?.nummer.wert ?? '';
    final version = bezug?.version ?? 0;
    final alt = _zwischenstand(schluessel);
    if (alt != null &&
        alt.nummer == nummer &&
        alt.version == version &&
        _gleich(alt.inhalt, inhalt)) {
      return;
    }
    _db.speichere(
      (alt ?? Zwischenstand(schluessel: schluessel, inhalt: inhalt))
        ..inhalt = inhalt
        ..nummer = nummer
        ..version = version
        ..ablaufAm = uhr().add(entwurfFrist).millisecondsSinceEpoch,
    );
  });

  /// Entwurf von [schluessel]; `null`, wenn es keinen gibt oder seine Frist
  /// abgelaufen ist. Der Bezug kommt mit Prüfcode zurück – der
  /// Sitzungsschlüssel ist selbst geheim, und gemerkt wird ein Bezug nur
  /// mit passendem Code.
  @override
  Entwurf? entwurf(String schluessel) {
    final z = _zwischenstand(schluessel);
    if (z == null || z.ablaufAm <= uhr().millisecondsSinceEpoch) return null;
    return (
      inhalt: z.inhalt,
      bezug: switch (_kopf(Konfigurationsnummer(z.nummer))) {
        final kopf? => _stand(kopf, z.version),
        null => null,
      },
    );
  }

  /// Kopf mit der nächsten laufenden Nummer des heutigen Tages.
  Konfiguration _neuerKopf() {
    final jetzt = uhr();
    final tag = Konfigurationsnummer.tagAus(jetzt);
    final abfrage =
        _db.store
            .box<Konfiguration>()
            .query(Konfiguration_.tag.equals(tag))
            .order(Konfiguration_.laufend, flags: Order.descending)
            .build()
          ..limit = 1;
    final int laufend;
    try {
      laufend = (abfrage.findFirst()?.laufend ?? 0) + 1;
    } finally {
      abfrage.close();
    }
    final nummer = Konfigurationsnummer.vergib(jetzt, laufend);
    return Konfiguration(nummer: nummer.wert, tag: tag, laufend: laufend)
      ..pruefcode = Pruefcode.zufaellig(_zufall).wert;
  }

  /// Kopf zu [kennung], wenn der Prüfcode passt (Vergleich in konstanter
  /// Zeit).
  Konfiguration? _kopfMit(Konfigurationskennung kennung) {
    final kopf = _kopf(kennung.nummer);
    if (kopf == null) return null;
    return Pruefcode(kopf.pruefcode).gleicht(kennung.pruefcode) ? kopf : null;
  }

  Konfiguration? _kopf(Konfigurationsnummer nummer) => _erster(
    _db.store.box<Konfiguration>().query(
      Konfiguration_.nummer
          .equals(nummer.wert)
          .and(Konfiguration_.geloeschtAm.isNull()),
    ),
  );

  KonfigurationsVersion? _version(String nummer, int version) => _erster(
    _db.store.box<KonfigurationsVersion>().query(
      KonfigurationsVersion_.schluessel
          .equals('$nummer/$version')
          .and(KonfigurationsVersion_.geloeschtAm.isNull()),
    ),
  );

  Zwischenstand? _zwischenstand(String schluessel) => _erster(
    _db.store.box<Zwischenstand>().query(
      Zwischenstand_.schluessel
          .equals(schluessel)
          .and(Zwischenstand_.geloeschtAm.isNull()),
    ),
  );

  static T? _erster<T>(QueryBuilder<T> abfrage) {
    final q = abfrage.build();
    try {
      return q.findFirst();
    } finally {
      q.close();
    }
  }

  static KonfigurationsStand _stand(Konfiguration kopf, int version) =>
      KonfigurationsStand(_kennung(kopf), version);

  static Konfigurationskennung _kennung(Konfiguration kopf) =>
      Konfigurationskennung(
        Konfigurationsnummer(kopf.nummer),
        Pruefcode(kopf.pruefcode),
      );

  static bool _gleich(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
