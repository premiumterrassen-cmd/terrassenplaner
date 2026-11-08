import 'dart:io';

/// Speicher (RSS) und verbrauchte CPU-Zeit eines Prozesses (M10-02), gelesen
/// mit `ps` – auf macOS und Linux gleich.
final class Prozessmessung {
  const Prozessmessung({required this.speicherKb, required this.cpuZeit});

  /// Liest die Werte des Prozesses [pid] mit [ps] (Standard: `ps` des
  /// Systems); `null`, wenn es den Prozess nicht gibt.
  static Future<Prozessmessung?> lies(
    int pid, {
    Future<ProcessResult> Function(String, List<String>) ps = Process.run,
  }) async {
    final ergebnis = await ps('ps', ['-o', 'rss=,cputime=', '-p', '$pid']);
    final felder = '${ergebnis.stdout}'.trim().split(RegExp(r'\s+'));
    if (ergebnis.exitCode != 0 || felder.length != 2) return null;
    return Prozessmessung(
      speicherKb: int.parse(felder[0]),
      cpuZeit: liesCpuZeit(felder[1]),
    );
  }

  /// CPU-Zeit im Format von `ps`: `[TT-][hh:]mm:ss[.hh]` (Linux
  /// `00:01:02`, macOS `1:02.50`).
  static Duration liesCpuZeit(String text) {
    final [...tageTeil, uhr] = text.split('-');
    final tage = tageTeil.isEmpty ? 0 : int.parse(tageTeil.single);
    var sekunden = 0.0;
    for (final teil in uhr.split(':')) {
      sekunden = sekunden * 60 + double.parse(teil);
    }
    return Duration(microseconds: ((tage * 86400 + sekunden) * 1e6).round());
  }

  /// Resident Set Size in KiB.
  final int speicherKb;

  /// Seit dem Start verbrauchte CPU-Zeit (alle Threads).
  final Duration cpuZeit;

  /// RSS in MiB, eine Nachkommastelle.
  double get speicherMb => (speicherKb / 102.4).round() / 10;
}
