import 'package:aves/model/app_lock.dart';
import 'package:aves/widgets/app_lock/app_lock_page.dart';
import 'package:material_ui/material_ui.dart';

// shows the lock page over the app content while the app is locked
class const AppLockGate({
  super.key,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: appLock.locked,
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
              // the lock page is above the app navigator, so it needs its own overlay for text input
              Overlay(
                initialEntries: [
                  OverlayEntry(builder: (context) => const AppLockPage()),
                ],
              ),
          ],
        );
      },
      child: child,
    );
  }
}
