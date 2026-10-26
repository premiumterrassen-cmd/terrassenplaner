/// Eingaben einer Planung zu einem Zeitpunkt (M3-03) – unveränderlich, damit
/// Rückgängig exakt auf einen früheren Stand springen kann. Ab M4 kommen
/// Grundriss, Belag, Unterkonstruktion usw. als Felder hinzu; berechnet wird
/// daraus auf dem Server.
base class Planungsstand {
  const Planungsstand.leer();

  // Gleich nur bei gleichem Typ: abgeleitete Stände (Tests, später M4)
  // gelten nie als gleich zum leeren Stand.
  @override
  bool operator ==(Object other) =>
      other is Planungsstand && other.runtimeType == runtimeType;

  @override
  int get hashCode => runtimeType.hashCode;
}
