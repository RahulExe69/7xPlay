import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../controllers/tv_catalog_controller.dart';
import '../../data/repositories/playlist_repository.dart';
import '../../provider/playlist_provider.dart';
import '../app/tv_design.dart';
import '../focus/tv_keymap.dart';
import '../models/tv_media_item.dart';
import '../widgets/tv_pill_button.dart';
import '../widgets/tv_playlist_picker.dart' show tvPlaylistEditMessage;
import '../widgets/tv_state_panel.dart';
import 'tv_collection_screen.dart';
import 'tv_media_details_screen.dart';

/// Someone's public list on the TV: who made it and how many titles, then
/// Save a copy or Browse, which opens its titles as a grid.
class TvSharedPlaylistScreen extends StatefulWidget {
  const TvSharedPlaylistScreen({required this.code, super.key});

  final String code;

  @override
  State<TvSharedPlaylistScreen> createState() => _TvSharedPlaylistScreenState();
}

class _TvSharedPlaylistScreenState extends State<TvSharedPlaylistScreen> {
  late Future<SharedPlaylist> _list = _load();
  bool _saving = false;

  Future<SharedPlaylist> _load() {
    final repository = context.read<PlaylistProvider>().repository;
    if (repository == null) {
      return Future<SharedPlaylist>.error(
          const PlaylistImportException('unavailable'));
    }
    return repository.fetchShared(widget.code);
  }

  void _browse(SharedPlaylist shared) {
    const page = 24;
    final items = shared.entries.map((entry) => entry.toMediaItem()).toList();
    Navigator.of(context).push<void>(MaterialPageRoute<void>(
      builder: (routeContext) => TvCollectionScreen(
        collection: TvCollection(
          id: 'shared-${shared.code}',
          title: shared.name,
          kicker: tr('playlist_shared'),
          loadPage: (number) async {
            final start = (number - 1) * page;
            if (start >= items.length) return const <TvMediaItem>[];
            return items.sublist(start, (start + page).clamp(0, items.length));
          },
        ),
        onOpenMedia: (item) => Navigator.of(routeContext).push<void>(
          MaterialPageRoute<void>(
              builder: (_) => TvMediaDetailsScreen(item: item)),
        ),
      ),
    ));
  }

  Future<void> _saveCopy(SharedPlaylist shared) async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      await context.read<PlaylistProvider>().create(
            shared.name,
            description: shared.description,
            items: shared.entries.map((entry) => entry.toMediaItem()).toList(),
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger?.showSnackBar(SnackBar(
        content:
            Text(tr('playlist_copy_saved', namedArgs: {'name': shared.name})),
      ));
    } on PlaylistEditException catch (error) {
      messenger?.showSnackBar(
          SnackBar(content: Text(tvPlaylistEditMessage(error.error))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final palette = TvPalette.of(context);
    return Scaffold(
      backgroundColor: TvDesign.surfaceFor(context),
      body: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 48, vertical: 28),
        child: TvKeymap(
          onBack: () => Navigator.of(context).pop(),
          child: FutureBuilder<SharedPlaylist>(
            future: _list,
            builder: (context, snapshot) {
              final shared = snapshot.data;
              if (snapshot.hasError) {
                final error = snapshot.error;
                final missing = error is PlaylistImportException &&
                    error.code == 'list_not_found';
                return Center(
                  child: missing
                      ? TvStatePanel(
                          title: tr('playlist_shared_missing_title'),
                          message: tr('playlist_shared_missing_message'),
                          icon: PhosphorIcons.lockSimple(),
                          actionLabel: tr('go_back'),
                          onAction: () => Navigator.of(context).pop(),
                        )
                      : TvStatePanel.error(
                          message: tr('playlist_shared_failed'),
                          onRetry: () => setState(() => _list = _load()),
                        ),
                );
              }
              if (shared == null) {
                return const Center(child: CircularProgressIndicator());
              }
              final count = plural(
                  'playlist_title_count', shared.entries.length,
                  namedArgs: {'count': '${shared.entries.length}'});
              final owner = shared.ownerName;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        tr('playlist_shared').toUpperCase(),
                        style: TextStyle(
                          color: palette.mutedText,
                          fontFamily: 'FigtreeSB',
                          fontSize: 15,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        shared.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: palette.foreground,
                          fontFamily: 'FigtreeBold',
                          fontSize: 40,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        owner == null
                            ? count
                            : '${tr('playlist_shared_by', namedArgs: {
                                    'name': owner
                                  })} · $count',
                        style:
                            TextStyle(color: palette.mutedText, fontSize: 19),
                      ),
                      if (shared.description
                          case final description?) ...<Widget>[
                        const SizedBox(height: 14),
                        Text(
                          description,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: palette.secondaryText,
                              fontSize: 18,
                              height: 1.35),
                        ),
                      ],
                      const SizedBox(height: 30),
                      FocusTraversalGroup(
                        child: Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          alignment: WrapAlignment.center,
                          children: <Widget>[
                            TvPillButton(
                              label: _saving
                                  ? tr('tv_please_wait')
                                  : tr('playlist_save_copy'),
                              icon: PhosphorIcons.copySimple(),
                              prominent: true,
                              autofocus: true,
                              height: 52,
                              enabled: shared.entries.isNotEmpty,
                              onActivate: () => _saveCopy(shared),
                            ),
                            TvPillButton(
                              label: tr('tv_playlist_browse'),
                              icon: PhosphorIcons.squaresFour(),
                              height: 52,
                              enabled: shared.entries.isNotEmpty,
                              onActivate: () => _browse(shared),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
