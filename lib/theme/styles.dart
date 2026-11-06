import 'package:aves/l10ngen/app_localizations_en.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/settings/language/locales.dart';
import 'package:flutter/widgets.dart';

class AStyles {
  static TextStyle _baseTitleStyle(KnownLocale? locale) {
    // Best gallery: bold titles, without small caps
    return const TextStyle(
      fontWeight: .w700,
      letterSpacing: 0,
    );
  }

  static final String _originalAppName = AppLocalizationsEn().appName;

  static TextStyle appNameStyle(BuildContext context, String appName) {
    final locale = appName != _originalAppName ? context.knownLocale : KnownLocale.english;
    return _baseTitleStyle(locale);
  }

  static TextStyle pageTitleTextStyle(KnownLocale locale) {
    return _baseTitleStyle(locale).copyWith(
      fontSize: 21,
    );
  }

  static TextStyle sectionTitleStyle(KnownLocale? locale) {
    return _baseTitleStyle(locale).copyWith(
      fontSize: 20,
    );
  }

  static const embossShadows = [
    Shadow(
      color: Color(0xFF000000),
      offset: Offset(0.5, 1.0),
    ),
  ];
}
