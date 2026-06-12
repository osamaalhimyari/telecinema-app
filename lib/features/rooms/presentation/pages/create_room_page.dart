import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '/core/constants/categories.dart';
import '/core/constants/reaction_emojis.dart';
import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/injections/injection.dart';
import '/routes/routes_names.dart';
import '../../domain/entities/create_room_params.dart';
import '../../domain/entities/room_type.dart';
import '../bloc/create_room/create_room_cubit.dart';
import '../bloc/create_room/create_room_state.dart';

const _defaultReactions = <String>[
  '😂',
  '❤️',
  '🔥',
  '👍',
  '😮',
  '😢',
  '👏',
  '🎉',
];

const _maxReactions = 8;

class CreateRoomPage extends StatelessWidget {
  const CreateRoomPage({
    super.key,
    this.initialName,
    this.initialMagnet,
    this.initialVideoUrl,
    this.initialCategory,
    this.initialImdbId,
    this.initialMaxHeight,
  });

  /// Optional pre-fill (e.g. opened from the Browse catalogue with a chosen
  /// torrent, or from the topcinema / YouTube direct-download flows). When
  /// [initialMagnet] is set the form opens on the torrent type; when
  /// [initialVideoUrl] is set it opens on the download type with the link filled
  /// in; [initialCategory] pre-selects a category chip (`movies` / `series`);
  /// [initialImdbId] is carried through so the room can later search subtitles
  /// by IMDB id; [initialMaxHeight] is the YouTube-chosen download quality
  /// (height in px) carried through to the server, unused by other sources.
  final String? initialName;
  final String? initialMagnet;
  final String? initialVideoUrl;
  final String? initialCategory;
  final String? initialImdbId;
  final int? initialMaxHeight;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CreateRoomCubit>(
      create: (_) => sl<CreateRoomCubit>(),
      child: _CreateRoomView(
        initialName: initialName,
        initialMagnet: initialMagnet,
        initialVideoUrl: initialVideoUrl,
        initialCategory: initialCategory,
        initialImdbId: initialImdbId,
        initialMaxHeight: initialMaxHeight,
      ),
    );
  }
}

class _CreateRoomView extends StatefulWidget {
  const _CreateRoomView({
    this.initialName,
    this.initialMagnet,
    this.initialVideoUrl,
    this.initialCategory,
    this.initialImdbId,
    this.initialMaxHeight,
  });

  final String? initialName;
  final String? initialMagnet;
  final String? initialVideoUrl;
  final String? initialCategory;
  final String? initialImdbId;
  final int? initialMaxHeight;

  @override
  State<_CreateRoomView> createState() => _CreateRoomViewState();
}

