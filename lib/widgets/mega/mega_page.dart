import 'dart:async';

import 'package:aves/model/mega_lock.dart';
import 'package:aves/model/source/collection_source.dart';
import 'package:aves/model/source/mega_source.dart';
import 'package:aves/services/mega_service.dart';
import 'package:aves/widgets/dialogs/aves_confirmation_dialog.dart';
import 'package:aves/utils/file_utils.dart';
import 'package:aves/model/settings/settings.dart';
import 'package:aves/theme/icons.dart';
import 'package:aves/widgets/collection/collection_page.dart';
import 'package:aves/widgets/common/basic/scaffold.dart';
import 'package:aves/widgets/common/extensions/build_context.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

// Entry point for the MEGA cloud drive: sign in, then browse folders.
class MegaPage extends StatefulWidget {
  static const routeName = '/mega';

  const new({super.key});

  @override
  State<MegaPage> createState() => _MegaPageState();
}

class _MegaPageState extends State<MegaPage> {
  late Future<String?> _accountLoader;

  @override
  void initState() {
    super.initState();
    _accountLoader = megaService.getAccountEmail();
    megaLock.onPageOpened();
    // leaving the lock page goes back to the page that opened MEGA
    megaLock.onCancel = () {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      final navigator = Navigator.maybeOf(context);
      // the MEGA page may already be leaving, e.g. after a back press while locked,
      // and popping until a route that is no longer in the stack would pop every page
      if (route == null || navigator == null || !route.isActive) return;
      navigator.popUntil((r) => r == route || r.isFirst);
      if (route.isCurrent && navigator.canPop()) navigator.pop();
    };
  }

  @override
  void dispose() {
    megaLock.onPageClosed();
    super.dispose();
  }

  void _reloadAccount() => setState(() => _accountLoader = megaService.getAccountEmail());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _accountLoader,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return AvesScaffold(
            appBar: AppBar(title: Text(context.l10n.megaPageTitle)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final email = snapshot.data;
        if (email == null) {
          return MegaLoginView(onLoggedIn: _reloadAccount);
        }
        return MegaFolderView(
          email: email,
          folderHandle: null,
          onLoggedOut: _reloadAccount,
        );
      },
    );
  }
}

String megaErrorMessage(BuildContext context, Object error) {
  final l10n = context.l10n;
  if (error is MegaException) {
    if (error.isWrongCredentials) return l10n.megaErrorWrongCredentials;
    if (error.isMfaRequired) return l10n.megaErrorMfaRequired;
    if (error.isQuotaExceeded) return l10n.megaErrorQuota;
    if (error.isSessionExpired) return l10n.megaErrorSessionExpired;
    return l10n.megaErrorGeneric(error.message ?? '${error.code}');
  }
  return l10n.megaErrorGeneric('$error');
}

class MegaLoginView extends StatefulWidget {
  final VoidCallback onLoggedIn;

  const new({super.key, required this.onLoggedIn});

  @override
  State<MegaLoginView> createState() => _MegaLoginViewState();
}

class _MegaLoginViewState extends State<MegaLoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _mfaController = TextEditingController();
  bool _showMfa = false, _busy = false, _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _mfaController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await megaService.login(
        email: email,
        password: password,
        mfaCode: _showMfa ? _mfaController.text.trim() : null,
      );
      if (!mounted) return;
      _passwordController.clear();
      widget.onLoggedIn();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        if (error is MegaException && error.isMfaRequired) _showMfa = true;
        _error = megaErrorMessage(context, error);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return AvesScaffold(
      appBar: AppBar(title: Text(l10n.megaPageTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Icon(AIcons.cloud, size: 64, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(l10n.megaLoginTitle, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(l10n.megaLoginDescription, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            TextField(
              controller: _emailController,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l10n.megaEmailLabel, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              enabled: !_busy,
              obscureText: _obscurePassword,
              autofillHints: const [AutofillHints.password],
              textInputAction: _showMfa ? TextInputAction.next : TextInputAction.done,
              onSubmitted: (_) => _showMfa ? null : _login(),
              decoration: InputDecoration(
                labelText: l10n.megaPasswordLabel,
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? AIcons.show : AIcons.hide),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            if (_showMfa) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _mfaController,
                enabled: !_busy,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
                decoration: InputDecoration(labelText: l10n.megaMfaLabel, border: const OutlineInputBorder()),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _login,
              child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l10n.megaLoginButton),
            ),
          ],
        ),
      ),
    );
  }
}

