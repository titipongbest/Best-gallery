import 'dart:math';

import 'package:aves/model/settings/settings.dart';
import 'package:aves/theme/durations.dart';
import 'package:aves/widgets/aves_app.dart';
import 'package:aves/widgets/common/basic/font_size_icon_theme.dart';
import 'package:aves/widgets/common/basic/gestures/ink_well.dart';
import 'package:aves/widgets/common/basic/insets.dart';
import 'package:aves/widgets/common/bars/floating_bar.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

class const AvesAppBar({
  super.key,
  required final double contentHeight,
  required final bool pinned,
  // when false, the bar scrolls away with the content and only shows again at the top
  final bool floating = true,
  required final Widget? leading,
  required final Widget title,
  required final List<Widget> Function(BuildContext context, double maxWidth) actions,
  // shown right below the title row, and included in `contentHeight`
  // when the bar is pinned (e.g. in selection mode), it scrolls away under the title row
  // instead of popping back in view over the content
  final Widget? header,
  final double headerHeight = 0,
  final Widget? bottom,
  final Object? transitionKey,
}) extends StatelessWidget {
  static const leadingHeroTag = 'appbar-leading';
  static const titleHeroTag = 'appbar-title';
  static const double _titleMinWidth = 96;
  static const margin = EdgeInsets.all(8);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textScaler = MediaQuery.textScalerOf(context);
    final useTvLayout = settings.useTvLayout;

    Widget? _leading = leading;
    if (_leading != null) {
      _leading = FontSizeIconTheme(
        child: _leading,
      );
    }

    Widget _title = FontSizeIconTheme(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            key: ValueKey(transitionKey),
            children: [
              Expanded(child: title),
              ...(actions(context, max(0, constraints.maxWidth - _titleMinWidth))),
            ],
          );
        },
      ),
    );

    final animate = context.select<Settings, bool>((v) => v.animate);
    if (animate) {
      _title = Hero(
        tag: titleHeroTag,
        flightShuttleBuilder: _flightShuttleBuilder,
        transitionOnUserGestures: true,
        child: AnimatedSwitcher(
          duration: context.read<DurationsData>().iconAnimation,
          child: _title,
        ),
      );

      if (_leading != null) {
        _leading = Hero(
          tag: leadingHeroTag,
          flightShuttleBuilder: _flightShuttleBuilder,
          transitionOnUserGestures: true,
          child: _leading,
        );
      }
    }

    final _header = header;
    final collapsibleHeight = pinned && _header != null ? headerHeight : 0.0;
    final maxHeight = MediaQuery.paddingOf(context).top + appBarHeightForContentHeight(contentHeight);
    return SliverPersistentHeader(
      floating: floating && !useTvLayout,
      pinned: pinned,
      delegate: _SliverAppBarDelegate(
        maxHeight: maxHeight,
        minHeight: maxHeight - collapsibleHeight,
        builder: (context, shrinkOffset) => DirectionalSafeArea(
          start: !useTvLayout,
          bottom: false,
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: AvesApp.themeSystemOverlayStyle(theme),
            child: AvesFloatingBar(
              margin: margin,
              builder: (context, backgroundColor, child) => Material(
                color: backgroundColor,
                child: AInkResponse(
                  // absorb taps while providing visual feedback
                  onTap: () {},
                  onLongPress: () {},
                  containedInkWell: true,
                  highlightShape: BoxShape.rectangle,
                  longPressTimeout: settings.longPressTimeout,
                  child: child,
                ),
              ),
              child: Theme(
                data: theme.copyWith(
                  colorScheme: colorScheme.copyWith(
                    onSurfaceVariant: colorScheme.onSurface,
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: textScaler.scale(kToolbarHeight),
                      child: Row(
                        children: [
                          _leading != null
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: _leading,
                                )
                              : const SizedBox(width: 16),
                          Expanded(
                            child: DefaultTextStyle(
                              style: theme.appBarTheme.titleTextStyle!,
                              child: _title,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_header != null)
                      ClipRect(
                        child: SizedBox(
                          height: collapsibleHeight > 0 ? (headerHeight - shrinkOffset).clamp(0.0, headerHeight) : headerHeight,
                          child: OverflowBox(
                            alignment: Alignment.bottomCenter,
                            minHeight: headerHeight,
                            maxHeight: headerHeight,
                            child: _header,
                          ),
                        ),
                      ),
                    ?bottom,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _flightShuttleBuilder(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection flightDirection,
    BuildContext fromHeroContext,
    BuildContext toHeroContext,
  ) {
    final pushing = flightDirection == HeroFlightDirection.push;
    Widget popBuilder(context, child) => Opacity(opacity: 1 - animation.value, child: child);
    Widget pushBuilder(context, child) => Opacity(opacity: animation.value, child: child);
    return Material(
      type: MaterialType.transparency,
      child: DefaultTextStyle(
        style: DefaultTextStyle.of(toHeroContext).style,
        child: Stack(
          children: [
            AnimatedBuilder(
              animation: animation,
              builder: pushing ? popBuilder : pushBuilder,
              child: fromHeroContext.widget,
            ),
            AnimatedBuilder(
              animation: animation,
              builder: pushing ? pushBuilder : popBuilder,
              child: toHeroContext.widget,
            ),
          ],
        ),
      ),
    );
  }

  static double appBarHeightForContentHeight(double contentHeight) => margin.vertical + contentHeight;
}

class const _SliverAppBarDelegate({
  required final double maxHeight,
  required final double minHeight,
  required final Widget Function(BuildContext context, double shrinkOffset) builder,
}) extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => builder(context, shrinkOffset);

  @override
  bool shouldRebuild(covariant _SliverAppBarDelegate oldDelegate) => true;
}
