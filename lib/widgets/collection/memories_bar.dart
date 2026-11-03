import 'package:aves/locale/aves_locale.dart';
import 'package:aves/model/entry/entry.dart';
import 'package:aves/model/filters/date.dart';
import 'package:aves/model/source/collection_lens.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:aves/widgets/common/thumbnail/image.dart';
import 'package:material_ui/material_ui.dart';

// Best gallery: photos taken on this day in previous years
class Memory {
  final int yearsAgo;
  final DateTime date;
  final List<AvesEntry> entries;

  const new({
    required this.yearsAgo,
    required this.date,
    required this.entries,
  });

  static const maxCount = 6;

  static List<Memory> compute(List<AvesEntry> entries, DateTime today) {
    final byYear = <int, List<AvesEntry>>{};
    for (final entry in entries) {
      final date = entry.bestDate;
      if (date == null || date.year >= today.year) continue;
      if (date.month != today.month || date.day != today.day) continue;
      (byYear[date.year] ??= []).add(entry);
    }
    final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));
    return years.take(maxCount).map((year) {
      final yearEntries = byYear[year]!;
      return Memory(
        yearsAgo: today.year - year,
        date: DateTime(year, today.month, today.day),
        entries: yearEntries,
      );
    }).toList();
  }
}

class const MemoriesBar({
  super.key,
  required final CollectionLens collection,
  required final List<Memory> memories,
}) extends StatelessWidget {
  static const _titleHeight = 32.0;
  static const _cardHeight = 136.0;
  static const _cardWidth = 200.0;
  static const _bottomPadding = 8.0;
  static const preferredHeight = _titleHeight + _cardHeight + _bottomPadding;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SizedBox(
      height: preferredHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: _titleHeight,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(start: 16),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l10n.memoriesTitle,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          SizedBox(
            height: _cardHeight,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: memories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) => _MemoryCard(
                memory: memories[index],
                width: _cardWidth,
                height: _cardHeight,
                onTap: () => collection.addFilters({
                  DateFilter(ACalendar.gregorian, DateLevel.ymd, memories[index].date),
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class const _MemoryCard({
  required final Memory memory,
  required final double width,
  required final double height,
  required final VoidCallback onTap,
}) extends StatelessWidget {
  static const _radius = BorderRadius.all(Radius.circular(22));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cover = memory.entries.first;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: _radius,
        boxShadow: [
          BoxShadow(
            color: const Color(0xff9a6410).withValues(alpha: .20),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ThumbnailImage(
                  entry: cover,
                  extent: width,
                  devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                  fit: BoxFit.cover,
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0x99000000)],
                      stops: [.45, 1],
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: 14,
                  end: 14,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.memoriesYearsAgo(memory.yearsAgo),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        l10n.itemCount(memory.entries.length),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
