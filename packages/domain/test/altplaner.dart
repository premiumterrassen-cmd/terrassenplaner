import 'package:terrassenplaner_domain/terrassenplaner_domain.dart';

/// Fuge des alten Planers (5 mm): Die Paritätstests der Verlegung gegen
/// seine Ergebnisse (Referenzkonfigurationen M1-03, Referenzfälle M1-02)
/// rechnen mit ihr, damit sie den Rechenweg prüfen. Der neue Planer
/// verlegt mit 6 mm ([fuge], Planungsregeln Alexander (Planungskern v6,
/// 11.11.2026) Regel 1.2, Entscheidung Alexander 11.11.2026).
const altplanerFuge = Millimeter(5);
