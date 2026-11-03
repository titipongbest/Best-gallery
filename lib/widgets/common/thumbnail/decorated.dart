import 'package:aves/model/entry/entry.dart';
import 'package:aves/widgets/common/fx/borders.dart';
import 'package:aves/widgets/common/grid/overlay.dart';
import 'package:aves/widgets/common/grid/sections/mosaic/section_layout_builder.dart';
import 'package:aves/widgets/common/thumbnail/image.dart';
import 'package:aves/widgets/common/thumbnail/notifications.dart';
import 'package:aves/widgets/common/thumbnail/overlay.dart';
import 'package:material_ui/material_ui.dart';

class const DecoratedThumbnail({
  super.key,
  required final AvesEntry entry,
  required final double tileExtent,
  final ValueNotifier<bool>? cancellableNotifier,
  final bool isMosaic = false,
  final bool selectable = true,
  final bool highlightable = true,
  final Object? Function()? heroTagger,
  final HeroPlaceholderBuilder? heroPlaceholderBuilder,
  final TransitionBuilder? imageDecorator,
}) extends StatelessWidget {
  static Color borderColor(BuildContext context) => Theme.of(context).dividerColor;

  static double borderWidth(BuildContext context) => AvesBorder.straightBorderWidth(context);

  static const radius = BorderRadius.all(Radius.circular(12));

  @override
  Widget build(BuildContext context) {
    final double thumbnailHeight = tileExtent;
    final double thumbnailWidth;
    if (isMosaic) {
      thumbnailWidth =
          thumbnailHeight *
          entry.displayAspectRatio.clamp(
            MosaicSectionLayoutBuilder.minThumbnailAspectRatio,
            MosaicSectionLayoutBuilder.maxThumbnailAspectRatio,
          );
    } else {
      thumbnailWidth = tileExtent;
    }

    Widget child = ThumbnailImage(
      entry: entry,
      extent: tileExtent,
      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
      isMosaic: isMosaic,
      cancellableNotifier: cancellableNotifier,
      heroTag: heroTagger?.call(),
      heroPlaceholderBuilder: heroPlaceholderBuilder,
    );

    child = Stack(
      fit: StackFit.passthrough,
      children: [
        imageDecorator?.call(context, child) ?? child,
        ThumbnailEntryOverlay(entry: entry),
        if (selectable) ...[
          GridItemSelectionOverlay<AvesEntry>(
            item: entry,
            padding: const EdgeInsets.all(2),
          ),
          ThumbnailZoomOverlay(
            onZoom: () => OpenViewerNotification(entry).dispatch(context),
          ),
        ],
        if (highlightable) ThumbnailHighlightOverlay(entry: entry),
      ],
    );

    // Best gallery: soft rounded tiles
    return SizedBox(
      width: thumbnailWidth,
      height: thumbnailHeight,
      child: ClipRRect(
        borderRadius: radius,
        child: child,
      ),
    );
  }
}
