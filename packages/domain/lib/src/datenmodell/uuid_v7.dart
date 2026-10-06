import 'dart:math';

/// Erzeugt UUIDv7 (RFC 9562): 48 Bit Unix-Millisekunden, Version 7, Variante
/// 10, Rest zufällig – zeitlich sortierbar und ohne zentrale Vergabe
/// eindeutig (docs/architektur/datenmodell.md, globale `uid`).
class UuidV7 {
  UuidV7({DateTime Function()? uhr, Random? zufall})
    : _uhr = uhr ?? DateTime.now,
      _zufall = zufall ?? Random.secure();

  final DateTime Function() _uhr;
  final Random _zufall;

  /// Neue UUID als Text `xxxxxxxx-xxxx-7xxx-yxxx-xxxxxxxxxxxx` (klein).
  String neu() {
    final ms = _uhr().millisecondsSinceEpoch;
    final bytes = List<int>.generate(16, (_) => _zufall.nextInt(256));
    for (var i = 0; i < 6; i++) {
      bytes[i] = (ms >> (8 * (5 - i))) & 0xff;
    }
    bytes[6] = 0x70 | (bytes[6] & 0x0f);
    bytes[8] = 0x80 | (bytes[8] & 0x3f);
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  /// Millisekunden-Zeitstempel einer UUIDv7.
  static int zeitstempel(String uuid) =>
      int.parse(uuid.replaceAll('-', '').substring(0, 12), radix: 16);
}
