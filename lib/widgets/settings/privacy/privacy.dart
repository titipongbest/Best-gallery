import 'dart:async';

import 'package:aves/model/app_lock.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/model/vaults/vaults.dart';
import 'package:aves/services/common/services.dart';
import 'package:aves/theme/colors.dart';
import 'package:aves/theme/icons.dart';
import 'package:aves/widgets/collection/entry_set_action_delegate.dart';
import 'package:aves/widgets/common/action_mixins/permission_aware.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/dialogs/aves_confirmation_dialog.dart';
import 'package:aves/widgets/dialogs/aves_dialog.dart';
import 'package:aves/widgets/dialogs/filter_editors/pin_dialog.dart';
import 'package:aves/widgets/settings/common/tile_leading.dart';
import 'package:aves/widgets/settings/common/tiles/sub_page.dart';
import 'package:aves/widgets/settings/common/tiles/switch_list.dart';
import 'package:aves/widgets/settings/privacy/access_grants_page.dart';
import 'package:aves/widgets/settings/privacy/hidden_items_page.dart';
import 'package:aves/widgets/settings/privacy/permissions/permissions_tile.dart';
import 'package:aves/widgets/settings/settings_definition.dart';
import 'package:aves_model/aves_model.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class PrivacySection extends SettingsSection {
  @override
  String get key => 'privacy';

  @override
  Widget icon(BuildContext context) => SettingsTileLeading(
    icon: AIcons.privacy,
    color: context.select<AvesColorsData, Color>((v) => v.privacy),
  );

  @override
  String title(BuildContext context) => context.l10n.settingsPrivacySectionTitle;

  @override
  Future<List<SettingsTile>> tiles(BuildContext context) async {
    return [
      SettingsTilePrivacyAppLock(),
      SettingsTilePermissions(),
      SettingsTilePrivacyHiddenItems(),
      if (!settings.useTvLayout) SettingsTilePrivacyStorageAccess(),
      if (!settings.useTvLayout) SettingsTilePrivacyEnableBin(),
      SettingsTilePrivacySaveSearchHistory(),
      if (!settings.useTvLayout) SettingsTilePrivacyAutoExportSettings(),
    ];
  }
}

class SettingsTilePrivacyAutoExportSettings extends SettingsTile with PermissionAwareMixin {
  @override
  List<String> get settingKeys => [SettingKeys.autoExportPathKey];

  @override
  String title(BuildContext context) => context.l10n.settingsAutoExportSettings;

  @override
  Widget build(BuildContext context) => SettingsSwitchListTile(
    selector: (context, s) => s.autoExportPath != null,
    onChanged: (v) async {
      if (v) {
        if (!await checkSystemFilePickerEnabled(context)) return;

        final dirPath = await storagePermissionService.requestSafAnyDirectoryAccess();
        if (dirPath == null) return;

        settings.autoExportPath = dirPath;
      } else {
        settings.autoExportPath = null;
      }
    },
    title: title,
    subtitle: (_) => settings.autoExportPath,
  );
}

class SettingsTilePrivacySaveSearchHistory extends SettingsTile {
  @override
  List<String> get settingKeys => [SettingKeys.saveSearchHistoryKey];

  @override
  String title(BuildContext context) => context.l10n.settingsSaveSearchHistory;

  @override
  Widget build(BuildContext context) => SettingsSwitchListTile(
    selector: (context, s) => s.saveSearchHistory,
    onChanged: (v) {
      settings.saveSearchHistory = v;
      if (!v) {
        settings.searchHistory = [];
      }
    },
    title: title,
  );
}

class SettingsTilePrivacyEnableBin extends SettingsTile {
  @override
  List<String> get settingKeys => [SettingKeys.enableBinKey];

  @override
  String title(BuildContext context) => context.l10n.settingsEnableBin;

  @override
  Widget build(BuildContext context) => SettingsSwitchListTile(
    selector: (context, s) => s.enableBin,
    onChanged: (v) => setBinUsage(context, v),
    title: title,
    subtitle: (context) => context.l10n.settingsEnableBinSubtitle,
  );

  static Future<bool> setBinUsage(BuildContext context, bool enabled) async {
    final l10n = context.l10n;
    if (!enabled) {
      if (vaults.all.any((v) => v.useBin)) {
        await showWarningDialog(
          context: context,
          message: l10n.vaultBinUsageDialogMessage,
        );
        return false;
      }

      final source = context.read<CollectionSource>();
      final trashedEntries = source.trashedEntries;
      if (trashedEntries.isNotEmpty) {
        if (!await showConfirmationDialog(
          context: context,
          message: l10n.settingsDisablingBinWarningDialogMessage,
          ok: l10n.applyButtonLabel,
        )) {
          return false;
        }

        // delete forever trashed items
        await EntrySetActionDelegate().doDelete(
          context: context,
          entries: trashedEntries,
          enableBin: false,
        );

        // in case of failure or cancellation
        if (source.trashedEntries.isNotEmpty) return false;
      }

      settings.searchHistory = [];
    }

    settings.enableBin = enabled;
    return true;
  }
}

class SettingsTilePrivacyHiddenItems extends SettingsTile {
  @override
  List<String> get settingKeys => HiddenItemsPage.settingKeys;

  @override
  String title(BuildContext context) => context.l10n.settingsHiddenItemsTile;

  @override
  Widget build(BuildContext context) => SettingsSubPageTile(
    title: title,
    routeName: HiddenItemsPage.routeName,
    builder: (context) => const HiddenItemsPage(),
  );
}

class SettingsTilePrivacyStorageAccess extends SettingsTile {
  @override
  List<String> get settingKeys => []; // no editable settings

  @override
  String title(BuildContext context) => context.l10n.settingsStorageAccessTile;

  @override
  Widget build(BuildContext context) => SettingsSubPageTile(
    title: title,
    routeName: StorageAccessPage.routeName,
    builder: (context) => const StorageAccessPage(),
  );
}

// Best gallery: app lock with a PIN
class SettingsTilePrivacyAppLock extends SettingsTile {
  @override
  List<String> get settingKeys => [];

  @override
  String title(BuildContext context) => context.l10n.appLockSettingTitle;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: appLock.enabled,
    builder: (context, enabled, child) => SwitchListTile(
      value: enabled,
      onChanged: (v) => _toggle(context, v),
      title: Text(title(context)),
      subtitle: Text(context.l10n.appLockSettingSubtitle),
    ),
  );

  Future<void> _toggle(BuildContext context, bool enable) async {
    if (enable) {
      final pin = await showAvesDialog<String>(
        context: context,
        builder: (context) => const PinDialog(needConfirmation: true),
        routeSettings: const RouteSettings(name: PinDialog.routeName),
      );
      if (pin != null) {
        await appLock.setPin(pin);
      }
    } else {
      // ask for the current PIN before removing the lock
      final pin = await showAvesDialog<String>(
        context: context,
        builder: (context) => const PinDialog(needConfirmation: false),
        routeSettings: const RouteSettings(name: PinDialog.routeName),
      );
      if (pin == null) return;
      if (appLock.check(pin)) {
        await appLock.setPin(null);
      } else if (context.mounted) {
        await showWarningDialog(
          context: context,
          message: context.l10n.appLockWrongPin,
        );
      }
    }
  }
}
