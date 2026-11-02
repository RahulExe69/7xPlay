import 'package:flixquest/catalog/media_item.dart';
import 'package:flixquest/mobile/widgets/hero_card.dart';
import 'package:flixquest/models/movie.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('phone spotlight uses cinematic backdrop art in a wide frame',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final item = MediaItem.fromMovie(
      Movie(
        id: 123,
        title: 'Featured title',
        posterPath: '/poster.jpg',
        backdropPath: '/backdrop.jpg',
      ),
    );
    late (String?, String?) artwork;
    late double height;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            artwork = HeroCard.artworkFor(context, item);
            height = HeroCard.heightFor(context);
            return const SizedBox();
          },
        ),
      ),
    );

    expect(artwork.$1, '/backdrop.jpg');
    expect(height, lessThanOrEqualTo(390 * .85));
  });
}
