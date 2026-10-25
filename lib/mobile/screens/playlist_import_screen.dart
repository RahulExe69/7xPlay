import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
// IMDb import is switched off for now.
// import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';

import '../../data/playlists/playlist.dart';
import '../../data/repositories/billing_repository.dart' show newIdempotencyKey;
import '../../data/repositories/playlist_repository.dart';
import '../../design/app_palette.dart';
import '../../design/app_tokens.dart';
import '../../presentation/session/auth_runtime.dart';
import '../../provider/playlist_provider.dart';
import '../../services/media_link.dart';
import '../playlists.dart';
import '../widgets/media_rows.dart';
import '../widgets/page_kit.dart';
import '../widgets/pill_button.dart';
import 'playlist_screen.dart';

/// What to say when an import cannot go ahead, by Laravel's code.
String playlistImportMessage(String code) => switch (code) {
      'unsupported_link' => tr('playlist_import_error_link'),
      'list_not_found' => tr('playlist_import_error_not_found'),
      'list_private' => tr('playlist_import_error_private'),
      'csv_invalid' => tr('playlist_import_error_csv'),
      'csv_empty' => tr('playlist_import_error_csv_empty'),
      'too_many_imports' => tr('playlist_import_error_busy'),
      'offline' => tr('playlist_import_error_offline'),
      'unavailable' => tr('playlist_import_error_unavailable'),
      'signed_out' || 'guest_account' => tr('playlist_import_sign_in'),
      _ => tr('playlist_import_error_source'),
    };

String playlistProblemReason(String reason) => switch (reason) {
      'not_found' => tr('playlist_problem_not_found'),
      'unsupported_episode' => tr('playlist_problem_episode'),
      _ => tr('playlist_problem_type'),
    };

// IMDb import is switched off for now.
// enum _Source { tmdb, imdb }

/// Brings a public TMDB list in as a list. (IMDb CSV exports are switched off
/// for now; their code is commented out below.)
///
/// The list is read on Laravel and shown here as a preview first: how many
/// titles were found, what could not be placed and why, and whether to make
/// a new list or add to one already here. Nothing changes until that choice
/// is confirmed. IMDb does not let other servers read its list pages, so its
/// lists come in through IMDb's own export.
class PlaylistImportScreen extends StatefulWidget {
  const PlaylistImportScreen({this.initialUrl, this.repository, super.key});

  /// A list link shared into the app.
  final String? initialUrl;

  /// For tests; otherwise the signed-in Laravel client's.
  final PlaylistRepository? repository;

  @override
  State<PlaylistImportScreen> createState() => _PlaylistImportScreenState();
}

class _PlaylistImportScreenState extends State<PlaylistImportScreen> {
  final _url = TextEditingController();
  final _name = TextEditingController();
  // IMDb import is switched off for now.
  // _Source _source = _Source.tmdb;
  PlaylistImport? _import;
  String? _error;
  bool _busy = false;
  bool _append = false;
  String? _target;
  Timer? _poll;

  PlaylistRepository? get _repository =>
      widget.repository ?? context.read<PlaylistProvider>().repository;

  bool get _signedIn =>
      widget.repository != null || AuthRuntime.maybeSession?.user != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialUrl;
    if (initial != null) {
      _url.text = initial;
      // IMDb import is switched off for now.
      // if (MediaLink.parse(initial) is ImdbListLink) _source = _Source.imdb;
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _url.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (text == null || !mounted) return;
    setState(() {
      _url.text = text.trim();
      _error = null;
    });
  }

  Future<void> _startTmdb() async {
    final text = _url.text.trim();
    final target = MediaLink.parse(text);
    // IMDb import is switched off for now.
    // if (target is ImdbListLink) {
    //   setState(() {
    //     _source = _Source.imdb;
    //     _error = null;
    //   });
    //   return;
    // }
    if (target is! TmdbListLink) {
      setState(() => _error = tr('playlist_import_error_link'));
      return;
    }
    await _start(() => _repository!
        .startImport(url: 'https://www.themoviedb.org/list/${target.id}'));
  }

