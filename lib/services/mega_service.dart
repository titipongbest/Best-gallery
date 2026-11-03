import 'package:aves/services/common/channel.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

final MegaService megaService = PlatformMegaService();

// error raised by the MEGA API or the platform side
class MegaException implements Exception {
  // MEGA API error code (e.g. -9 for wrong credentials, -26 when a 2FA code is required), if any
  final int? code;
  final bool isQuotaExceeded;
  final String? message;

  const new({this.code, this.isQuotaExceeded = false, this.message});

  static const int codeNotFound = -9;
  static const int codeBlocked = -16;
  static const int codeSessionExpired = -15;
  static const int codeMfaRequired = -26;

  bool get isMfaRequired => code == codeMfaRequired;

  bool get isWrongCredentials => code == codeNotFound;

  bool get isSessionExpired => code == codeSessionExpired;

  factory fromPlatform(PlatformException e) {
    final details = e.details;
    return MegaException(
      code: e.code.endsWith('-mega') && details is int ? details : null,
      isQuotaExceeded: e.code.endsWith('-quota'),
      message: e.message,
    );
  }

  @override
  String toString() => 'MegaException{code=$code, isQuotaExceeded=$isQuotaExceeded, message=$message}';
}

class MegaFolderRef {
  final String handle;
  final String name;

  const new({required this.handle, required this.name});

  factory fromMap(Map map) => MegaFolderRef(
    handle: map['handle'] as String,
    name: map['name'] as String,
  );
}

class MegaFolderSummary {
  final String handle;
  final String name;
  final int folderCount;
  final int mediaCount;
  final String? coverUri;

  const new({
    required this.handle,
    required this.name,
    required this.folderCount,
    required this.mediaCount,
    required this.coverUri,
  });

  factory fromMap(Map map) => MegaFolderSummary(
    handle: map['handle'] as String,
    name: map['name'] as String,
    folderCount: map['folderCount'] as int? ?? 0,
    mediaCount: map['mediaCount'] as int? ?? 0,
    coverUri: map['coverUri'] as String?,
  );
}

class MegaFolderListing {
  final String handle;
  final String name;
  final bool isRoot;

  // folders from the cloud drive root (excluded) to this folder (included)
  final List<MegaFolderRef> path;
  final List<MegaFolderSummary> folders;

  // platform entry maps, without dimensions
  final List<Map> files;

  const new({
    required this.handle,
    required this.name,
    required this.isRoot,
    required this.path,
    required this.folders,
    required this.files,
  });

  factory fromMap(Map map) => MegaFolderListing(
    handle: map['handle'] as String,
    name: map['name'] as String,
    isRoot: map['isRoot'] as bool? ?? false,
    path: (map['path'] as List? ?? []).cast<Map>().map(MegaFolderRef.fromMap).toList(),
    folders: (map['folders'] as List? ?? []).cast<Map>().map(MegaFolderSummary.fromMap).toList(),
    files: (map['files'] as List? ?? []).cast<Map>(),
  );
}

abstract class MegaService {
  // email of the logged in account, if any
  Future<String?> getAccountEmail();

  // throws [MegaException]
  Future<String> login({required String email, required String password, String? mfaCode});

  Future<void> logout();

  // root folder when `handle` is null, throws [MegaException]
  Future<MegaFolderListing> listFolder({String? handle, bool refresh = false});

  Future<void> clearCache();

  // path of the decrypted file in the cache, downloaded if needed
  Future<String?> getLocalFilePath(String uri);
}

class PlatformMegaService implements MegaService {
  static const _platform = AvesMethodChannel('deckers.thibault/aves/mega');

  @override
  Future<String?> getAccountEmail() async {
    try {
      final result = await _platform.invokeMethod('getAccount');
      if (result is Map) return result['email'] as String?;
    } on PlatformException catch (_) {
      // ignore
    }
    return null;
  }

  @override
  Future<String> login({required String email, required String password, String? mfaCode}) async {
    try {
      final result = await _platform.invokeMethod('login', <String, dynamic>{
        'email': email,
        'password': password,
        'mfaCode': mfaCode,
      });
      return (result as Map)['email'] as String;
    } on PlatformException catch (e) {
      throw MegaException.fromPlatform(e);
    }
  }

  @override
  Future<void> logout() async {
    try {
      await _platform.invokeMethod('logout');
    } on PlatformException catch (_) {
      // ignore
    }
  }

  @override
  Future<MegaFolderListing> listFolder({String? handle, bool refresh = false}) async {
    try {
      final result = await _platform.invokeMethod('listFolder', <String, dynamic>{
        'handle': handle,
        'refresh': refresh,
      });
      return MegaFolderListing.fromMap(result as Map);
    } on PlatformException catch (e) {
      throw MegaException.fromPlatform(e);
    }
  }

  @override
  Future<void> clearCache() async {
    try {
      await _platform.invokeMethod('clearCache');
    } on PlatformException catch (_) {
      // ignore
    }
  }

  @override
  Future<String?> getLocalFilePath(String uri) async {
    try {
      return await _platform.invokeMethod<String>('getLocalFile', <String, dynamic>{'uri': uri});
    } on PlatformException catch (e) {
      debugPrint('failed to get local file for uri=$uri with exception=$e');
      return null;
    }
  }
}
