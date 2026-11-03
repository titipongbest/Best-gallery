import 'package:aves/model/filters/favourite.dart';
import 'package:aves/model/filters/filters.dart';
import 'package:aves/model/filters/mime.dart';
import 'package:aves/model/filters/recent.dart';
import 'package:aves/model/filters/trash.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/widgets/collection/collection_page.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

// Best gallery: shortcuts to favourites, videos, recently added and the bin, above the album grid
class const AlbumQuickAccessBar({
  super.key,
  required final CollectionSource source,
}) extends StatelessWidget {
  static const _tileHeight = 78.0;
  static const _verticalPadding = 8.0;
  static const preferredHeight = _tileHeight + _verticalPadding * 2;

  @override
  Widget build(BuildContext context) {
    final filters = <CollectionFilter>[
      FavouriteFilter.instance,
      MimeFilter.video,
      RecentlyAddedFilter.instance,
      if (settings.enableBin) TrashFilter.instance,
    ];
    return SizedBox(
      height: preferredHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: _verticalPadding),
        child: Row(
          children: filters
              .map(
                (filter) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _QuickTile(
                      filter: filter,
                      count: _count(filter),
                      height: _tileHeight,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  int _count(CollectionFilter filter) {
    if (filter is TrashFilter) return source.trashedEntries.length;
    return source.visibleEntries.where(filter.test).length;
  }
}

class const _QuickTile({
  required final CollectionFilter filter,
  required final int count,
  required final double height,
}) extends StatelessWidget {
  static const _radius = BorderRadius.all(Radius.circular(18));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final label = filter.getLabel(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: _radius,
        color: colors.surfaceContainerLow,
        border: Border.all(color: isDark ? colors.outlineVariant : Colors.white),
        boxShadow: [
          BoxShadow(
            color: const Color(0xff9a6410).withValues(alpha: isDark ? .30 : .14),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: _radius,
          onTap: () => Navigator.maybeOf(context)?.push(
            MaterialPageRoute(
              settings: const RouteSettings(name: CollectionPage.routeName),
              builder: (context) => CollectionPage(
                source: context.read<CollectionSource>(),
                filters: {filter},
              ),
            ),
          ),
          child: Tooltip(
            message: label,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconTheme.merge(
                  data: IconThemeData(color: colors.primary),
                  child: filter.iconBuilder(context, 20) ?? const SizedBox(height: 20),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
                ),
                Text(
                  '$count',
                  maxLines: 1,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: colors.onSurface),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
