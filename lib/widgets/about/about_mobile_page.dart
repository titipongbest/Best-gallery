import 'package:aves/theme/icons.dart';
import 'package:aves/widgets/about/app_ref.dart';
import 'package:aves/widgets/about/bug_report.dart';
import 'package:aves/widgets/about/crash_log_page.dart';
import 'package:aves/widgets/about/credits.dart';
import 'package:aves/widgets/about/data_usage.dart';
import 'package:aves/widgets/about/licenses.dart';
import 'package:aves/widgets/about/translators.dart';
import 'package:aves/widgets/common/basic/insets.dart';
import 'package:aves/widgets/common/basic/scaffold.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:material_ui/material_ui.dart';

class AboutMobilePage extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return AvesScaffold(
      appBar: AppBar(
        title: Text(context.l10n.aboutPageTitle),
      ),
      body: GestureAreaProtectorStack(
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.only(top: 16),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      const AppReference(),
                      const Divider(),
                      const BugReport(),
                      ListTile(
                        leading: const Icon(AIcons.error),
                        title: Text(context.l10n.crashLogPageTitle),
                        subtitle: Text(context.l10n.crashLogTileSubtitle),
                        onTap: () => Navigator.maybeOf(context)?.push(
                          MaterialPageRoute(
                            settings: const RouteSettings(name: CrashLogPage.routeName),
                            builder: (context) => const CrashLogPage(),
                          ),
                        ),
                      ),
                      const Divider(),
                      const AboutDataUsage(),
                      const Divider(),
                      const AboutCredits(),
                      const Divider(),
                      const AboutTranslators(),
                      const Divider(),
                    ],
                  ),
                ),
              ),
              const Licenses(),
              const SafeBottomPaddingSliver(),
            ],
          ),
        ),
      ),
    );
  }
}
