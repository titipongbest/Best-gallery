import 'package:aves/model/filters/favourite.dart';
import 'package:aves/model/filters/filters.dart';
import 'package:aves/model/filters/mime.dart';
import 'package:aves/model/filters/recent.dart';
import 'package:aves/model/source/collection_lens.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:material_ui/material_ui.dart';

// Best gallery: quick filter pills on the unfiltered photos page
class const QuickFilterBar({
  super.key,
  required final CollectionLens collection,
}) extends StatelessWidget {
  static const preferredHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final filters = <CollectionFilter>[
      FavouriteFilter.instance,
      MimeFilter.video,
      RecentlyAddedFilter.instance,
    ];
    return SizedBox(
      height: preferredHeight,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        scrollDirection: Axis.horizontal,
        children: [
          _Pill(
            label: context.l10n.quickFilterAll,
            selected: true,
            onTap: null,
          ),
          ...filters.map(
            (filter) => _Pill(
              label: filter.getLabel(context),
              selected: false,
              onTap: () => collection.addFilters({filter}),
            ),
          ),
        ],
      ),
    );
  }
}

class const _Pill({
  required final String label,
  required final bool selected,
  required final VoidCallback? onTap,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const shape = StadiumBorder();
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Material(
        shape: selected ? shape : StadiumBorder(side: BorderSide(color: colors.outlineVariant)),
        color: selected ? colors.secondary : colors.surfaceContainerLowest,
        elevation: selected ? 3 : 1,
        shadowColor: const Color(0xff9a6410).withValues(alpha: .5),
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? colors.onSecondary : colors.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
