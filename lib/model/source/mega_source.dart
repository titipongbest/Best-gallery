import 'dart:async';

import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/entry/extensions/keys.dart';
import 'package:aves/model/entry/origins.dart';
import 'package:aves/model/source/analysis_controller.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/services/common/services.dart';
import 'package:aves/services/mega_service.dart';
import 'package:aves_model/aves_model.dart';
import 'package:flutter/foundation.dart';

// Source for the media files of a single MEGA folder.
// Entries are created from the folder listing right away (MEGA thumbnails are available without downloading),
// then completed in the background with their dimensions and dates, read from the beginning of each file.
class MegaSource extends CollectionSource {
  final String folderHandle;
  final String folderName;

  SourceScope _loadedScope, _targetScope;
  bool _disposed = false;

  new({required this.folderHandle, required this.folderName});

  static const _detailConcurrency = 3;

  @override
  set canAnalyze(bool enabled) {}

  @override
  SourceScope get loadedScope => _loadedScope;

  @override
  SourceScope get targetScope => _targetScope;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  Future<void> init({
    required SourceScope scope,
    AnalysisController? analysisController,
    bool loadTopEntriesFirst = false,
  }) async {
    _targetScope = scope;
    state = SourceState.loading;
    await loadDates();
    await _load(refresh: false);
    _loadedScope = scope;
  }

  Future<void> reload() => _load(refresh: true);

  Future<void> _load({required bool refresh}) async {
    state = SourceState.loading;
    try {
      final listing = await megaService.listFolder(handle: folderHandle, refresh: refresh);
      if (_disposed) return;
      final entries = listing.files.map((map) {
        final fields = Map.of(map);
        fields[EntryFields.origin] = EntryOrigins.mega;
        return AvesEntry.fromMap(fields);
      }).toSet();
      clearEntries();
      addEntries(entries);
      updateDerivedFilters(entries);
      state = SourceState.ready;
      unawaited(_fetchDetails(entries));
    } catch (error) {
      debugPrint('$runtimeType failed to load folder=$folderHandle with error=$error');
      state = SourceState.ready;
      rethrow;
    }
  }

  // completes entries with dimensions, orientation and dates
  Future<void> _fetchDetails(Set<AvesEntry> entries) async {
    final todo = entries.toList();
    final total = todo.length;
    var done = 0;
    setProgress(done: done, total: total);

    Future<void> worker() async {
      while (todo.isNotEmpty && !_disposed) {
        final entry = todo.removeAt(0);
        try {
          final detailed = await mediaFetchService.getEntry(entry.uri, entry.sourceMimeType, allowUnsized: true);
          if (detailed != null && !_disposed) {
            await entry.applyNewFields({
              EntryFields.width: detailed.width,
              EntryFields.height: detailed.height,
              EntryFields.sourceRotationDegrees: detailed.sourceRotationDegrees,
              EntryFields.sourceDateTakenMillis: ?detailed.sourceDateTakenMillis,
              EntryFields.durationMillis: ?detailed.durationMillis,
            }, persist: false);
          }
        } catch (error) {
          debugPrint('$runtimeType failed to get details for uri=${entry.uri} with error=$error');
        }
        done++;
        if (!_disposed) setProgress(done: done, total: total);
      }
    }

    await Future.wait(List.generate(_detailConcurrency, (_) => worker()));
    if (_disposed) return;
    invalidateEntries();
    updateDerivedFilters(entries);
  }

  @override
  Future<void> checkForChanges() async {}

  @override
  Future<Set<String>> refreshUris(Set<String> changedUris, {AnalysisController? analysisController}) async => changedUris;
}
