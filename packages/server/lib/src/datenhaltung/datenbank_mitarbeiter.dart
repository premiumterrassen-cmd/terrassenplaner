import '../zugriff/mitarbeiter_verzeichnis.dart';
import '../zugriff/mitarbeiter_zugang.dart';
import 'datenbank.dart';
import 'entitaeten.dart';

/// Mitarbeiter-Zugänge aus der ObjectBox-Datenbank (Entität [Benutzer]).
class DatenbankMitarbeiter implements MitarbeiterQuelle {
  DatenbankMitarbeiter(this.datenbank);

  final Datenbank datenbank;

  @override
  MitarbeiterZugang? finde(String authId) {
    final b = datenbank.benutzer(authId);
    if (b == null) return null;
    return MitarbeiterZugang(
      authId: b.authId,
      salt: b.salt,
      iterationen: b.iterationen,
      storedKey: b.storedKey,
      serverKey: b.serverKey,
    );
  }

  /// Übernimmt Zugänge (z. B. aus der Mitarbeiter-Datei): neue werden
  /// angelegt, vorhandene mit geänderten Schlüsseln aktualisiert, gleiche
  /// bleiben unverändert. Liefert die Zahl der geschriebenen Zugänge.
  int uebernimm(Iterable<MitarbeiterZugang> zugaenge) {
    var geschrieben = 0;
    for (final z in zugaenge) {
      final vorhanden = datenbank.benutzer(z.authId);
      if (vorhanden != null &&
          vorhanden.salt == z.salt &&
          vorhanden.iterationen == z.iterationen &&
          vorhanden.storedKey == z.storedKey &&
          vorhanden.serverKey == z.serverKey) {
        continue;
      }
      final b =
          (vorhanden ??
                Benutzer(
                  authId: z.authId,
                  salt: z.salt,
                  iterationen: z.iterationen,
                  storedKey: z.storedKey,
                  serverKey: z.serverKey,
                ))
            ..salt = z.salt
            ..iterationen = z.iterationen
            ..storedKey = z.storedKey
            ..serverKey = z.serverKey;
      datenbank.speichere(b);
      geschrieben++;
    }
    return geschrieben;
  }
}
