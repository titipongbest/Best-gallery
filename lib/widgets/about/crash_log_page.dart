import 'dart:convert';

import 'package:aves/locale/intl.dart';
import 'package:aves/ref/mime_types.dart';
import 'package:aves/services/common/services.dart';
import 'package:aves/services/crash_log_service.dart';
import 'package:aves/theme/icons.dart';
import 'package:aves/widgets/common/action_mixins/feedback.dart';
import 'package:aves/widgets/common/basic/scaffold.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

// Best gallery: why the app closed by itself, and recent app errors
class CrashLogPage extends StatefulWidget {
  static const routeName = '/about/crash_log';

  const new({super.key});

  @override
  State<CrashLogPage> createState() => _CrashLogPageState();
}

class _CrashLogPageState extends State<CrashLogPage> with FeedbackMixin {
  late Future<String> _loader;

  @override
  void initState() {
    super.initState();
    _loader = crashLogService.read();
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showFeedback(context, FeedbackType.info, context.l10n.genericSuccessFeedback);
  }

  Future<void> _save(String text) async {
    final date = DateFormat('yyyyMMdd_HHmmss', IntlUtils.rootLocaleName).format(DateTime.now());
    final success = await storageService.createFile(
      basename: 'best-gallery-crash-log-$date',
      mimeType: MimeTypes.plainText,
      bytes: utf8.encode(text),
    );
    if (success != null && mounted) {
      showFeedback(context, success ? FeedbackType.info : FeedbackType.warn, success ? context.l10n.genericSuccessFeedback : context.l10n.genericFailureFeedback);
    }
  }

  Future<void> _clear() async {
    await crashLogService.clear();
    if (mounted) setState(() => _loader = crashLogService.read());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder<String>(
      future: _loader,
      builder: (context, snapshot) {
        final text = snapshot.data;
        return AvesScaffold(
          appBar: AppBar(
            title: Text(l10n.crashLogPageTitle),
            actions: [
              IconButton(
                icon: const Icon(AIcons.copy),
                tooltip: l10n.crashLogCopyTooltip,
                onPressed: text == null ? null : () => _copy(text),
              ),
              IconButton(
                icon: const Icon(AIcons.save),
                tooltip: l10n.saveTooltip,
                onPressed: text == null ? null : () => _save(text),
              ),
              IconButton(
                icon: const Icon(AIcons.clear),
                tooltip: l10n.crashLogClearTooltip,
                onPressed: text == null ? null : _clear,
              ),
            ],
          ),
          body: SafeArea(
            child: text == null
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: .start,
                      children: [
                        Text(l10n.crashLogDescription, style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: 16),
                        SelectableText(
                          text,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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
