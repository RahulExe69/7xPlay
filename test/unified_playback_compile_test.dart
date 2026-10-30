import 'package:flixquest/screens/common/player.dart';
import 'package:flixquest/screens/movie/movie_video_loader.dart';
import 'package:flixquest/screens/tv/tv_video_loader.dart';
import 'package:flixquest/services/unified_playback_language_service.dart';
import 'package:flixquest/widgets/playback_loading_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unified playback player and loader modules compile', () {
    expect(PlayerOne.new, isNotNull);
    expect(MovieVideoLoader.new, isNotNull);
    expect(TVVideoLoader.new, isNotNull);
    expect(PlaybackLoadingScreen.new, isNotNull);
    expect(UnifiedPlaybackLanguageOption.new, isNotNull);
  });
}
