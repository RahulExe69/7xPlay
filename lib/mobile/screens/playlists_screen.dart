import 'package:cached_network_image/cached_network_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../data/playlists/playlist.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../provider/playlist_provider.dart';
import '../playlists.dart';
import '../widgets/media_art.dart' show tmdbImageUrl;
import '../widgets/page_kit.dart';
import '../widgets/pill_button.dart';
import 'playlist_import_screen.dart';

/// Every custom list, newest first, presented as a visual collection rather
/// than a settings-style row. Creation, import, opening and sync keep their
/// existing provider and route contracts.
class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  @override
  void initState() {
    super.initState();
    // Another device may have changed them since this one last looked.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PlaylistProvider>().sync();
    });
  }

  Future<void> _create() async {
    final id = await createPlaylist(context);
    if (id != null && mounted) await openPlaylist(context, id);
  }

  void _import() => Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const PlaylistImportScreen()));

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final provider = context.watch<PlaylistProvider>();
    final lists = provider.lists;
    final gutter = AppSpace.gutter(context);
    return Scaffold(
      backgroundColor: palette.page,
      appBar: PageAppBar(
        title: tr('playlists'),
        contentWidth: 760,
        actions: <Widget>[
          IconButton(
            tooltip: tr('playlist_import'),
            color: palette.mutedText,
            onPressed: _import,
            icon: Icon(PhosphorIcons.downloadSimple()),
          ),
          IconButton(
            tooltip: tr('playlist_new'),
            color: palette.mutedText,
            onPressed: _create,
            icon: Icon(PhosphorIcons.plus()),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: lists.isEmpty
            ? (provider.loaded
                ? _Empty(onCreate: _create, onImport: _import)
                : const ListSkeleton(scrolls: true, leadingHeight: 66))
            : RefreshIndicator(
                onRefresh: provider.sync,
                child: ReadableWidth(
                  child: GridView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsetsDirectional.fromSTEB(
                      gutter,
                      AppSpace.sm,
                      gutter,
                      AppSpace.xxl + MediaQuery.paddingOf(context).bottom,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 230,
                      mainAxisSpacing: AppSpace.lg,
                      crossAxisSpacing: AppSpace.md,
                      childAspectRatio: .82,
                    ),
                    itemCount: lists.length,
                    itemBuilder: (context, index) {
                      final list = lists[index];
                      return _PlaylistCard(
                        key: ValueKey<String>(list.id),
                        playlist: list,
                        onTap: () => openPlaylist(context, list.id),
                      );
                    },
                  ),
                ),
              ),
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    required this.playlist,
    required this.onTap,
    super.key,
  });

  final Playlist playlist;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Material(
      color: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
        side: BorderSide(color: palette.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: _PlaylistArtwork(playlist: playlist)),
              const SizedBox(height: AppSpace.sm),
              Text(
                playlist.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.scaled(context, AppType.cardTitle).copyWith(
                  color: palette.foreground,
                  fontFamily: AppType.bold,
                ),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                playlistSummary(playlist),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.metadata.copyWith(color: palette.mutedText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A four-title mosaic gives a list its own cover without requiring a new
/// upload or changing the playlist data model. Missing artwork stays quiet
/// and branded through the shared theme rather than showing a broken image.
class _PlaylistArtwork extends StatelessWidget {
  const _PlaylistArtwork({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final items = playlist.items.take(4).toList(growable: false);
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellWidth = constraints.maxWidth / 2;
        Widget cell(int index) {
          Widget fallback() => ColoredBox(
                color: palette.raisedSurface,
                child: Center(
                  child: Icon(
                    PhosphorIcons.listBullets(),
                    color: palette.mutedText,
                    size: 22,
                  ),
                ),
              );
          if (index >= items.length) return fallback();
          final url = tmdbImageUrl(context, items[index].posterPath);
          if (url == null) return fallback();
          return CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            memCacheWidth:
                (cellWidth * MediaQuery.devicePixelRatioOf(context)).round(),
            fadeInDuration: const Duration(milliseconds: 140),
            placeholder: (_, __) => fallback(),
            errorWidget: (_, __, ___) => fallback(),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: Column(
            children: <Widget>[
              Expanded(
                child: Row(
                  children: <Widget>[
                    Expanded(child: cell(0)),
                    const SizedBox(width: 2),
                    Expanded(child: cell(1)),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Row(
                  children: <Widget>[
                    Expanded(child: cell(2)),
                    const SizedBox(width: 2),
                    Expanded(child: cell(3)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onCreate, required this.onImport});

  final VoidCallback onCreate;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(PhosphorIcons.listPlus(),
                  size: 40, color: palette.mutedText),
              const SizedBox(height: AppSpace.lg),
              Text(
                tr('playlists_empty_title'),
                textAlign: TextAlign.center,
                style: AppType.sectionHeader.copyWith(
                    fontFamily: AppType.bold, color: palette.foreground),
              ),
              const SizedBox(height: AppSpace.sm),
              Text(
                tr('playlists_empty_message'),
                textAlign: TextAlign.center,
                style: AppType.body.copyWith(color: palette.mutedText),
              ),
              const SizedBox(height: AppSpace.xl),
              PillButton(
                primary: true,
                icon: PhosphorIcons.plus(),
                label: tr('playlist_new'),
                onPressed: onCreate,
              ),
              const SizedBox(height: AppSpace.sm),
              PillButton(
                icon: PhosphorIcons.downloadSimple(),
                label: tr('playlist_import'),
                onPressed: onImport,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
