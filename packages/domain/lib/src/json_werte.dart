/// Wandelt Maps und Listen einer WAMP-Nutzlast in JSON-Typen (M2-06): Der
/// FlatBuffers-Serialisierer liefert verschachtelte Maps als
/// `Map<Object?, Object?>`, die `ausJson`-Leser erwarten `Map<String, Object?>`.
Object? alsJsonWert(Object? wert) => switch (wert) {
  Map() => <String, Object?>{
    for (final MapEntry(:key, :value) in wert.entries)
      key! as String: alsJsonWert(value),
  },
  List() => [for (final w in wert) alsJsonWert(w)],
  _ => wert,
};

/// [alsJsonWert] für ein JSON-Objekt.
Map<String, Object?> alsJsonObjekt(Object? wert) =>
    alsJsonWert(wert)! as Map<String, Object?>;
