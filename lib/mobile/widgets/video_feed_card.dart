import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../catalog/media_item.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../playback.dart';
import 'media_art.dart';
import 'section_header.dart';
import 'title_sheet.dart';

/// A full-width, thumbnail-led card for the Home feed.
///
/// It borrows the fast scan pattern of a video feed while keeping the
/// metadata and actions specific to movies and series. No creator, view or
/// engagement metrics are fabricated.
class VideoFeedCard extends StatelessWidget {
  const VideoFeedCard({
    required this.item,
    this.onTap,
    this.onPlay,
    this.onMore,
    super.key,
  });

  final MediaItem item;
  final VoidCallback? onTap;
  final VoidCallback? onPlay;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final width = MediaQuery.sizeOf(context).width - gutter * 2;
    final id = item.stableId;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          GestureDetector(
            key: ValueKey<String>('video-feed-thumbnail-$id'),
            behavior: HitTestBehavior.opaque,
            onTap: onTap ?? () => MobilePlayback.openDetails(context, item),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    MediaArt(
                      item: item,
                      path: item.backdropPath ?? item.posterPath,
                      width: width,
                      size: item.backdropPath == null ? null : ArtSize.backdrop,
                      placeholder: MediaArt.darkPlaceholder,
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            Color(0x16000000),
                            Color(0x00000000),
                            Color(0x65000000),
                          ],
                          stops: <double>[0, .48, 1],
                        ),
                      ),
                    ),
                    Center(
                      child: Material(
                        color: const Color(0xB8000000),
                        shape: const CircleBorder(),
                        child: IconButton(
                          key: ValueKey<String>('video-feed-play-$id'),
                          tooltip: tr('play'),
                          onPressed:
                              onPlay ?? () => MobilePlayback.play(context, item),
                          icon: Icon(
                            PhosphorIcons.play(PhosphorIconsStyle.fill),
                            color: Colors.white,
                            size: 25,
                          ),
                        ),
                      ),
                    ),
                    PositionedDirectional(
                      start: 10,
                      bottom: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xC9000000),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            tr(item.kind == MediaKind.movie ? 'movie' : 'series_one')
                                .toUpperCase(),
                            style: AppType.kicker.copyWith(
                              color: Colors.white,
                              fontSize: 9,
                              letterSpacing: .8,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: SizedBox(
                  width: 44,
                  height: 62,
                  child: MediaArt(
                    item: item,
                    path: item.posterPath ?? item.backdropPath,
                    width: 44,
                    placeholder: palette.raisedSurface,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.cardTitle.copyWith(
                          color: palette.foreground,
                          fontSize: 15,
                          height: 19 / 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mediaFacts(item),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.metadata.copyWith(
                          color: palette.mutedText,
                        ),
                      ),
                      if (item.overview.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          item.overview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.metadata.copyWith(
                            color: palette.secondaryText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              IconButton(
                key: ValueKey<String>('video-feed-more-$id'),
                tooltip: tr('more_options'),
                visualDensity: VisualDensity.compact,
                color: palette.mutedText,
                onPressed: onMore ?? () => showTitleSheet(context, item),
                icon: Icon(PhosphorIcons.dotsThreeVertical()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A vertical section of video-feed cards; OTT poster shelves remain available
/// alongside it for denser discovery.
class VideoFeedSection extends StatelessWidget {
  const VideoFeedSection({
    required this.title,
    required this.items,
    this.onSeeAll,
    super.key,
  });

  final String title;
  final List<MediaItem> items;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SectionHeader(title: title, onSeeAll: onSeeAll),
        for (var index = 0; index < items.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(height: AppSpace.xl),
          VideoFeedCard(item: items[index]),
        ],
      ],
    );
  }
}