class _CreateRoomViewState extends State<_CreateRoomView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _externalUrl = TextEditingController();
  final _videoUrl = TextEditingController();
  final _magnet = TextEditingController();
  final _password = TextEditingController();

  RoomType _type = RoomType.torrent;
  String? _videoPath;
  String? _videoName;
  String? _category;
  final List<String> _reactions = [..._defaultReactions];

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) _name.text = widget.initialName!;
    if (widget.initialMagnet != null) {
      _magnet.text = widget.initialMagnet!;
      _type = RoomType.torrent;
    }
    if (widget.initialVideoUrl != null) {
      _videoUrl.text = widget.initialVideoUrl!;
      _type = RoomType.download;
    }
    if (widget.initialCategory != null &&
        kCategories.contains(widget.initialCategory)) {
      _category = widget.initialCategory;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _externalUrl.dispose();
    _videoUrl.dispose();
    _magnet.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (file != null) {
      setState(() {
        _videoPath = file.path;
        _videoName = file.name;
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_type == RoomType.upload && _videoPath == null) {
      context.showSnack(context.tr(TranslationKeys.pickVideo));
      return;
    }

    // The "Download (server fetches)" field accepts either an http(s) link or a
    // magnet — the server downloads either to a file. A magnet pasted here is
    // routed to the `magnet` param (server full-download); a magnet in the
    // dedicated Torrent field streams on-device instead.
    final downloadText = _videoUrl.text.trim();
    final downloadIsMagnet = downloadText.startsWith('magnet:');

    context.read<CreateRoomCubit>().submit(
      CreateRoomParams(
        name: _name.text.trim(),
        type: _type,
        password: _password.text.trim().isEmpty ? null : _password.text.trim(),
        externalUrl: _type == RoomType.external
            ? _externalUrl.text.trim()
            : null,
        videoUrl: _type == RoomType.download && !downloadIsMagnet ? downloadText : null,
        magnet: _type == RoomType.torrent
            ? _magnet.text.trim()
            : (_type == RoomType.download && downloadIsMagnet ? downloadText : null),
        localVideoPath: _type == RoomType.upload ? _videoPath : null,
        reactions: _reactions.isEmpty ? null : List.of(_reactions),
        category: _category,
        imdbId: widget.initialImdbId,
        // Only meaningful for a server download (the YouTube flow sets it).
        maxHeight: _type == RoomType.download ? widget.initialMaxHeight : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr(TranslationKeys.createRoomTitle))),
      body: BlocConsumer<CreateRoomCubit, CreateRoomState>(
        listener: (context, state) {
          if (state.status == CreateRoomStatus.success &&
              state.createdSlug != null) {
            context.pushReplacementNamed(
              RoutesNames.room,
              pathParameters: {'slug': state.createdSlug!},
            );
          } else if (state.status == CreateRoomStatus.failure) {
            context.showSnack(
              context.tr(state.errorKey ?? TranslationKeys.errorUnknown),
            );
            context.read<CreateRoomCubit>().reset();
          }
        },
        builder: (context, state) {
          return AbsorbPointer(
            absorbing: state.isBusy,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
              children: [
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(context, TranslationKeys.roomName),
                      TextFormField(
                        controller: _name,
                        decoration: InputDecoration(
                          hintText: context.tr(TranslationKeys.roomNameHint),
                        ),
                        validator: (v) => (v == null || v.trim().length < 2)
                            ? context.tr(TranslationKeys.roomName)
                            : null,
                      ),
                      const SizedBox(height: 20),

                      _label(context, TranslationKeys.sourceType),
                      _typeSelector(context),
                      const SizedBox(height: 16),

                      _sourceField(context),
                      const SizedBox(height: 20),

                      _label(context, TranslationKeys.password),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        decoration: InputDecoration(
                          hintText: context.tr(
                            TranslationKeys.passwordOptionalHint,
                          ),
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 20),

                      _label(context, TranslationKeys.category),
                      _categorySelector(context),
                      const SizedBox(height: 20),

                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${context.tr(TranslationKeys.chooseReactions)}  (${_reactions.length}/$_maxReactions)',
                          style: context.text.titleSmall,
                        ),
                      ),
                      _selectedReactionsRow(context),
                      _reactionsPicker(context),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _submitButton(context, state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _label(BuildContext context, String key) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(context.tr(key), style: context.text.titleSmall),
  );

  /// A live preview of the currently-chosen reactions, shown above the full
  /// picker. Tapping a chip removes that emoji from the selection ("changeable
  /// by pressing").
  Widget _selectedReactionsRow(BuildContext context) {
    if (_reactions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          context.tr(TranslationKeys.chooseReactions),
          style: context.text.bodySmall?.copyWith(color: context.colors.outline),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _reactions.map((emoji) {
          return GestureDetector(
            onTap: () => setState(() => _reactions.remove(emoji)),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: context.colors.primary),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 4),
                  Icon(Icons.close_rounded, size: 14, color: context.colors.primary),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _reactionsPicker(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        border: Border.all(color: context.colors.outline),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kReactionEmojis.map((emoji) {
            final selected = _reactions.contains(emoji);
            return GestureDetector(
              onTap: () => _toggleReaction(emoji),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? context.colors.primary.withValues(alpha: 0.18)
                      : context.colors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? context.colors.primary
                        : context.colors.outline,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Single-select category chips. Tapping the active chip clears the choice
  /// (category is optional), so the param is sent only when one is picked.
  Widget _categorySelector(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kCategories.map((c) {
        final selected = _category == c;
        return ChoiceChip(
          label: Text(context.tr(categoryLabelKey(c))),
          selected: selected,
          onSelected: (_) => setState(() => _category = selected ? null : c),
        );
      }).toList(),
    );
  }

  void _toggleReaction(String emoji) {
    if (_reactions.contains(emoji)) {
      setState(() => _reactions.remove(emoji));
    } else if (_reactions.length < _maxReactions) {
      setState(() => _reactions.add(emoji));
    } else {
      context.showSnack(context.tr(TranslationKeys.chooseReactions));
    }
  }

  Widget _typeSelector(BuildContext context) {
    return SegmentedButton<RoomType>(
      segments: [
        ButtonSegment(
          value: RoomType.torrent,
          icon: const Icon(Icons.stream_rounded, size: 18),
          label: Text(context.tr(TranslationKeys.typeTorrent)),
        ),
        ButtonSegment(
          value: RoomType.download,
          icon: const Icon(Icons.link_rounded, size: 18),
          label: Text(context.tr(TranslationKeys.typeDownload)),
        ),
        ButtonSegment(
          value: RoomType.upload,
          icon: const Icon(Icons.upload_rounded, size: 18),
          label: Text(context.tr(TranslationKeys.typeUpload)),
        ),
      ],
      selected: {_type},
      onSelectionChanged: (s) => setState(() => _type = s.first),
      showSelectedIcon: false,
    );
  }

  Widget _sourceField(BuildContext context) {
    switch (_type) {
      case RoomType.torrent:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(TranslationKeys.typeTorrentDesc),
              style: context.text.bodySmall,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _magnet,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: context.tr(TranslationKeys.magnetUrl),
                hintText: context.tr(TranslationKeys.magnetUrlHint),
                prefixIcon: const Icon(Icons.stream_rounded),
              ),
              validator: (v) =>
                  (_type == RoomType.torrent &&
                      (v == null || !v.trim().startsWith('magnet:')))
                  ? context.tr(TranslationKeys.magnetUrlHint)
                  : null,
            ),
          ],
        );
      case RoomType.external:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(TranslationKeys.typeExternalDesc),
              style: context.text.bodySmall,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _externalUrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: context.tr(TranslationKeys.externalUrl),
                hintText: context.tr(TranslationKeys.externalUrlHint),
                prefixIcon: const Icon(Icons.public_rounded),
              ),
              validator: (v) =>
                  (_type == RoomType.external &&
                      (v == null || !v.startsWith('http')))
                  ? context.tr(TranslationKeys.externalUrlHint)
                  : null,
            ),
          ],
        );
      case RoomType.download:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(TranslationKeys.typeDownloadDesc),
              style: context.text.bodySmall,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _videoUrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: context.tr(TranslationKeys.videoUrl),
                hintText: context.tr(TranslationKeys.videoUrlHint),
                prefixIcon: const Icon(Icons.download_rounded),
              ),
              validator: (v) {
                if (_type != RoomType.download) return null;
                final t = v?.trim() ?? '';
                // Accept a direct http(s) link or a magnet — the server fetches
                // either to a file.
                return (t.startsWith('http') || t.startsWith('magnet:'))
                    ? null
                    : context.tr(TranslationKeys.videoUrlHint);
              },
            ),
          ],
        );
      case RoomType.upload:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr(TranslationKeys.typeUploadDesc),
              style: context.text.bodySmall,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickVideo,
              icon: const Icon(Icons.video_library_outlined),
              label: Text(_videoName ?? context.tr(TranslationKeys.pickVideo)),
            ),
          ],
        );
    }
  }

  Widget _submitButton(BuildContext context, CreateRoomState state) {
    if (state.status == CreateRoomStatus.uploading) {
      return _progress(
        context,
        context.tr(TranslationKeys.uploadingVideo),
        state.uploadProgress,
      );
    }
    if (state.status == CreateRoomStatus.downloading) {
      // Torrent rooms reuse the same poll, but there is no download bar — the
      // room opens as soon as peers/metadata are found, so show a prep label.
      if (_type == RoomType.torrent) {
        return _progress(
          context,
          context.tr(TranslationKeys.preparingTorrent),
          null,
        );
      }
      final pct = state.downloadPercent;
      return _progress(
        context,
        context.tr(TranslationKeys.downloadingVideo),
        pct == null ? null : pct / 100,
        trailing: pct == null ? null : '$pct%',
      );
    }
    return FilledButton.icon(
      onPressed: state.isBusy ? null : _submit,
      icon: state.isBusy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.check_rounded),
      label: Text(context.tr(TranslationKeys.create)),
    );
  }

  Widget _progress(
    BuildContext context,
    String label,
    double? value, {
    String? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: context.text.bodyMedium)),
            if (trailing != null)
              Text(trailing, style: context.text.titleSmall),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(value: value, minHeight: 8),
        ),
      ],
    );
  }
}