  // IMDb import is switched off for now.
  // Future<void> _startImdb() async {
  // final picked = await FilePicker.platform.pickFiles(
  // type: FileType.custom,
  // allowedExtensions: const <String>['csv'],
  // withData: true,
  // );
  // final file = picked?.files.singleOrNull;
  // final bytes = file?.bytes;
  // if (file == null || bytes == null || !mounted) return;
  // await _start(
  // () => _repository!.startImport(csv: bytes, filename: file.name));
  // }

  Future<void> _start(Future<PlaylistImport> Function() request) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _show(await request());
    } on PlaylistImportException catch (error) {
      if (!mounted) return;
      // IMDb import is switched off for now.
      // setState(() {
      //   if (error.code == 'imdb_export_required') {
      //     _source = _Source.imdb;
      //   } else {
      //     _error = playlistImportMessage(error.code);
      //   }
      // });
      setState(() => _error = playlistImportMessage(error.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _show(PlaylistImport import) {
    if (!mounted) return;
    setState(() {
      _import = import;
      if (import.ready && _name.text.isEmpty) _name.text = import.name ?? '';
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

  Future<void> _cancel() async {
    final import = _import;
    _poll?.cancel();
    setState(() {
      _import = null;
      _error = null;
    });
    if (import != null && import.pending) {
      try {
        await _repository!.cancelImport(import.id);
      } on PlaylistImportException {
        // An abandoned import is pruned by Laravel either way.
      }
    }
  }

  Future<void> _commit() async {
    final import = _import;
    final playlists = context.read<PlaylistProvider>();
    if (import == null || _busy) return;
    final target = _append ? _target : null;
    if (_append && target == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // A list made on this device must reach Laravel before it can be
      // added to.
      await playlists.sync();
      final result = await _repository!.commitImport(
        import.id,
        playlistId: target ?? newIdempotencyKey(),
        append: _append,
        name: _append ? null : _name.text.trim(),
      );
      await playlists.sync();
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => PlaylistScreen(playlistId: result.playlistId),
      ));
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
    final palette = AppPalette.of(context);
    final import = _import;
    final Widget body;
    if (!_signedIn || _repository == null) {
      body = EmptyState(
        icon: PhosphorIcons.userCircle(),
        title: tr('playlist_import'),
        message: tr(_signedIn
            ? 'playlist_import_error_unavailable'
            : 'playlist_import_sign_in'),
      );
    } else if (import == null) {
      body = _input(context);
    } else if (import.pending) {
      body = _progress(context, import);
    } else if (import.ready) {
      body = _preview(context, import);
    } else {
      body = EmptyState.error(
        title: tr('playlist_import_failed'),
        message: playlistImportMessage(import.errorCode ?? ''),
        onRetry: _cancel,
      );
    }
    return Scaffold(
      backgroundColor: palette.page,
      appBar: PageAppBar(title: tr('playlist_import'), contentWidth: 620),
      body: SafeArea(child: body),
    );
  }

  Widget _input(BuildContext context) {
    final palette = AppPalette.of(context);
    final error = _error;
    return ReadableWidth(
      maxWidth: 620,
      child: ListView(
        padding: EdgeInsets.symmetric(
            horizontal: AppSpace.gutter(context), vertical: AppSpace.lg),
        children: <Widget>[
          // IMDb import is switched off for now.
          // SegmentSwitch<_Source>(
          // selected: _source,
          // onChanged: (source) => setState(() {
          // _source = source;
          // _error = null;
          // }),
          // segments: <Segment<_Source>>[
          // Segment<_Source>(_Source.tmdb, 'TMDB'),
          // Segment<_Source>(_Source.imdb, 'IMDb'),
          // ],
          // ),
          // const SizedBox(height: AppSpace.xl),
          // if (_source == _Source.tmdb) ...<Widget>[
          Text(
            tr('playlist_import_tmdb_intro'),
            style: AppType.body.copyWith(color: palette.secondaryText),
          ),
          const SizedBox(height: AppSpace.lg),
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _startTmdb(),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              labelText: tr('playlist_import_link'),
              hintText: 'themoviedb.org/list/8136',
              errorText: error,
              errorMaxLines: 3,
              suffixIcon: IconButton(
                tooltip: tr('paste'),
                onPressed: _paste,
                icon: Icon(PhosphorIcons.clipboardText()),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          ListenableBuilder(
            listenable: _url,
            builder: (context, _) => PillButton(
              primary: true,
              busy: _busy,
              icon: PhosphorIcons.magnifyingGlass(),
              label: tr('playlist_import_find'),
              onPressed: _url.text.trim().isEmpty ? null : _startTmdb,
            ),
          ),
          // IMDb import is switched off for now.
          // ] else ...<Widget>[
          // Text(
          // tr('playlist_import_imdb_intro'),
          // style: AppType.body.copyWith(color: palette.secondaryText),
          // ),
          // const SizedBox(height: AppSpace.lg),
          // for (final (index, step) in <String>[
          // tr('playlist_import_imdb_step_open'),
          // tr('playlist_import_imdb_step_export'),
          // tr('playlist_import_imdb_step_choose'),
          // ].indexed)
          // ListRow(flush: true, leadingNumber: index + 1, label: step),
          // if (error != null) ...<Widget>[
          // const SizedBox(height: AppSpace.md),
          // Text(
          // error,
          // style: AppType.body
          // .copyWith(color: Theme.of(context).colorScheme.error),
          // ),
          // ],
          // const SizedBox(height: AppSpace.xl),
          // PillButton(
          // primary: true,
          // busy: _busy,
          // icon: PhosphorIcons.fileCsv(),
          // label: tr('playlist_import_choose_csv'),
          // onPressed: _startImdb,
          // ),
          // ],
        ],
      ),
    );
  }

  Widget _progress(BuildContext context, PlaylistImport import) {
    final palette = AppPalette.of(context);
    final progress = import.progress;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                import.name ?? tr('playlist_import_reading'),
                textAlign: TextAlign.center,
                style: AppType.sectionHeader.copyWith(
                    fontFamily: AppType.bold, color: palette.foreground),
              ),
              const SizedBox(height: AppSpace.lg),
              LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                borderRadius: BorderRadius.circular(AppRadii.chip),
                backgroundColor: palette.idleFill,
              ),
              const SizedBox(height: AppSpace.md),
              Text(
                import.sourceCount > 0
                    ? tr('playlist_import_progress', namedArgs: {
                        'done': '${import.processedCount}',
                        'total': '${import.sourceCount}',
                      })
                    : tr('playlist_import_reading'),
                style: AppType.metadata.copyWith(color: palette.mutedText),
              ),
              if (_error case final error?) ...<Widget>[
                const SizedBox(height: AppSpace.md),
                Text(error,
                    textAlign: TextAlign.center,
                    style: AppType.body
                        .copyWith(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: AppSpace.xl),
              PillButton(label: tr('cancel'), onPressed: _cancel),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preview(BuildContext context, PlaylistImport import) {
    final palette = AppPalette.of(context);
    final gutter = AppSpace.gutter(context);
    final lists = context.watch<PlaylistProvider>().lists;
    final found = import.matchedCount ?? 0;
    final notes = <String>[
      if (import.duplicateCount > 0)
        plural('playlist_import_duplicates', import.duplicateCount,
            namedArgs: {'count': '${import.duplicateCount}'}),
      if (import.unresolvedCount > 0)
        plural('playlist_import_unresolved', import.unresolvedCount,
            namedArgs: {'count': '${import.unresolvedCount}'}),
      if (import.unsupportedCount > 0)
        plural('playlist_import_unsupported', import.unsupportedCount,
            namedArgs: {'count': '${import.unsupportedCount}'}),
      if (import.truncated)
        tr('playlist_import_truncated',
            namedArgs: {'count': '${PlaylistLimits.items}'}),
    ];
    final canCommit =
        found > 0 && (_append ? _target != null : _name.text.trim().isNotEmpty);
    return ListView(
      padding: EdgeInsets.only(
          top: AppSpace.lg,
          bottom: AppSpace.xxl + MediaQuery.paddingOf(context).bottom),
      children: <Widget>[
        Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                plural('playlist_import_found', found,
                    namedArgs: {'count': '$found'}),
                style: AppType.scaled(context, AppType.pageTitle)
                    .copyWith(color: palette.foreground),
              ),
              const SizedBox(height: AppSpace.xs),
              Text(
                tr(import.provider == 'imdb'
                    ? 'playlist_from_imdb'
                    : 'playlist_from_tmdb'),
                style: AppType.metadata.copyWith(color: palette.mutedText),
              ),
              for (final note in notes) ...<Widget>[
                const SizedBox(height: AppSpace.xs),
                Text(note,
                    style: AppType.body.copyWith(color: palette.secondaryText)),
              ],
            ],
          ),
        ),
        if (import.preview.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpace.xl),
          PosterRow(
            items: import.preview.map((entry) => entry.toMediaItem()).toList(),
          ),
        ],
        if (import.problems.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter - 12),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 12),
              shape: const Border(),
              collapsedShape: const Border(),
              title: Text(
                tr('playlist_import_problems'),
                style: AppType.cardTitle
                    .copyWith(fontSize: 15, color: palette.foreground),
              ),
              children: <Widget>[
                for (final problem in import.problems)
                  ListRow(
                    label: problem.title ?? problem.reference,
                    subtitle: playlistProblemReason(problem.reason),
                  ),
              ],
            ),
          ),
        if (found > 0) ...<Widget>[
          KickerHeading(tr('playlist_import_destination')),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: gutter),
            child: SegmentSwitch<bool>(
              selected: _append,
              onChanged: (append) => setState(() => _append = append),
              segments: <Segment<bool>>[
                Segment<bool>(false, tr('playlist_new')),
                Segment<bool>(true, tr('playlist_import_existing')),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.lg),
          if (!_append)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: TextField(
                controller: _name,
                maxLength: PlaylistLimits.name,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: tr('playlist_name')),
              ),
            )
          else if (lists.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: gutter),
              child: Text(tr('playlists_empty_title'),
                  style: AppType.body.copyWith(color: palette.mutedText)),
            )
          else
            for (final list in lists)
              ListRow(
                leading: PlaylistCover(list: list, width: 30),
                label: list.name,
                subtitle: playlistSummary(list),
                trailing: Icon(
                  _target == list.id
                      ? PhosphorIcons.radioButton(PhosphorIconsStyle.fill)
                      : PhosphorIcons.circle(),
                  color: _target == list.id
                      ? palette.foreground
                      : palette.mutedText,
                ),
                onTap: () => setState(() => _target = list.id),
              ),
          if (_error case final error?)
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, AppSpace.md, gutter, 0),
              child: Text(error,
                  style: AppType.body
                      .copyWith(color: Theme.of(context).colorScheme.error)),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, AppSpace.xl, gutter, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: PillButton(label: tr('cancel'), onPressed: _cancel),
                ),
                const SizedBox(width: AppSpace.md),
                Expanded(
                  child: PillButton(
                    primary: true,
                    busy: _busy,
                    label: _append
                        ? plural('playlist_import_add', found,
                            namedArgs: {'count': '$found'})
                        : tr('playlist_create'),
                    onPressed: canCommit ? _commit : null,
                  ),
                ),
              ],
            ),
          ),
        ] else
          Padding(
            padding: EdgeInsets.fromLTRB(gutter, AppSpace.xl, gutter, 0),
            child: PillButton(
                label: tr('playlist_import_again'), onPressed: _cancel),
          ),
      ],
    );
  }
}
