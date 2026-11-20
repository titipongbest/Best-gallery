import 'dart:async';
import 'dart:io';

import 'package:aves/services/common/services.dart';
import 'package:aves/theme/durations.dart';
import 'package:aves/theme/icons.dart';
import 'package:aves/utils/android_file_utils.dart';
import 'package:aves/view/view.dart';
import 'package:aves/widgets/common/bars/app_bar.dart';
import 'package:aves/widgets/common/bars/crumb_line.dart';
import 'package:aves/widgets/common/basic/font_size_icon_theme.dart';
import 'package:aves/widgets/common/basic/insets.dart';
import 'package:aves/widgets/common/basic/scaffold.dart';
import 'package:aves/widgets/common/basic/text/fading_line.dart';
import 'package:aves/widgets/common/behaviour/pop/scope.dart';
import 'package:aves/widgets/common/behaviour/pop/tv_navigation.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/common/identity/aves_icons.dart';
import 'package:aves/widgets/common/identity/empty.dart';
import 'package:aves/widgets/dialogs/aves_dialog.dart';
import 'package:aves/widgets/dialogs/select_storage_dialog.dart';
import 'package:aves/widgets/explorer/crumb_line.dart';
import 'package:aves_model/aves_model.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

Future<String?> pickFolder({
  required BuildContext context,
}) async {
  return await Navigator.maybeOf(context)?.push<String>(
    MaterialPageRoute(
      settings: const RouteSettings(name: _FolderPickPage.routeName),
      builder: (context) => const _FolderPickPage(),
    ),
  );
}

class _FolderPickPage extends StatefulWidget {
  static const routeName = '/folder_pick';

  const new();

  @override
  State<_FolderPickPage> createState() => _FolderPickPageState();
}

class _FolderPickPageState extends State<_FolderPickPage> {
  final ValueNotifier<VolumeRelativeDirectory?> _directory = ValueNotifier(null);
  final ValueNotifier<List<Directory>> _contents = ValueNotifier([]);
  StreamSubscription<FileSystemEntity>? _listSubscription;

  Set<StorageVolume> get _volumes => androidFileUtils.storageVolumes;

  @override
  void initState() {
    super.initState();
    final primaryVolume = _volumes.firstWhereOrNull((v) => v.isPrimary) ?? _volumes.firstOrNull;
    if (primaryVolume != null) {
      _goToPath(primaryVolume.path);
    }
    _contents.addListener(_scrollToTop);
  }