class MegaFolderView extends StatefulWidget {
  final String email;

  // cloud drive root when null
  final String? folderHandle;
  final String? folderName;
  final VoidCallback onLoggedOut;

  const new({
    super.key,
    required this.email,
    required this.folderHandle,
    this.folderName,
    required this.onLoggedOut,
  });

  @override
  State<MegaFolderView> createState() => _MegaFolderViewState();
}

class _MegaFolderViewState extends State<MegaFolderView> {
  late Future<MegaFolderListing> _loader;

  @override
  void initState() {
    super.initState();
    _loader = megaService.listFolder(handle: widget.folderHandle);
  }

  void _refresh() => setState(() => _loader = megaService.listFolder(handle: widget.folderHandle, refresh: true));

  Future<void> _logout() async {
    await megaService.logout();
    if (!mounted) return;
    // back to the MEGA root page, which shows the login form
    Navigator.maybeOf(context)?.popUntil((route) => route.settings.name == MegaPage.routeName || route.isFirst);
    widget.onLoggedOut();
  }

  void _openFolder(MegaFolderSummary folder) {
    Navigator.maybeOf(context)?.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: '${MegaPage.routeName}/folder'),
        builder: (context) => MegaFolderView(
          email: widget.email,
          folderHandle: folder.handle,
          folderName: folder.name,
          onLoggedOut: widget.onLoggedOut,
        ),
      ),
    );
  }

  Future<void> _openMedia(MegaFolderListing listing) => openMegaMedia(
    context,
    MegaSource(folderHandle: listing.handle, folderName: listing.name),
  );

  void _openSearch() {
    Navigator.maybeOf(context)?.push(
      MaterialPageRoute(
        settings: const RouteSettings(name: MegaSearchPage.routeName),
        builder: (context) => MegaSearchPage(
          email: widget.email,
          onLoggedOut: widget.onLoggedOut,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AvesScaffold(
      appBar: AppBar(
        title: Text(widget.folderName ?? l10n.megaPageTitle),
        actions: [
          IconButton(
            icon: const Icon(AIcons.search),
            tooltip: l10n.megaSearchTooltip,
            onPressed: _openSearch,
          ),
          IconButton(
            icon: const Icon(AIcons.refresh),
            tooltip: l10n.megaRefreshTooltip,
            onPressed: _refresh,
          ),
          if (widget.folderHandle == null)
            IconButton(
              icon: const Icon(AIcons.logout),
              tooltip: l10n.megaLogoutTooltip,
              onPressed: _logout,
            ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<MegaFolderListing>(
          future: _loader,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final error = snapshot.error;
            if (error != null) {
              final isExpired = error is MegaException && error.isSessionExpired;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(AIcons.error, size: 48),
                      const SizedBox(height: 16),
                      Text(megaErrorMessage(context, error), textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: isExpired ? _logout : _refresh,
                        child: Text(isExpired ? l10n.megaLoginButton : l10n.megaRefreshTooltip),
                      ),
                    ],
                  ),
                ),
              );
            }
            final listing = snapshot.data!;
            final mediaCount = listing.files.length;
            final children = <Widget>[
              if (widget.folderHandle == null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(l10n.megaSignedInAs(widget.email), style: Theme.of(context).textTheme.bodySmall),
                ),
              if (widget.folderHandle == null) const MegaCacheTile(),
              if (mediaCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: FilledButton.tonalIcon(
                    icon: const Icon(AIcons.image),
                    label: Text(l10n.megaFolderMediaTile(mediaCount)),
                    onPressed: () => _openMedia(listing),
                  ),
                ),
              ...listing.folders.map(
                (folder) => ListTile(
                  leading: const Icon(AIcons.folder),
                  title: Text(folder.name),
                  subtitle: Text(l10n.megaFolderSubtitle(folder.folderCount, folder.mediaCount)),
                  onTap: () => _openFolder(folder),
                ),
              ),
            ];
            if (mediaCount == 0 && listing.folders.isEmpty) {
              children.add(
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(l10n.megaFolderEmpty, textAlign: TextAlign.center),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: () async {
                _refresh();
                await _loader.then((_) {}, onError: (_) {});
              },
              child: ListView(children: children),
            );
          },
        ),
      ),
    );
  }
}

// size of the downloaded photos, videos and thumbnails, with a button to clear them
class MegaCacheTile extends StatefulWidget {
  const new({super.key});

  @override
  State<MegaCacheTile> createState() => _MegaCacheTileState();
}

