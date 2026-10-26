import '../data/sync/library_scope.dart';
import '../data/sync/local_library.dart';
import '../data/playlists/playlist_store.dart';
import '../controllers/bookmark_database_controller.dart';
import '../controllers/recently_watched_database_controller.dart';
import '../controllers/wellness_database_controller.dart';

class LocalAccountData {
  static Future<void> delete(String owner) async {
    if (LibraryScope.enabled) {
      await (await LocalLibrary.open(owner)).clear();
      await (await PlaylistStore.forOwner(owner)).clear();
      await WellnessDatabaseController.instance.permanentlyDeleteOwner(owner);
      return;
    }
    final movies = MovieDatabaseController();
    final tv = TVDatabaseController();
    for (final movie in await movies.getMovieList()) {
      if (movie.id != null) await movies.deleteMovie(movie.id!);
    }
    for (final show in await tv.getTVList()) {
      if (show.id != null) await tv.deleteTV(show.id!);
    }
    await (await PlaylistStore.forOwner(owner)).clear();
    await RecentlyWatchedMoviesController().clear();
    await RecentlyWatchedEpisodeController().clear();
    await WellnessDatabaseController.instance.permanentlyDeleteOwner(owner);
  }
}
