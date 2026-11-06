import 'package:aves/services/mega_service.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:material_ui/material_ui.dart';

// progress of a MEGA video download, shown over the video cover until it can play
class const MegaDownloadProgress({
  super.key,
  required final String uri,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, double>>(
      valueListenable: MegaDownloads.progress,
      builder: (context, downloads, child) {
        final progress = downloads[uri];
        if (progress == null) return const SizedBox();
        final percent = (progress * 100).floor();
        return IgnorePointer(
          child: Center(
            child: Container(
              width: 240,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .6),
                borderRadius: const BorderRadius.all(Radius.circular(16)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.megaDownloadingVideo(percent),
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                    child: LinearProgressIndicator(
                      value: progress > 0 ? progress : null,
                      minHeight: 6,
                      backgroundColor: Colors.white24,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
