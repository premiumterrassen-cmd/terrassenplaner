import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:objectbox/internal.dart' show InternalStoreAccess;
import 'package:path/path.dart' as p;

import '../../objectbox.g.dart';

/// Speichert und liest Datensätze als rohe FlatBuffers direkt über
/// objectbox-c – ohne Umweg über Dart-Objekte (#110, Schritt 3).
///
/// Die Bytes haben das ObjectBox-Speicherformat (erzeugt mit
/// `transport.g.dart` im domain-Paket); es entfällt jedes Objekt-Mapping.
/// Ersatz für den künftigen `connectanum_objectbox_adapter`: Bis connectanum
/// native Puffer (Leases) direkt übergibt, wird beim Schreiben einmal in
/// nativen Speicher und beim Lesen einmal in den Dart-Heap kopiert.
final class RohSpeicher {
  /// Bindet sich an den geöffneten [store] (eigene Store-Referenz).
  RohSpeicher(Store store)
    : _store = InternalStoreAccess.clone(store).cast<_ObxStore>();

  final Pointer<_ObxStore> _store;

  /// ObjectBox-Entitäts-ID des Typs [T] (für [speichere] und [lies]).
  static int entitaetId<T>(Store store) =>
      InternalStoreAccess.entityDef<T>(store).model.id.id;

  /// Speichert alle [datensaetze] in einer Schreibtransaktion und liefert
  /// ihre neuen IDs. Schlägt einer fehl, wird nichts gespeichert.
  List<int> speichere(int entitaet, Iterable<Uint8List> datensaetze) {
    final liste = datensaetze.toList(growable: false);
    final groesste = liste.fold(1, (m, d) => d.length > m ? d.length : m);
    final puffer = malloc<Uint8>(groesste);
    final txn = _pruefe(_txnWrite(_store));
    var uebernommen = false;
    try {
      final cursor = _pruefe(_cursor(txn, entitaet));
      final List<int> ids;
      try {
        ids = [
          for (final daten in liste)
            _id(
              _cursorPut(
                cursor,
                _kopiere(daten, puffer),
                daten.length,
                _putModePut,
              ),
            ),
        ];
      } finally {
        _cursorClose(cursor);
      }
      // obx_txn_success schreibt fest und gibt die Transaktion selbst frei.
      uebernommen = true;
      _ok(_txnSuccess(txn));
      return ids;
    } finally {
      if (!uebernommen) _txnClose(txn);
      malloc.free(puffer);
    }
  }

  /// Liest den Datensatz [id] als FlatBuffer oder `null`, wenn es ihn nicht
  /// gibt.
  Uint8List? lies(int entitaet, int id) {
    final txn = _pruefe(_txnRead(_store));
    final daten = calloc<Pointer<Uint8>>();
    final laenge = calloc<Size>();
    try {
      final cursor = _pruefe(_cursor(txn, entitaet));
      final int status;
      try {
        status = _cursorGet(cursor, id, daten, laenge);
      } finally {
        _cursorClose(cursor);
      }
      if (status == _nichtGefunden) return null;
      _ok(status);
      return Uint8List.fromList(daten.value.asTypedList(laenge.value));
    } finally {
      calloc
        ..free(daten)
        ..free(laenge);
      _txnClose(txn);
    }
  }

  static Pointer<Uint8> _kopiere(Uint8List daten, Pointer<Uint8> ziel) {
    ziel.asTypedList(daten.length).setAll(0, daten);
    return ziel;
  }

  /// Gibt die Store-Referenz frei; der ursprüngliche Store bleibt offen.
  void schliesse() => _storeClose(_store);

  static Pointer<T> _pruefe<T extends NativeType>(Pointer<T> zeiger) {
    if (zeiger == nullptr) throw _fehler();
    return zeiger;
  }

  static int _id(int id) => id == 0 ? throw _fehler() : id;

  static void _ok(int status) {
    if (status != 0) throw _fehler();
  }

  static ObjectBoxException _fehler() => ObjectBoxException(
    '${_lastErrorCode()}: ${_lastErrorMessage().toDartString()}',
  );

