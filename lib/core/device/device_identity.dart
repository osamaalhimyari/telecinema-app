import 'dart:math';

import '/logic/storage/key_value_storage.dart';
import '/logic/storage/shared_prefs_storage.dart';

/// A stable, per-install identifier for this device, persisted locally and sent
/// to the server on every request (the `X-Device-Id` header). It lets the
/// server tie long-running operations — link/torrent downloads — to the device
/// that started them, so the app can list and cancel *its* operations even after
/// a socket reconnect throws away the realtime token it had.
///
/// It is a random UUID generated once and kept in [KeyValueStorage]; it is not
/// derived from hardware, so it carries no identifying device info and simply
/// survives reconnects and app restarts.
class DeviceIdentity {
  DeviceIdentity(this._storage);

  final KeyValueStorage _storage;

  String? _cached;

  /// The persisted id, generating and storing one on first use.
  String get id {
    final cached = _cached;
    if (cached != null) return cached;

    final saved = _storage.getString(StorageKeys.deviceId);
    if (saved != null && saved.isNotEmpty) {
      _cached = saved;
      return saved;
    }

    final fresh = _generateUuidV4();
    _cached = fresh;
    // Fire-and-forget: the in-memory cache already holds it for this run, and
    // the next launch reads whatever landed on disk.
    _storage.setString(StorageKeys.deviceId, fresh);
    return fresh;
  }

  /// A random RFC-4122 v4 UUID using a cryptographic RNG — no extra dependency.
  static String _generateUuidV4() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
    String hex(int start, int end) {
      final b = StringBuffer();
      for (var i = start; i < end; i++) {
        b.write(bytes[i].toRadixString(16).padLeft(2, '0'));
      }
      return b.toString();
    }

    return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
  }
}

/// Process-wide holder so the (lazily-built) [DioApiClient] interceptor can read
/// the device id without a constructor dependency. Set once during DI startup.
class DeviceIdHolder {
  DeviceIdHolder._();

  static String? current;
}
