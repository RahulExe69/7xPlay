import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../catalog/media_item.dart';
import '../../data/playlists/playlist.dart';
import '../../provider/playlist_provider.dart';
import '../screens/tv_playlist_name_screen.dart';
import 'tv_dialog.dart';
import 'tv_list_row.dart';

/// What the TV says when a list edit could not be made.
String tvPlaylistEditMessage(PlaylistEditError error) => switch (error) {
      PlaylistEditError.emptyName => tr('playlist_name_required'),
      PlaylistEditError.tooManyLists => tr('playlist_too_many_lists',
          namedArgs: {'count': '${PlaylistLimits.lists}'}),
      PlaylistEditError.listFull => tr('playlist_list_full',
          namedArgs: {'count': '${PlaylistLimits.items}'}),
      PlaylistEditError.missing => tr('playlist_missing'),
    };

void _snack(BuildContext context, String message) =>
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

/// Asks for a name and makes a list, with [first] in it when given.
Future<String?> tvCreatePlaylist(BuildContext context,
    {MediaItem? first}) async {
  final playlists = context.read<PlaylistProvider>();
  final name = await TvPlaylistNameScreen.open(
    context,
    title: tr('playlist_new'),
    actionLabel: tr('playlist_create'),
  );
  if (name == null || !context.mounted) return null;
  try {
    final id = await playlists.create(name, first: first);
    if (context.mounted && first != null) {
      _snack(context, tr('playlist_added_to', namedArgs: {'name': name}));
    }
    return id;
  } on PlaylistEditException catch (error) {
    if (context.mounted) _snack(context, tvPlaylistEditMessage(error.error));
    return null;
  }
}

/// Every custom list as a row that adds [item] or takes it out on OK, then
/// New list and Done.
Future<void> showTvPlaylistPicker(BuildContext context, MediaItem item) async {
  final create = await showTvDialog<bool>(
    context: context,
    barrierDismissible: true,
    title: tr('playlist_save_to'),
    autofocusFirstAction: false,
    content: _PickerRows(item: item, host: context),
    actions: <TvDialogAction>[
      TvDialogAction(
        label: tr('playlist_new'),
        onPressed: () => Navigator.of(context).pop(true),
      ),
      TvDialogAction(
        label: tr('done'),
        isPrimary: true,
        onPressed: () => Navigator.of(context).pop(false),
      ),
    ],
  );
  if (create == true && context.mounted) {
    await tvCreatePlaylist(context, first: item);
  }
}

class _PickerRows extends StatelessWidget {
  const _PickerRows({required this.item, required this.host});

  final MediaItem item;
  final BuildContext host;

  @override
  Widget build(BuildContext context) {
    final playlists = context.watch<PlaylistProvider>();
    final lists = playlists.lists;
    if (lists.isEmpty) return Text(tr('tv_playlists_empty_hint'));
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .45),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final (index, list) in lists.indexed)
              TvListRow(
                autofocus: index == 0,
                label: list.name,
                icon: list.contains(item)
                    ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)
                    : PhosphorIcons.circle(),
                value: plural('playlist_title_count', list.entries.length,
                    namedArgs: {'count': '${list.entries.length}'}),
                showsNext: false,
                semanticLabel: list.contains(item)
                    ? tr('tv_playlist_in', namedArgs: {'name': list.name})
                    : list.name,
                onActivate: () async {
                  try {
                    await playlists.toggle(list.id, item);
                  } on PlaylistEditException catch (error) {
                    if (host.mounted) {
                      _snack(host, tvPlaylistEditMessage(error.error));
                    }
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
