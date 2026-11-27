import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores the app PIN as a salted PBKDF2-SHA256 hash. The PIN itself is never stored.
class PinStore {
  PinStore._();

  static const _key = 'monova.pin';
  static const _secure = FlutterSecureStorage();
  static const _iterations = 100000;
  static final _random = Random.secure();

  static Future<String?> _read() async {
    if (kIsWeb) return (await SharedPreferences.getInstance()).getString(_key);
    return _secure.read(key: _key);
  }

  static Future<void> _write(String? value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      if (value == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, value);
      }
      return;
    }
    if (value == null) {
      await _secure.delete(key: _key);
    } else {
      await _secure.write(key: _key, value: value);
    }
  }

  static Future<bool> isSet() async => (await _read()) != null;

  static Future<void> setPin(String pin) async {
    final salt = List<int>.generate(16, (_) => _random.nextInt(256));
    final hash = await _hash(pin, salt, _iterations);
    await _write(
      jsonEncode({
        'salt': base64Encode(salt),
        'hash': base64Encode(hash),
        'iterations': _iterations,
      }),
    );
  }

  static Future<bool> matches(String pin) async {
    final raw = await _read();
    if (raw == null) return false;
    final stored = jsonDecode(raw) as Map<String, dynamic>;
    final hash = await _hash(
      pin,
      base64Decode(stored['salt'] as String),
      stored['iterations'] as int,
    );
    return _sameBytes(hash, base64Decode(stored['hash'] as String));
  }

  static Future<void> clear() => _write(null);

  static Future<List<int>> _hash(
    String pin,
    List<int> salt,
    int iterations,
  ) async {
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: pin, nonce: salt);
    return key.extractBytes();
  }

  /// Compares without stopping at the first difference, so timing does not reveal how close a guess was.
  static bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

enum LockStatus { checking, disabled, locked, unlocked }

class AppLockState {
  const AppLockState({required this.status, this.failures = 0, this.waitUntil});

  final LockStatus status;
  final int failures;
  final DateTime? waitUntil;

  AppLockState copyWith({
    LockStatus? status,
    int? failures,
    DateTime? waitUntil,
    bool clearWait = false,
  }) => AppLockState(
    status: status ?? this.status,
    failures: failures ?? this.failures,
    waitUntil: clearWait ? null : (waitUntil ?? this.waitUntil),
  );
}

/// Locks the app when a PIN is set. After five wrong PINs the app waits longer before the next try.
class AppLockController extends Notifier<AppLockState> {
  @override
  AppLockState build() {
    _init();
    return const AppLockState(status: LockStatus.checking);
  }

  Future<void> _init() async {
    final set = await PinStore.isSet();
    state = AppLockState(status: set ? LockStatus.locked : LockStatus.disabled);
  }

  /// Returns null when unlocked, or the message to show.
  Future<String?> tryUnlock(String pin) async {
    final wait = state.waitUntil;
    if (wait != null && DateTime.now().isBefore(wait)) {
      final seconds = wait.difference(DateTime.now()).inSeconds + 1;
      return 'Too many wrong PINs. Try again in $seconds seconds.';
    }
    if (await PinStore.matches(pin)) {
      state = const AppLockState(status: LockStatus.unlocked);
      return null;
    }
    final failures = state.failures + 1;
    final delay = failures >= 5
        ? Duration(seconds: 30 * (failures - 4))
        : Duration.zero;
    state = state.copyWith(
      failures: failures,
      waitUntil: delay == Duration.zero ? null : DateTime.now().add(delay),
      clearWait: delay == Duration.zero,
    );
    return 'Wrong PIN.';
  }

  /// Called when the app goes to the background, so the next open asks for the PIN.
  void lockIfSet() {
    if (state.status == LockStatus.unlocked)
      state = state.copyWith(status: LockStatus.locked);
  }

  Future<void> setPin(String pin) async {
    await PinStore.setPin(pin);
    state = const AppLockState(status: LockStatus.unlocked);
  }

  Future<void> removePin() async {
    await PinStore.clear();
    state = const AppLockState(status: LockStatus.disabled);
  }

  /// Used after the app data has been erased, so the lock is no longer needed.
  Future<void> forgetAll() async {
    await PinStore.clear();
    state = const AppLockState(status: LockStatus.disabled);
  }
}

final appLockProvider = NotifierProvider<AppLockController, AppLockState>(
  AppLockController.new,
);