  static const _putModePut = 1;
  static const _nichtGefunden = 404;
}

final class _ObxStore extends Opaque {}

final class _ObxCursor extends Opaque {}

final class _ObxTxn extends Opaque {}

/// Dieselbe Bibliothek, die `package:objectbox` lädt.
final DynamicLibrary _bibliothek = DynamicLibrary.open(
  objectBoxBibliothek(
    Directory.current.path,
    Platform.isMacOS ? 'libobjectbox.dylib' : 'libobjectbox.so',
    (pfad) => File(pfad).existsSync(),
  ),
);

/// Pfad der ObjectBox-Bibliothek in derselben Reihenfolge wie
/// `package:objectbox`: zuerst `lib/` im Arbeitsverzeichnis, sonst der
/// Standard-Suchpfad des Systems (z. B. `LD_LIBRARY_PATH` auf dem Server).
String objectBoxBibliothek(
  String arbeitsverzeichnis,
  String name,
  bool Function(String pfad) vorhanden,
) {
  final lokal = p.join(arbeitsverzeichnis, 'lib', name);
  return vorhanden(lokal) ? lokal : name;
}

final _cursor = _bibliothek
    .lookupFunction<
      Pointer<_ObxCursor> Function(Pointer<_ObxTxn>, Uint32),
      Pointer<_ObxCursor> Function(Pointer<_ObxTxn>, int)
    >('obx_cursor', isLeaf: true);

final _cursorPut = _bibliothek
    .lookupFunction<
      Uint64 Function(Pointer<_ObxCursor>, Pointer<Uint8>, Size, Int32),
      int Function(Pointer<_ObxCursor>, Pointer<Uint8>, int, int)
    >('obx_cursor_put_object4', isLeaf: true);

final _cursorGet = _bibliothek
    .lookupFunction<
      Int32 Function(
        Pointer<_ObxCursor>,
        Uint64,
        Pointer<Pointer<Uint8>>,
        Pointer<Size>,
      ),
      int Function(
        Pointer<_ObxCursor>,
        int,
        Pointer<Pointer<Uint8>>,
        Pointer<Size>,
      )
    >('obx_cursor_get', isLeaf: true);

final _cursorClose = _bibliothek
    .lookupFunction<
      Int32 Function(Pointer<_ObxCursor>),
      int Function(Pointer<_ObxCursor>)
    >('obx_cursor_close', isLeaf: true);

final _txnWrite = _bibliothek
    .lookupFunction<
      Pointer<_ObxTxn> Function(Pointer<_ObxStore>),
      Pointer<_ObxTxn> Function(Pointer<_ObxStore>)
    >('obx_txn_write', isLeaf: true);

final _txnRead = _bibliothek
    .lookupFunction<
      Pointer<_ObxTxn> Function(Pointer<_ObxStore>),
      Pointer<_ObxTxn> Function(Pointer<_ObxStore>)
    >('obx_txn_read', isLeaf: true);

final _txnSuccess = _bibliothek
    .lookupFunction<
      Int32 Function(Pointer<_ObxTxn>),
      int Function(Pointer<_ObxTxn>)
    >('obx_txn_success', isLeaf: true);

final _txnClose = _bibliothek
    .lookupFunction<
      Int32 Function(Pointer<_ObxTxn>),
      int Function(Pointer<_ObxTxn>)
    >('obx_txn_close', isLeaf: true);

final _storeClose = _bibliothek
    .lookupFunction<
      Int32 Function(Pointer<_ObxStore>),
      int Function(Pointer<_ObxStore>)
    >('obx_store_close');

final _lastErrorCode = _bibliothek
    .lookupFunction<Int32 Function(), int Function()>(
      'obx_last_error_code',
      isLeaf: true,
    );

final _lastErrorMessage = _bibliothek
    .lookupFunction<Pointer<Utf8> Function(), Pointer<Utf8> Function()>(
      'obx_last_error_message',
      isLeaf: true,
    );
