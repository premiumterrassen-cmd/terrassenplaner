import 'einstellungs_speicher.dart';

/// Außerhalb des Browsers (Dart-VM, Unit-Tests): nur für die Sitzung.
EinstellungsSpeicher browserSpeicher() => FluechtigerSpeicher();