class _MegaCacheTileState extends State<MegaCacheTile> {
  late Future<int> _sizeLoader;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _sizeLoader = megaService.getCacheSize();
  }

  Future<void> _clear() async {
    final l10n = context.l10n;
    final confirmed = await showConfirmationDialog(
      context: context,
      message: l10n.megaClearCacheConfirmation,
      ok: l10n.megaClearCacheButton,
    );
    if (!confirmed || !mounted) return;
    setState(() => _clearing = true);
    await megaService.clearCache();
    if (!mounted) return;
    setState(() {
      _clearing = false;
      _sizeLoader = megaService.getCacheSize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder<int>(
      future: _sizeLoader,
      builder: (context, snapshot) {
        final size = snapshot.data;
        final sizeText = size == null ? '…' : formatFileSize(settings.avesLocale, size, round: 1);
        return ListTile(
          leading: const Icon(AIcons.storageMain),
          title: Text(l10n.megaCacheTitle),
          subtitle: Text(l10n.megaCacheSubtitle(sizeText)),
          trailing: _clearing
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : TextButton(
                  onPressed: size == null || size == 0 ? null : _clear,
                  child: Text(l10n.megaClearCacheButton),
                ),
        );
      },
    );
  }
}

// opens the media of a MEGA source in a collection page, and disposes the source when leaving
Future<void> openMegaMedia(BuildContext context, MegaSource source) async {
  unawaited(
    source.init(scope: CollectionSource.fullScope).catchError((error) {
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(megaErrorMessage(context, error))));
      }
    }),
  );
  await Navigator.maybeOf(context)?.push(
    MaterialPageRoute(
      settings: const RouteSettings(name: CollectionPage.routeName),
      builder: (context) => Provider<CollectionSource>.value(
        value: source,
        child: CollectionPage(
          source: source,
          filters: null,
        ),
      ),
    ),
  );
  source.dispose();
}

// search by name in the whole MEGA cloud drive
class MegaSearchPage extends StatefulWidget {
  static const routeName = '/mega/search';

  final String email;
  final VoidCallback onLoggedOut;

  const new({super.key, required this.email, required this.onLoggedOut});

  @override
  State<MegaSearchPage> createState() => _MegaSearchPageState();
}

class _MegaSearchPageState extends State<MegaSearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  Future<MegaFolderListing>? _results;

  static const _debounceDelay = Duration(milliseconds: 350);

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () => _search(value));
  }

  void _search(String value) {
    final query = value.trim();
    if (query == _query) return;
    setState(() {
      _query = query;
      _results = query.isEmpty ? null : megaService.search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AvesScaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: l10n.megaSearchHint,
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
          onSubmitted: _search,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(AIcons.clear),
              onPressed: () {
                _controller.clear();
                _search('');
              },
            ),
        ],
      ),
      body: SafeArea(
        child: _results == null
            ? const SizedBox()
            : FutureBuilder<MegaFolderListing>(
                future: _results,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final error = snapshot.error;
                  if (error != null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(megaErrorMessage(context, error), textAlign: TextAlign.center),
                      ),
                    );
                  }
                  final listing = snapshot.data!;
                  final mediaCount = listing.files.length;
                  if (mediaCount == 0 && listing.folders.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(l10n.megaSearchEmpty, textAlign: TextAlign.center),
                    );
                  }
                  return ListView(
                    children: [
                      if (mediaCount > 0)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: FilledButton.tonalIcon(
                            icon: const Icon(AIcons.image),
                            label: Text(l10n.megaFolderMediaTile(mediaCount)),
                            onPressed: () => openMegaMedia(
                              context,
                              MegaSource(folderHandle: listing.handle, folderName: _query, searchQuery: _query),
                            ),
                          ),
                        ),
                      ...listing.folders.map(
                        (folder) => ListTile(
                          leading: const Icon(AIcons.folder),
                          title: Text(folder.name),
                          subtitle: Text(
                            [
                              if (folder.location?.isNotEmpty == true) folder.location!,
                              l10n.megaFolderSubtitle(folder.folderCount, folder.mediaCount),
                            ].join('\n'),
                          ),
                          isThreeLine: folder.location?.isNotEmpty == true,
                          onTap: () => Navigator.maybeOf(context)?.push(
                            MaterialPageRoute(
                              settings: const RouteSettings(name: '${MegaPage.routeName}/folder'),
                              builder: (context) => MegaFolderView(
                                email: widget.email,
                                folderHandle: folder.handle,
                                folderName: folder.name,
                                onLoggedOut: widget.onLoggedOut,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
