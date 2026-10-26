import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/billing_repository.dart' show newIdempotencyKey;
import '../../data/repositories/playlist_repository.dart';
import '../../mobile/screens/playlist_import_screen.dart'
    show playlistImportMessage;
import '../../presentation/session/auth_runtime.dart';
import '../../provider/playlist_provider.dart';
import '../../services/media_link.dart';
import '../app/tv_design.dart';
import '../focus/tv_keymap.dart';
import '../widgets/tv_form_keyboard.dart';
import '../widgets/tv_pill_button.dart';
import '../widgets/tv_state_panel.dart';
import 'tv_playlist_name_screen.dart';

/// Imports a public TMDB list on the TV: its number (or whole link) typed on
/// FlixQuest's keyboard, then the read's progress, then a preview to keep as
/// a new list. (IMDb import is switched off for now.)
class TvPlaylistImportScreen extends StatefulWidget {
  const TvPlaylistImportScreen({this.initialUrl, this.repository, super.key});

  final String? initialUrl;
  final PlaylistRepository? repository;

  @override
  State<TvPlaylistImportScreen> createState() => _TvPlaylistImportScreenState();
}

class _TvPlaylistImportScreenState extends State<TvPlaylistImportScreen> {
  final _keyboard = GlobalKey<TvFormKeyboardState>();
  late String _text = widget.initialUrl ?? '';
  PlaylistImport? _import;
  String? _error;
  bool _busy = false;
  String? _name;
  Timer? _poll;

  static const _maxLength = 120;

  PlaylistRepository? get _repository =>
      widget.repository ?? context.read<PlaylistProvider>().repository;

  bool get _signedIn =>
      widget.repository != null || AuthRuntime.maybeSession?.user != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keyboard.currentState?.requestFocus();
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _type(String text) {
    if (_text.length >= _maxLength) return;
    setState(() {
      _text = (_text + text).trim();
      _error = null;
    });
  }

  void _delete() {
    if (_text.isEmpty) return;
    setState(() => _text = _text.substring(0, _text.length - 1));
  }

  /// A bare number is a TMDB list id; anything else must read as a link.
  int? get _listId {
    final text = _text.trim();
    final number = int.tryParse(text);
    if (number != null && number > 0) return number;
    final target = MediaLink.parse(text);
    return target is TmdbListLink ? target.id : null;
  }

