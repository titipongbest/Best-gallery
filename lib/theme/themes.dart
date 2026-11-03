import 'package:aves/theme/colors.dart';
import 'package:aves/theme/styles.dart';
import 'package:aves/widgets/aves_app.dart';
import 'package:aves/widgets/settings/language/locales.dart';
import 'package:aves_utils/aves_utils.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class Themes {
  static String asButtonLabel(String s) => s.toUpperCase();

  static TextStyle searchFieldStyle(BuildContext context) => Theme.of(context).textTheme.bodyLarge!;

  static Color overlayBackgroundColor({
    required Brightness brightness,
    required bool blurred,
  }) {
    switch (brightness) {
      case .dark:
        return blurred ? Colors.black26 : Colors.black45;
      case .light:
        return blurred ? Colors.white54 : const Color(0xCCFFFFFF);
    }
  }

  static bool _isDarkTheme(ColorScheme colors) => colors.brightness == Brightness.dark && colors.surface != Colors.black;

  static Color firstLayerColor(BuildContext context) => _schemeFirstLayer(Theme.of(context).colorScheme);

  static Color _schemeFirstLayer(ColorScheme colors) => _isDarkTheme(colors) ? colors.surfaceContainer : colors.surface;

  static Color _schemeCardLayer(ColorScheme colors) => _isDarkTheme(colors) ? _schemeSecondLayer(colors) : colors.surfaceContainerLow;

  static Color secondLayerColor(BuildContext context) => _schemeSecondLayer(Theme.of(context).colorScheme);

  static Color _schemeSecondLayer(ColorScheme colors) => _isDarkTheme(colors) ? colors.surfaceContainerHigh : colors.surfaceContainer;

  static Color thirdLayerColor(BuildContext context) => _schemeThirdLayer(Theme.of(context).colorScheme);

  static Color _schemeThirdLayer(ColorScheme colors) => _isDarkTheme(colors) ? colors.surfaceContainerHighest : colors.surfaceContainerHigh;

  static Color _unselectedWidgetColor(ColorScheme colors) => colors.onSurface.withValues(alpha: .6);

  static Color backgroundTextColor(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Color.alphaBlend(colors.surfaceTint, colors.onSurface).withValues(alpha: .5);
  }

  static final _typography = Typography.material2021(platform: TargetPlatform.android);

  static ThemeData _baseTheme(ColorScheme colors, bool deviceInitialized) {
    return ThemeData(
      // COLOR
      brightness: colors.brightness,
      canvasColor: _schemeSecondLayer(colors),
      cardColor: _schemeCardLayer(colors),
      colorScheme: colors,
      dividerColor: colors.outlineVariant,
      shadowColor: const Color(0xff9a6410),
      scaffoldBackgroundColor: _schemeFirstLayer(colors),
      // TYPOGRAPHY & ICONOGRAPHY
      iconTheme: _iconTheme(colors),
      typography: _typography,
      // COMPONENT THEMES
      bottomNavigationBarTheme: _bottomNavigationBarTheme(colors),
      cardTheme: const CardThemeData(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
      ),
      checkboxTheme: _checkboxTheme(colors),
      chipTheme: const ChipThemeData(shape: StadiumBorder()),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(shape: const StadiumBorder())),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: const StadiumBorder())),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(shape: const StadiumBorder())),
      drawerTheme: _drawerTheme(colors),
      floatingActionButtonTheme: _floatingActionButtonTheme(colors),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: _schemeFirstLayer(colors),
        selectedIconTheme: IconThemeData(color: colors.primary),
        unselectedIconTheme: IconThemeData(color: _unselectedWidgetColor(colors)),
        selectedLabelTextStyle: TextStyle(color: colors.primary),
        unselectedLabelTextStyle: TextStyle(color: _unselectedWidgetColor(colors)),
      ),
      radioTheme: _radioTheme(colors),
      sliderTheme: _sliderTheme(colors),
      tabBarTheme: TabBarThemeData(indicatorColor: colors.primary),
      tooltipTheme: _tooltipTheme,
    );
  }

  static BottomNavigationBarThemeData _bottomNavigationBarTheme(ColorScheme colors) {
    final iconTheme = _iconTheme(colors);
    return BottomNavigationBarThemeData(
      elevation: 0,
      selectedIconTheme: iconTheme.copyWith(color: colors.primary),
      unselectedIconTheme: iconTheme.copyWith(color: _unselectedWidgetColor(colors)),
    );
  }

  static CheckboxThemeData _checkboxTheme(ColorScheme colors) => CheckboxThemeData(
    side: BorderSide(width: 2.0, color: _unselectedWidgetColor(colors)),
  );

  static DrawerThemeData _drawerTheme(ColorScheme colors) => DrawerThemeData(
    backgroundColor: _schemeSecondLayer(colors),
  );

  static IconThemeData _iconTheme(ColorScheme colors) => IconThemeData(
    // increased weight (from default 400 to 600)
    // applied to variable fonts from `material_symbols_icons`,
    // to match the fixed-weight icons from `flutter_material_design_icons`
    weight: 600,
    grade: 0,
    opticalSize: 48,
    color: colors.onSurface,
  );

  static const _listTileTheme = ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(horizontal: 16),
  );

  static PopupMenuThemeData _popupMenuTheme(ColorScheme colors, TextTheme textTheme) {
    return PopupMenuThemeData(
      color: _schemeSecondLayer(colors),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        // adapted from M3 defaults
        final TextStyle style = textTheme.labelLarge!;
        if (states.contains(WidgetState.disabled)) {
          return style.apply(color: colors.onSurface.withValues(alpha: .38));
        }
        return style.apply(color: colors.onSurface);
      }),
      iconColor: colors.onSurface,
    );
  }

  static FloatingActionButtonThemeData _floatingActionButtonTheme(ColorScheme colors) {
    return FloatingActionButtonThemeData(
      foregroundColor: colors.onPrimary,
      backgroundColor: colors.primary,
      elevation: 8,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
    );
  }

  // adapted from M3 defaults
  static RadioThemeData _radioTheme(ColorScheme colors) => RadioThemeData(
    fillColor: WidgetStateProperty.resolveWith<Color>((states) {
      if (states.contains(WidgetState.selected)) {
        if (states.contains(WidgetState.disabled)) {
          return colors.onSurface.withValues(alpha: .38);
        }
        return colors.primary;
      }
      if (states.contains(WidgetState.disabled)) {
        return colors.onSurface.withValues(alpha: .38);
      }
      if (states.contains(WidgetState.pressed)) {
        return colors.onSurface;
      }
      if (states.contains(WidgetState.hovered)) {
        return colors.onSurface;
      }
      if (states.contains(WidgetState.focused)) {
        return colors.onSurface;
      }
      return _unselectedWidgetColor(colors);
    }),
  );

  static SliderThemeData _sliderTheme(ColorScheme colors) => SliderThemeData(
    inactiveTrackColor: colors.primary.withValues(alpha: .24),
  );

  static SnackBarThemeData _snackBarTheme(ColorScheme colors) => SnackBarThemeData(
    actionTextColor: colors.primary,
    behavior: SnackBarBehavior.floating,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
  );

  static const _tooltipTheme = TooltipThemeData(
    verticalOffset: 32,
  );

  // light

  // Best gallery "Golden Frame" palette: cream surfaces, deep brown text, amber gold accents
  static const _lightInk = Color(0xff2e2210);
  static const _lightThemeTypoBodyColor = Color(0xdd2e2210);
  static final _lightThemeTypo = _typography.black.apply(
    bodyColor: _lightThemeTypoBodyColor,
    displayColor: _lightThemeTypoBodyColor,
  );
  static const _lightTitleColor = Color(0xff2e2210);
  static const _lightLabelColor = _lightThemeTypoBodyColor;
  static const _lightActionIconColor = Color(0xffb8730a);
  static const _lightOnSurface = _lightInk;

  static ThemeData lightTheme(Color accentColor, bool deviceInitialized, KnownLocale locale) {
    final onAccent = ColorUtils.textColorOn(accentColor);
    final isDefault = accentColor == AvesColorsData.defaultAccent;
    final colors = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.light,
      primary: accentColor,
      onPrimary: onAccent,
      secondary: isDefault ? AvesColorsData.defaultSecondary : accentColor,
      onSecondary: isDefault ? const Color(0xff2e2210) : onAccent,
      tertiary: isDefault ? AvesColorsData.defaultTertiary : null,
      onTertiary: isDefault ? Colors.white : null,
      onSurface: _lightOnSurface,
      onSurfaceVariant: const Color(0xff6b5838),
      surface: const Color(0xfffdf9f1),
      surfaceContainerLowest: const Color(0xffffffff),
      surfaceContainerLow: const Color(0xfffffdf8),
      surfaceContainer: const Color(0xfff8f0e0),
      surfaceContainerHigh: const Color(0xfff3e8d2),
      surfaceContainerHighest: const Color(0xffeddfc2),
      outline: const Color(0xffa8916a),
      outlineVariant: const Color(0xffead9b5),
    );
    final textTheme = _lightThemeTypo;
    return _baseTheme(colors, deviceInitialized).copyWith(
      // TYPOGRAPHY & ICONOGRAPHY
      textTheme: textTheme,
      // COMPONENT THEMES
      appBarTheme: AppBarTheme(
        backgroundColor: _schemeFirstLayer(colors),
        // `foregroundColor` is used by icons
        foregroundColor: _lightActionIconColor,
        // `titleTextStyle.color` is used by text
        titleTextStyle: AStyles.pageTitleTextStyle(locale).copyWith(color: _lightTitleColor),
        // `systemOverlayStyle` is assumed by the app to never be null
        systemOverlayStyle: deviceInitialized ? AvesApp.systemUIStyleForBrightness(colors.brightness, _schemeFirstLayer(colors)) : const SystemUiOverlayStyle(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _schemeSecondLayer(colors),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
        titleTextStyle: AStyles.pageTitleTextStyle(locale).copyWith(color: _lightTitleColor),
      ),
      listTileTheme: _listTileTheme.copyWith(
        iconColor: _lightActionIconColor,
      ),
      popupMenuTheme: _popupMenuTheme(colors, textTheme),
      snackBarTheme: _snackBarTheme(colors),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _lightLabelColor,
        ),
      ),
    );
  }

  // dark

  static final _darkThemeTypo = _typography.white;
  static final _darkTitleColor = _darkThemeTypo.titleMedium!.color!;
  static final _darkBodyColor = _darkThemeTypo.bodyMedium!.color!;
  static final _darkLabelColor = _darkThemeTypo.labelMedium!.color!;
  static const _darkOnSurface = Colors.white;

  static ColorScheme _darkColorScheme(Color accentColor) {
    final onAccent = ColorUtils.textColorOn(accentColor);
    final isDefault = accentColor == AvesColorsData.defaultDarkAccent;
    final colors = ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.dark,
      primary: accentColor,
      onPrimary: onAccent,
      secondary: isDefault ? AvesColorsData.defaultDarkSecondary : accentColor,
      onSecondary: isDefault ? const Color(0xff17130c) : onAccent,
      tertiary: isDefault ? AvesColorsData.defaultDarkTertiary : null,
      onTertiary: isDefault ? const Color(0xff17130c) : null,
      onSurface: _darkOnSurface,
      // deep warm brown surfaces
      surface: const Color(0xff17130c),
      surfaceContainerLowest: const Color(0xff120f09),
      surfaceContainerLow: const Color(0xff1d1810),
      surfaceContainer: const Color(0xff241e14),
      surfaceContainerHigh: const Color(0xff2d2619),
      surfaceContainerHighest: const Color(0xff372e1f),
      outlineVariant: const Color(0xff4a3e28),
    );
    return colors;
  }

  static ThemeData _baseDarkTheme(ColorScheme colors, bool deviceInitialized, KnownLocale locale) {
    final textTheme = _darkThemeTypo;
    return _baseTheme(colors, deviceInitialized).copyWith(
      // TYPOGRAPHY & ICONOGRAPHY
      textTheme: textTheme,
      // COMPONENT THEMES
      appBarTheme: AppBarTheme(
        backgroundColor: _schemeFirstLayer(colors),
        // `foregroundColor` is used by icons
        foregroundColor: _darkTitleColor,
        // `titleTextStyle.color` is used by text
        titleTextStyle: AStyles.pageTitleTextStyle(locale).copyWith(color: _darkTitleColor),
        // `systemOverlayStyle` is assumed by the app to never be null
        systemOverlayStyle: deviceInitialized ? AvesApp.systemUIStyleForBrightness(colors.brightness, _schemeFirstLayer(colors)) : const SystemUiOverlayStyle(),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _schemeSecondLayer(colors),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(28))),
        titleTextStyle: AStyles.pageTitleTextStyle(locale).copyWith(color: _darkTitleColor),
      ),
      listTileTheme: _listTileTheme,
      popupMenuTheme: _popupMenuTheme(colors, textTheme),
      snackBarTheme: _snackBarTheme(colors).copyWith(
        backgroundColor: _schemeSecondLayer(colors),
        contentTextStyle: TextStyle(
          color: _darkBodyColor,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _darkLabelColor,
        ),
      ),
    );
  }

  static ThemeData darkTheme(Color accentColor, bool deviceInitialized, KnownLocale locale) {
    final colors = _darkColorScheme(accentColor);
    return _baseDarkTheme(colors, deviceInitialized, locale);
  }

  // black

  static ThemeData blackTheme(Color accentColor, bool deviceInitialized, KnownLocale locale) {
    final colors = _darkColorScheme(accentColor).copyWith(
      surface: Colors.black,
    );
    return _baseDarkTheme(colors, deviceInitialized, locale);
  }
}
