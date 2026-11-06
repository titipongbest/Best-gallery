import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Best gallery: reasons the app closed by itself, and app errors, kept on the device
final CrashLogService crashLogService = CrashLogService._private();

class CrashLogService {
  new _private();

  static const _channel = MethodChannel('deckers.thibault/aves/crash_log');

  Future<String> read() async {
    try {
      return await _channel.invokeMethod<String>('read') ?? '';
    } on PlatformException catch (e) {
      return 'failed to read the log: ${e.message}';
    }
  }

  Future<void> record(String title, Object error, StackTrace? stack) async {
    try {
      await _channel.invokeMethod('append', {
        'title': title,
        'details': '$error\n${stack ?? ''}',
      });
    } catch (e) {
      debugPrint('failed to record error=$error with exception=$e');
    }
  }

  Future<void> clear() async {
    try {
      await _channel.invokeMethod('clear');
    } on PlatformException catch (e) {
      debugPrint('failed to clear crash log with exception=$e');
    }
  }
}