  @override
  void dispose() {
    unawaited(_listSubscription?.cancel());
    _contents.removeListener(_scrollToTop);
    _directory.dispose();
    _contents.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (!mounted) return;
    final scrollController = PrimaryScrollController.of(context);
    if (scrollController.hasClients) {
      scrollController.positions.where((v) => v.hasContentDimensions).forEach((v) => v.jumpTo(0));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VolumeRelativeDirectory?>(
      valueListenable: _directory,
      builder: (context, directory, child) {
        final atRoot = directory?.relativeDir.isEmpty ?? true;
        final path = directory?.dirPath;
        final canPickCurrent = path != null && !atRoot && _canPickAsDestination(path);

        return AvesScaffold(
          body: AvesPopScope(
            handlers: [
              APopHandler(
                canPop: (context) => atRoot,
                onPopBlocked: (context) {
                  if (path != null) {
                    _goToPath(pContext.dirname(path));
                  }
                },
              ),
              tvNavigationPopHandler,
            ],
            child: GestureAreaProtectorStack(
              child: SafeArea(
                bottom: false,
                child: ValueListenableBuilder<List<Directory>>(
                  valueListenable: _contents,
                  builder: (context, contents, child) {
                    final durations = context.watch<DurationsData>();
                    return CustomScrollView(
                      primary: true,
                      physics: contents.isEmpty ? const NeverScrollableScrollPhysics() : null,
                      slivers: [
                        _buildAppBar(context, atRoot: atRoot, canPickCurrent: canPickCurrent),
                        contents.isEmpty
                            ? SliverFillRemaining(
                                hasScrollBody: false,
                                child: EmptyContent(
                                  icon: AIcons.folder,
                                  text: context.l10n.folderPickPageEmpty,
                                  alignment: .center,
                                ),
                              )
                            : AnimationLimiter(
                                key: ValueKey(contents),
                                child: SliverList.builder(
                                  itemBuilder: (context, index) {
                                    final entity = contents[index];
                                    return AnimationConfiguration.staggeredList(
                                      position: index,
                                      duration: durations.staggeredAnimation,
                                      delay: durations.staggeredAnimationDelay * timeDilation,
                                      child: SlideAnimation(
                                        verticalOffset: 50.0,
                                        child: FadeInAnimation(
                                          child: _FolderLine(
                                            entity: entity,
                                            canPick: _canPickAsDestination(entity.path),
                                            onOpen: () => _goToPath(entity.path),
                                            onPick: () => _pickFolder(entity.path),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  itemCount: contents.length,
                                ),
                              ),
                        if (canPickCurrent) const SliverToBoxAdapter(child: SizedBox(height: 88)),
                        const SafeBottomPaddingSliver(),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          floatingActionButton: canPickCurrent
              ? FloatingActionButton.extended(
                  onPressed: () => _pickFolder(path),
                  icon: const Icon(AIcons.apply),
                  label: Text(context.l10n.folderPickPageMoveHereButton),
                )
              : null,
          resizeToAvoidBottomInset: false,
        );
      },
    );
  }

  Widget _buildAppBar(
    BuildContext context, {
    required bool atRoot,
    required bool canPickCurrent,
  }) {
    final textScaler = MediaQuery.textScalerOf(context);
    final contentHeight = textScaler.scale(kToolbarHeight) + CrumbLine.getPreferredHeight(textScaler);
    return AvesAppBar(
      contentHeight: contentHeight,
      pinned: true,
      floating: false,
      leading: CloseButton(
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: FadingLine(context.l10n.folderPickPageTitleMove),
      actions: (context, maxWidth) => [
        if (canPickCurrent)
          IconButton(
            icon: const Icon(AIcons.add),
            onPressed: _createFolder,
            tooltip: context.l10n.newFolderDialogTitle,
          ),
        if (_volumes.length > 1) _buildVolumeSelector(context),
      ].map((v) => FontSizeIconTheme(child: v)).toList(),
      bottom: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            padding: CrumbLine.padding,
            width: constraints.maxWidth,
            height: CrumbLine.getPreferredHeight(MediaQuery.textScalerOf(context)),
            child: ValueListenableBuilder<VolumeRelativeDirectory?>(
              valueListenable: _directory,
              builder: (context, contentsDirectory, child) {
                return ExplorerCrumbLine(
                  directory: contentsDirectory,
                  onTap: _goToDir,
                  lastCrumbBuilder: null,
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildVolumeSelector(BuildContext context) {
    if (_volumes.length == 2) {
      return ValueListenableBuilder<VolumeRelativeDirectory?>(
        valueListenable: _directory,
        builder: (context, directory, child) {
          final currentVolume = directory?.volumePath;
          final otherVolume = _volumes.firstWhere((volume) => volume.path != currentVolume);
          final icon = otherVolume.isRemovable ? AIcons.storageCard : AIcons.storageMain;
          return IconButton(
            icon: Icon(icon),
            onPressed: () => _goToDir(VolumeRelativeDirectory.volume(otherVolume)),
            tooltip: otherVolume.getDescription(context),
          );
        },
      );
    } else {
      return IconButton(
        icon: const Icon(AIcons.storageCard),
        onPressed: () async {
          final volumePath = _directory.value?.volumePath;
          final initialVolume = _volumes.firstWhereOrNull((v) => v.path == volumePath);
          final volume = await showAvesDialog<StorageVolume?>(
            context: context,
            builder: (context) => SelectStorageDialog(initialVolume: initialVolume),
            routeSettings: const RouteSettings(name: SelectStorageDialog.routeName),
          );
          if (volume != null) {
            _goToDir(VolumeRelativeDirectory.volume(volume));
          }
        },
        tooltip: context.l10n.explorerActionSelectStorageVolume,
      );
    }
  }

  void _updateContents() {
    unawaited(_listSubscription?.cancel());
    final directory = _directory.value;
    final dirPath = directory?.dirPath;
    if (dirPath == null) return;

    final contents = <Directory>[];
    _listSubscription = Directory(dirPath).list().listen(
      (event) {
        final entity = event.absolute;
        if (entity is Directory) {
          final name = pContext.basename(entity.path);
          if (name.startsWith('.')) return;
          if (_isRestrictedBrowseDir(entity.path)) return;
          contents.add(entity);
        }
      },
      onError: (error) => debugPrint('failed to list directory=$dirPath with error=$error'),
      onDone: () {
        if (!mounted || _directory.value != directory) return;
        _contents.value = contents
          ..sort((a, b) {
            final nameA = pContext.basename(a.path);
            final nameB = pContext.basename(b.path);
            return compareAsciiUpperCaseNatural(nameA, nameB);
          });
      },
    );
  }

  bool _isRestrictedBrowseDir(String dirPath) {
    final relDir = androidFileUtils.relativeDirectoryFromPath(dirPath);
    if (relDir == null) return false;
    final trimmed = androidFileUtils.removeTrailingSeparator(relDir.relativeDir) ?? '';
    if (trimmed.isEmpty) return false;
    final segments = pContext.split(trimmed);
    if (segments.length >= 2 && segments[0].toLowerCase() == 'android') {
      final second = segments[1].toLowerCase();
      if (second == 'data' || second == 'obb') return true;
    }
    return false;
  }

  bool _canPickAsDestination(String dirPath) {
    final relDir = androidFileUtils.relativeDirectoryFromPath(dirPath);
    if (relDir == null || relDir.relativeDir.isEmpty) return false;
    final trimmed = androidFileUtils.removeTrailingSeparator(relDir.relativeDir) ?? '';
    if (trimmed.isEmpty) return false;
    final segments = pContext.split(trimmed);
    if (segments.first.toLowerCase() == 'android') {
      if (segments.length == 1) return false;
      final second = segments[1].toLowerCase();
      if (second == 'data' || second == 'obb') return false;
    }
    return true;
  }

  void _goToDir(VolumeRelativeDirectory? dir) {
    if (dir != null) {
      _directory.value = dir;
      _updateContents();
    }
  }

  void _goToPath(String path) => _goToDir(androidFileUtils.relativeDirectoryFromPath(path));

  Future<void> _createFolder() async {
    final parentPath = _directory.value?.dirPath;
    if (parentPath == null) return;

    final folderPath = await showAvesDialog<String>(
      context: context,
      builder: (context) => _CreateFolderDialog(parentPath: parentPath),
      routeSettings: const RouteSettings(name: _CreateFolderDialog.routeName),
    );
    if (folderPath == null || !mounted) return;

    await Future.pause(ADurations.dialogTransitionLoose * timeDilation);
    if (!mounted) return;
    _pickFolder(folderPath);
  }

  void _pickFolder(String dirPath) {
    final normalized = androidFileUtils.removeTrailingSeparator(dirPath) ?? dirPath;
    Navigator.of(context).pop<String>(normalized);
  }
}

class const _FolderLine({
  required final Directory entity,
  required final bool canPick,
  required final VoidCallback onOpen,
  required final VoidCallback onPick,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final name = pContext.basename(entity.path);
    final leadingIcon = IconUtils.getAlbumIcon(context: context, albumPath: entity.path) ?? const Icon(AIcons.folder);
    return ListTile(
      leading: SizedBox(
        width: 40,
        height: 40,
        child: Center(child: leadingIcon),
      ),
      title: Text('${Unicode.FSI}$name${Unicode.PDI}'),
      trailing: canPick
          ? IconButton(
              icon: const Icon(AIcons.move),
              onPressed: onPick,
              tooltip: context.l10n.collectionActionMoveToFolder,
            )
          : null,
      onTap: onOpen,
    );
  }
}

class const _CreateFolderDialog({
  required final String parentPath,
}) extends StatefulWidget {
  static const routeName = '/dialog/create_folder';

  @override
  State<_CreateFolderDialog> createState() => _CreateFolderDialogState();
}

class _CreateFolderDialogState extends State<_CreateFolderDialog> {
  final TextEditingController _nameController = TextEditingController();
  final ValueNotifier<bool> _directoryExistsNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _isValidNotifier = ValueNotifier(false);

  @override
  void dispose() {
    _nameController.dispose();
    _directoryExistsNotifier.dispose();
    _isValidNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const contentHorizontalPadding = EdgeInsets.symmetric(horizontal: AvesDialog.defaultHorizontalContentPadding);

    return AvesDialog(
      title: l10n.newFolderDialogTitle,
      scrollableContent: [
        Padding(
          padding: contentHorizontalPadding + const EdgeInsets.only(top: 8, bottom: 8),
          child: ValueListenableBuilder<bool>(
            valueListenable: _directoryExistsNotifier,
            builder: (context, directoryExists, child) {
              return TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.newFolderDialogNameLabel,
                  helperText: directoryExists ? l10n.newAlbumDialogNameLabelAlreadyExistsHelper : '',
                ),
                autofocus: true,
                onChanged: (_) => _validate(),
                onSubmitted: (_) => _submit(context),
              );
            },
          ),
        ),
      ],
      actions: [
        const CancelButton(),
        ValueListenableBuilder<bool>(
          valueListenable: _isValidNotifier,
          builder: (context, isValid, child) {
            return TextButton(
              onPressed: isValid ? () => _submit(context) : null,
              child: Text(l10n.createAlbumButtonLabel),
            );
          },
        ),
      ],
    );
  }

  Future<String?> _buildFolderPath() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name == '.' || name == '..' || name.contains('/') || name.contains('\\')) {
      return null;
    }

    final parentDir = Directory(widget.parentPath);
    String? resolvedSegment;
    if (await parentDir.exists()) {
      final lowerName = name.toLowerCase();
      resolvedSegment = parentDir.listSync().map((v) => pContext.basename(v.path)).firstWhereOrNull((v) => v.toLowerCase() == lowerName);
    }
    return pContext.join(widget.parentPath, resolvedSegment ?? name);
  }

  Future<void> _validate() async {
    final path = await _buildFolderPath();
    final isValid = path != null;
    _isValidNotifier.value = isValid;
    _directoryExistsNotifier.value = isValid && await Directory(path).exists();
  }

  Future<void> _submit(BuildContext context) async {
    final path = await _buildFolderPath();
    if (path == null || !context.mounted) return;

    Navigator.maybeOf(context)?.pop<String>(path);
  }
}