  Future<void> _find() async {
    if (_busy) return;
    // IMDb import is switched off for now.
    // if (MediaLink.parse(_text) is ImdbListLink) {
    //   setState(() => _error = tr('tv_playlist_import_imdb'));
    //   return;
    // }
    final id = _listId;
    if (id == null) {
      setState(() => _error = tr('tv_playlist_import_hint'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _show(await _repository!
          .startImport(url: 'https://www.themoviedb.org/list/$id'));
    } on PlaylistImportException catch (error) {
      if (mounted) setState(() => _error = playlistImportMessage(error.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(PlaylistImport import) {
    if (!mounted) return;
    setState(() {
      _import = import;
      _name ??= import.ready ? import.name : null;
    });
    _poll?.cancel();
    if (import.pending) {
      _poll = Timer(const Duration(milliseconds: 1500), () async {
        try {
          _show(await _repository!.fetchImport(import.id));
        } on PlaylistImportException catch (error) {
          if (mounted) {
            setState(() => _error = playlistImportMessage(error.code));
          }
        }
      });
    }
  }

  Future<void> _startOver() async {
    final import = _import;
    _poll?.cancel();
    setState(() {
      _import = null;
      _name = null;
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _keyboard.currentState?.requestFocus();
    });
    if (import != null && import.pending) {
      try {
        await _repository!.cancelImport(import.id);
      } on PlaylistImportException {
        // Laravel prunes an abandoned import either way.
      }
    }
  }

  Future<void> _rename() async {
    final name = await TvPlaylistNameScreen.open(
      context,
      title: tr('playlist_name'),
      actionLabel: tr('save'),
      initialName: _name ?? '',
    );
    if (name != null && mounted) setState(() => _name = name);
  }

  Future<void> _create(PlaylistImport import) async {
    if (_busy) return;
    final playlists = context.read<PlaylistProvider>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _repository!.commitImport(
        import.id,
        playlistId: newIdempotencyKey(),
        name: _name,
      );
      await playlists.sync();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pop();
      messenger?.showSnackBar(SnackBar(
        content: Text(plural('playlist_import_added', result.added,
            namedArgs: {'count': '${result.added}'})),
      ));
    } on PlaylistImportException catch (error) {
      if (mounted) setState(() => _error = playlistImportMessage(error.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final import = _import;
    final Widget body;
    if (!_signedIn || _repository == null) {
      body = Center(
        child: TvStatePanel(
          title: tr('playlist_import'),
          message: tr(_signedIn
              ? 'playlist_import_error_unavailable'
              : 'playlist_import_sign_in'),
          icon: PhosphorIcons.userCircle(),
          actionLabel: tr('go_back'),
          onAction: () => Navigator.of(context).pop(),
        ),
      );
    } else if (import == null) {
      body = _input(context);
    } else if (import.pending) {
      body = _status(
        context,
        title: import.name ?? tr('playlist_import_reading'),
        message: import.sourceCount > 0
            ? tr('playlist_import_progress', namedArgs: {
                'done': '${import.processedCount}',
                'total': '${import.sourceCount}',
              })
            : tr('playlist_import_reading'),
        progress: import.progress,
        actions: <Widget>[
          TvPillButton(
              label: tr('cancel'), autofocus: true, onActivate: _startOver),
        ],
      );
    } else if (import.ready && (import.matchedCount ?? 0) > 0) {
      final found = import.matchedCount ?? 0;
      final skipped = import.unresolvedCount + import.unsupportedCount;
      body = _status(
        context,
        title: _name ?? import.name ?? tr('playlist_import'),
        message: <String>[
          plural('playlist_import_found', found,
              namedArgs: {'count': '$found'}),
          if (skipped > 0)
            plural('playlist_import_skipped', skipped,
                namedArgs: {'count': '$skipped'}),
        ].join(' · '),
        actions: <Widget>[
          TvPillButton(
            label: _busy ? tr('tv_please_wait') : tr('playlist_create'),
            prominent: true,
            autofocus: true,
            height: 52,
            onActivate: () => _create(import),
          ),
          TvPillButton(
            label: tr('tv_playlist_rename'),
            icon: PhosphorIcons.pencilSimple(),
            height: 52,
            onActivate: _rename,
          ),
          TvPillButton(label: tr('cancel'), height: 52, onActivate: _startOver),
        ],
      );
    } else {
      body = _status(
        context,
        title: tr('playlist_import_failed'),
        message: import.ready
            ? tr('playlist_import_none_found')
            : playlistImportMessage(import.errorCode ?? ''),
        actions: <Widget>[
          TvPillButton(
            label: tr('playlist_import_again'),
            autofocus: true,
            prominent: true,
            onActivate: _startOver,
          ),
        ],
      );
    }
    return Scaffold(
      backgroundColor: TvDesign.surfaceFor(context),
      body: SafeArea(
        minimum: const EdgeInsets.symmetric(horizontal: 48, vertical: 28),
        child: body,
      ),
    );
  }

  Widget _input(BuildContext context) {
    final palette = TvPalette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 650;
        final keyboardWidth = <double>[
          constraints.maxWidth * 0.5,
          TvFormKeyboard.widthFor(constraints.maxHeight - (compact ? 64 : 84)),
          620,
        ].reduce((a, b) => a < b ? a : b);
        final error = _error;
        return Row(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    tr('tv_playlist_import_title'),
                    style: TextStyle(
                      color: palette.foreground,
                      fontFamily: 'FigtreeBold',
                      fontSize: compact ? 28 : 36,
                      letterSpacing: -0.45,
                      height: 1.1,
                    ),
                  ),
                  SizedBox(height: compact ? 6 : 10),
                  Text(
                    tr('tv_playlist_import_intro'),
                    style: TextStyle(
                      color: palette.mutedText,
                      fontSize: compact ? 15 : 18,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: compact ? 18 : 28),
                  Container(
                    height: compact ? 64 : 76,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: palette.idleFill,
                      borderRadius:
                          BorderRadius.circular(TvDesign.cardRadius * 2),
                      border: Border.all(
                        color: error != null
                            ? Theme.of(context).colorScheme.error
                            : palette.foreground,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(PhosphorIcons.link(),
                            color: palette.mutedText, size: 24),
                        const SizedBox(width: 14),
                        Flexible(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            reverse: true,
                            physics: const NeverScrollableScrollPhysics(),
                            child: Text(
                              _text,
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                color: palette.foreground,
                                fontFamily: 'FigtreeSB',
                                fontSize: compact ? 22 : 26,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 2,
                          height: compact ? 24 : 28,
                          margin: const EdgeInsetsDirectional.only(start: 2),
                          color: palette.foreground,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: compact ? 10 : 14),
                  Text(
                    // IMDb import is switched off for now; this line used to
                    // point IMDb lists to the phone (tv_playlist_import_imdb).
                    error ?? tr('tv_playlist_import_hint'),
                    style: TextStyle(
                      color: error != null
                          ? Theme.of(context).colorScheme.error
                          : palette.mutedText,
                      fontFamily: error != null ? 'FigtreeSB' : null,
                      fontSize: compact ? 15 : 17,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: compact ? 32 : 48),
            SizedBox(
              width: keyboardWidth,
              child: Center(
                child: TvFormKeyboard(
                  key: _keyboard,
                  width: keyboardWidth,
                  onType: _type,
                  onDelete: _delete,
                  onClear: () => setState(() {
                    _text = '';
                    _error = null;
                  }),
                  onAction: _find,
                  actionLabel:
                      _busy ? tr('tv_please_wait') : tr('playlist_import_find'),
                  actionIcon: PhosphorIcons.magnifyingGlass(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _status(
    BuildContext context, {
    required String title,
    required String message,
    required List<Widget> actions,
    double? progress,
  }) {
    final palette = TvPalette.of(context);
    final error = _error;
    return TvKeymap(
      onBack: () => Navigator.of(context).pop(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: palette.foreground,
                  fontFamily: 'FigtreeBold',
                  fontSize: 34,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: palette.mutedText, fontSize: 19, height: 1.35),
              ),
              if (progress != null || _import?.pending == true) ...<Widget>[
                const SizedBox(height: 22),
                LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(4),
                  backgroundColor: palette.idleFill,
                  color: palette.foreground,
                ),
              ],
              if (error != null) ...<Widget>[
                const SizedBox(height: 14),
                Text(error,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 17)),
              ],
              const SizedBox(height: 30),
              FocusTraversalGroup(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: actions,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
