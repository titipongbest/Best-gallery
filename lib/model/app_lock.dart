import 'package:aves/services/common/services.dart';
import 'package:flutter/foundation.dart';

// Best gallery: app lock with a PIN, asked when opening the app
final AppLock appLock = AppLock._private();

class AppLock {
  new _private();

  static const _pinKey = 'best_gallery_app_lock_pin';

  // lock again when coming back to the app after this delay in the background,
  // short enough to protect the app when reopened from recent apps,
  // long enough not to lock during system dialogs (e.g. permission requests)
  static const relockDelay = Duration(seconds: 30);

  final ValueNotifier<bool> enabled = ValueNotifier(false);
  final ValueNotifier<bool> locked = ValueNotifier(false);

  String? _pin;
  DateTime? _backgroundSince;

  Future<void> init() async {
    _pin = await securityService.readValue<String>(_pinKey);
    enabled.value = _pin?.isNotEmpty == true;
    locked.value = enabled.value;
  }

  bool check(String pin) => enabled.value && pin == _pin;

  bool unlock(String pin) {
    if (!check(pin)) return false;
    locked.value = false;
    return true;
  }

  // unlock after a successful fingerprint / device credential check
  void unlockWithSystemAuth() {
    if (enabled.value) locked.value = false;
  }

  // set a PIN to enable the lock, or `null` to disable it
  Future<bool> setPin(String? pin) async {
    final value = pin?.isNotEmpty == true ? pin : null;
    final success = await securityService.writeValue<String>(_pinKey, value);
    if (success) {
      _pin = value;
      enabled.value = value != null;
      if (value == null) locked.value = false;
    }
    return success;
  }

  void onBackground() => _backgroundSince ??= DateTime.now();

  void onForeground() {
    final since = _backgroundSince;
    _backgroundSince = null;
    if (enabled.value && since != null && DateTime.now().difference(since) >= relockDelay) {
      locked.value = true;
    }
  }
}
