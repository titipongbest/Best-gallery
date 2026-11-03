import 'package:aves/model/app_lock.dart';
import 'package:aves/services/common/services.dart';
import 'package:flutter/widgets.dart';

// Best gallery: PIN asked when opening the MEGA pages
final MegaLock megaLock = MegaLock._private();

class MegaLock {
  new _private();

  static const _pinKey = 'best_gallery_mega_lock_pin';

  final ValueNotifier<bool> enabled = ValueNotifier(false);

  // whether the lock page covers the MEGA pages
  final ValueNotifier<bool> locked = ValueNotifier(false);

  String? _pin;
  int _openPages = 0;
  DateTime? _backgroundSince;

  // called by the MEGA page to leave the MEGA pages when the lock page is dismissed
  VoidCallback? onCancel;

  Future<void> init() async {
    _pin = await securityService.readValue<String>(_pinKey);
    enabled.value = _pin?.isNotEmpty == true;
  }

  bool check(String pin) => enabled.value && pin == _pin;

  bool unlock(String pin) {
    if (!check(pin)) return false;
    locked.value = false;
    return true;
  }

  // unlock after a successful fingerprint / device credential check
  void unlockWithSystemAuth() => locked.value = false;

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

  // the PIN is asked each time the MEGA page is opened
  void onPageOpened() {
    _openPages++;
    if (_openPages == 1 && enabled.value) {
      // the page is opened during a build, and the lock gate cannot rebuild during it.
      // the first frame only shows the page loading indicator
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_openPages > 0 && enabled.value) locked.value = true;
      });
    }
  }

  void onPageClosed() {
    _openPages = (_openPages - 1).clamp(0, 1 << 30);
    if (_openPages == 0) {
      locked.value = false;
      onCancel = null;
    }
  }

  void cancel() {
    final callback = onCancel;
    locked.value = false;
    callback?.call();
  }

  void onBackground() => _backgroundSince ??= DateTime.now();

  void onForeground() {
    final since = _backgroundSince;
    _backgroundSince = null;
    if (enabled.value && _openPages > 0 && since != null && DateTime.now().difference(since) >= AppLock.relockDelay) {
      locked.value = true;
    }
  }
}
