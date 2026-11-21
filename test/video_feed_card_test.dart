import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/mobile/widgets/video_feed_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MediaItem _movie() => const MediaItem(
      kind: MediaKind.movie,
      id: 550,
      title: 'Dune: Part Two',
      overview: 'A science-fiction epic.',
      posterPath: null,
      backdropPath: null,
      rating: 8.2,
      releaseDate: '2024-02-27',
    );

void main() {
  testWidgets('video feed card exposes cinematic artwork and title metadata',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: VideoFeedCard(item: _movie())),
      ),
    );

    expect(find.text('Dune: Part Two'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('video-feed-thumbnail-movie:550')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('video-feed-more-movie:550')),
      findsOneWidget,
    );
  });

  testWidgets('thumbnail opens details and play action starts playback',
      (tester) async {
    var opened = 0;
    var played = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          body: VideoFeedCard(
            item: _movie(),
            onTap: () => opened++,
            onPlay: () => played++,
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('video-feed-thumbnail-movie:550')),
    );
    expect(opened, 1);

    await tester.tap(
      find.byKey(const ValueKey<String>('video-feed-play-movie:550')),
    );
    expect(played, 1);
  });
}
