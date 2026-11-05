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

  // media files matching this name in the whole cloud drive, instead of the folder content
  final String? searchQuery;

  SourceScope _loadedScope, _targetScope;
  bool _disposed = false;

  new({required this.folderHandle, required this.folderName, this.searchQuery});

  static const _detailConcurrency = 4;
  static const _batchSize = 12;
  static const _batchDelay = Duration(milliseconds: 800);

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
      final query = searchQuery;
      final listing = query != null ? await megaService.search(query) : await megaService.listFolder(handle: folderHandle, refresh: refresh);
      if (_disposed) return;
      final knownUris = listing.files.where((map) => map['megaDetailsKnown'] == true).map((map) => map[EntryFields.uri]).toSet();
      final entries = listing.files.map((map) {
        final fields = Map.of(map)..remove('megaDetailsKnown');
        fields[EntryFields.origin] = EntryOrigins.mega;
        // entries are kept by ID in the source, so each one needs its own
        fields[EntryFields.id] = localMediaDb.nextId;
        return AvesEntry.fromMap(fields);
      }).toSet();
      clearEntries();
      // entries with details from a previous visit are shown right away
      final known = entries.where((entry) => (entry.width > 0 && entry.height > 0) || knownUris.contains(entry.uri)).toSet();
      addEntries(known);
      updateDerivedFilters(known);
      // other entries are added once sized, as the viewer needs dimensions
      await _fetchDetails(entries.difference(known));
      if (!_disposed) state = SourceState.ready;
    } catch (error) {
      debugPrint('$runtimeType failed to load folder=$folderHandle with error=$error');
      if (!_disposed) state = SourceState.ready;
      rethrow;
    }
  }

  // completes entries with dimensions, orientation and dates, then adds them to the source by batches
  Future<void> _fetchDetails(Set<AvesEntry> entries) async {
    final todo = entries.toList();
    final total = todo.length;
    final pending = <AvesEntry>{};
    var done = 0;
    var lastFlush = DateTime.now();
    setProgress(done: done, total: total);

    void flush() {
      if (pending.isEmpty || _disposed) return;
      final batch = Set.of(pending);
      pending.clear();
      addEntries(batch);
      updateDerivedFilters(batch);
      lastFlush = DateTime.now();
    }

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
        if (_disposed) return;
        pending.add(entry);
        done++;
        setProgress(done: done, total: total);
        if (pending.length >= _batchSize || DateTime.now().difference(lastFlush) > _batchDelay) flush();
      }
    }

    await Future.wait(List.generate(_detailConcurrency, (_) => worker()));
    flush();
  }

  @override
  Future<void> checkForChanges() async {}

  @override
  Future<Set<String>> refreshUris(Set<String> changedUris, {AnalysisController? analysisController}) async => changedUris;
}
