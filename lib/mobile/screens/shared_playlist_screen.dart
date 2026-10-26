import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/playlist_repository.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../provider/playlist_provider.dart';
import '../playlists.dart';
import '../widgets/page_kit.dart';
import '../widgets/pill_button.dart';
import '../widgets/poster_card.dart';
import '../widgets/poster_grid.dart';
import 'playlist_screen.dart';

/// Someone's public list, opened from its `flix.quest/list/fq-…` link: who
/// made it, its titles in their order, and Save a copy, which makes it one
/// of this account's own lists (a guest's too) that its maker's later edits
/// leave alone. A link to one of this account's own lists opens that list.
class SharedPlaylistScreen extends StatefulWidget {
  const SharedPlaylistScreen({required this.code, this.repository, super.key});

  /// `fq-` and the list's code.
  final String code;
  final PlaylistRepository? repository;

  @override
  State<SharedPlaylistScreen> createState() => _SharedPlaylistScreenState();
}

class _SharedPlaylistScreenState extends State<SharedPlaylistScreen> {
  late Future<SharedPlaylist> _list = _load();
  bool _saving = false;

  Future<SharedPlaylist> _load() {
    final repository =
        widget.repository ?? context.read<PlaylistProvider>().repository;
    if (repository == null) {
      return Future<SharedPlaylist>.error(
          const PlaylistImportException('unavailable'));
    }
    return repository.fetchShared(widget.code);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final own = context.read<PlaylistProvider>().byShareCode(widget.code);
      if (own != null) {
        Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
          builder: (_) => PlaylistScreen(playlistId: own.id),
        ));
      }
    });
  }

  Future<void> _saveCopy(SharedPlaylist shared) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final id = await context.read<PlaylistProvider>().create(
            shared.name,
            description: shared.description,
            items: shared.entries.map((entry) => entry.toMediaItem()).toList(),
          );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => PlaylistScreen(playlistId: id),
      ));
      messenger?.showSnackBar(SnackBar(
        content:
            Text(tr('playlist_copy_saved', namedArgs: {'name': shared.name})),
      ));
    } on PlaylistEditException catch (error) {
      if (mounted) showPlaylistSnack(context, playlistEditMessage(error.error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return FutureBuilder<SharedPlaylist>(
      future: _list,
      builder: (context, snapshot) {
        final shared = snapshot.data;
        final Widget body;
        if (shared != null) {
          body = _body(context, shared);
        } else if (snapshot.hasError) {
          final error = snapshot.error;
          final missing = error is PlaylistImportException &&
              error.code == 'list_not_found';
          body = missing
              ? EmptyState(
                  icon: PhosphorIcons.lockSimple(),
                  title: tr('playlist_shared_missing_title'),
                  message: tr('playlist_shared_missing_message'),
                )
              : EmptyState.error(
                  message: tr('playlist_shared_failed'),
                  onRetry: () => setState(() => _list = _load()),
                );
        } else {
          body = const Center(child: CircularProgressIndicator());
        }
        return Scaffold(
          backgroundColor: palette.page,
          appBar: PageAppBar(
            title: shared?.name ?? tr('playlist_shared'),
            kicker: shared == null ? null : tr('playlist_shared'),
            actions: <Widget>[
              if (shared != null)
                IconButton(
                  tooltip: tr('share'),
                  color: palette.mutedText,
                  onPressed: () => sharePlaylistLink(shared.name, shared.url),
                  icon: Icon(PhosphorIcons.shareNetwork()),
                ),
            ],
          ),
          body: SafeArea(bottom: false, child: body),
        );
      },
    );
  }

  Widget _body(BuildContext context, SharedPlaylist shared) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final count = plural('playlist_title_count', shared.entries.length,
        namedArgs: {'count': '${shared.entries.length}'});
    final owner = shared.ownerName;
    final description = shared.description;
    return CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding:
              EdgeInsets.fromLTRB(gutter, AppSpace.sm, gutter, AppSpace.lg),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  owner == null
                      ? count
                      : '${tr('playlist_shared_by', namedArgs: {
                              'name': owner
                            })} · $count',
                  style: AppType.metadata.copyWith(color: palette.mutedText),
                ),
                if (description != null) ...<Widget>[
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    description,
                    style: AppType.body.copyWith(color: palette.secondaryText),
                  ),
                ],
                const SizedBox(height: AppSpace.lg),
                PillButton(
                  primary: true,
                  busy: _saving,
                  icon: PhosphorIcons.copySimple(),
                  label: tr('playlist_save_copy'),
                  onPressed:
                      shared.entries.isEmpty ? null : () => _saveCopy(shared),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  tr('playlist_save_copy_hint'),
                  style: AppType.metadata.copyWith(color: palette.mutedText),
                ),
              ],
            ),
          ),
        ),
        if (shared.entries.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: PhosphorIcons.listBullets(),
              title: tr('playlist_empty_title'),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              gutter,
              0,
              gutter,
              AppSpace.xxl + MediaQuery.paddingOf(context).bottom,
            ),
            sliver: SliverGrid.builder(
              gridDelegate: posterGridDelegate(context),
              itemCount: shared.entries.length,
              itemBuilder: (context, index) => LayoutBuilder(
                builder: (context, constraints) => PosterCard(
                  item: shared.entries[index].toMediaItem(),
                  width: constraints.maxWidth,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
