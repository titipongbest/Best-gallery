import 'package:aves/model/mega_lock.dart';
import 'package:aves/widgets/app_lock/app_lock_page.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:material_ui/material_ui.dart';

// shows the lock page over the MEGA pages (folders, collection, viewer) while they are locked
class const MegaLockGate({
  super.key,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: megaLock.locked,
      builder: (context, locked, child) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ExcludeSemantics(
              excluding: locked,
              child: TickerMode(
                enabled: !locked,
                child: child!,
              ),
            ),
            if (locked)
              Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (context) => PopScope(
                      canPop: false,
                      onPopInvokedWithResult: (didPop, _) {
                        if (!didPop) megaLock.cancel();
                      },
                      child: AppLockPage(
                        title: context.l10n.megaPageTitle,
                        unlock: megaLock.unlock,
                        onSystemAuth: megaLock.unlockWithSystemAuth,
                        onCancel: megaLock.cancel,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        );
      },
      child: child,
    );
  }
}
