import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/injections/injection.dart';
import '/routes/routes_names.dart';
import '../../domain/entities/create_room_params.dart';
import '../../domain/entities/room_type.dart';
import '../bloc/create_room/create_room_cubit.dart';
import '../bloc/create_room/create_room_state.dart';

/// Emoji the creator can choose from; the picked ones become the room's
/// reaction palette.
const _reactionPalette = <String>[
  '😂', '❤️', '🔥', '👍', '👎', '😮',
  '😢', '😡', '👏', '🎉', '💯', '🤔',
  '😍', '😅', '😱', '🥳', '🤣', '💀',
  '👀', '✨', '🙏', '🤯',
];

const _defaultReactions = <String>['😂', '❤️', '🔥', '👍', '😮', '😢', '👏', '🎉'];

const _maxReactions = 8;

class CreateRoomPage extends StatelessWidget {
  const CreateRoomPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CreateRoomCubit>(
      create: (_) => sl<CreateRoomCubit>(),
      child: const _CreateRoomView(),
    );
  }
}

class _CreateRoomView extends StatefulWidget {
  const _CreateRoomView();

  @override
  State<_CreateRoomView> createState() => _CreateRoomViewState();
}

class _CreateRoomViewState extends State<_CreateRoomView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _externalUrl = TextEditingController();
  final _videoUrl = TextEditingController();
  final _password = TextEditingController();

  RoomType _type = RoomType.external;
  String? _videoPath;
  String? _videoName;
  final List<String> _reactions = [..._defaultReactions];

  @override
  void dispose() {
    _name.dispose();
    _externalUrl.dispose();
    _videoUrl.dispose();
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
    context.read<CreateRoomCubit>().submit(
      CreateRoomParams(
        name: _name.text.trim(),
        type: _type,
        password: _password.text.trim().isEmpty ? null : _password.text.trim(),
        externalUrl: _type == RoomType.external ? _externalUrl.text.trim() : null,
        videoUrl: _type == RoomType.download ? _videoUrl.text.trim() : null,
        localVideoPath: _type == RoomType.upload ? _videoPath : null,
        reactions: _reactions.isEmpty ? null : List.of(_reactions),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr(TranslationKeys.createRoomTitle))),
      body: BlocConsumer<CreateRoomCubit, CreateRoomState>(
        listener: (context, state) {
          if (state.status == CreateRoomStatus.success && state.createdSlug != null) {
            context.pushReplacementNamed(
              RoutesNames.room,
              pathParameters: {'slug': state.createdSlug!},
            );
          } else if (state.status == CreateRoomStatus.failure) {
            context.showSnack(context.tr(state.errorKey ?? TranslationKeys.errorUnknown));
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
                        validator: (v) =>
                            (v == null || v.trim().length < 2) ? context.tr(TranslationKeys.roomName) : null,
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
                          hintText: context.tr(TranslationKeys.passwordOptionalHint),
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 20),

                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${context.tr(TranslationKeys.chooseReactions)}  (${_reactions.length}/$_maxReactions)',
                          style: context.text.titleSmall,
                        ),
                      ),
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

  Widget _reactionsPicker(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _reactionPalette.map((emoji) {
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
                color: selected ? context.colors.primary : context.colors.outline,
                width: selected ? 2 : 1,
              ),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 20)),
          ),
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
          value: RoomType.external,
          icon: const Icon(Icons.cast_rounded, size: 18),
          label: Text(context.tr(TranslationKeys.typeExternal)),
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
      case RoomType.external:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr(TranslationKeys.typeExternalDesc), style: context.text.bodySmall),
            const SizedBox(height: 8),
            TextFormField(
              controller: _externalUrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: context.tr(TranslationKeys.externalUrl),
                hintText: context.tr(TranslationKeys.externalUrlHint),
                prefixIcon: const Icon(Icons.public_rounded),
              ),
              validator: (v) => (_type == RoomType.external && (v == null || !v.startsWith('http')))
                  ? context.tr(TranslationKeys.externalUrlHint)
                  : null,
            ),
          ],
        );
      case RoomType.download:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr(TranslationKeys.typeDownloadDesc), style: context.text.bodySmall),
            const SizedBox(height: 8),
            TextFormField(
              controller: _videoUrl,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: context.tr(TranslationKeys.videoUrl),
                hintText: context.tr(TranslationKeys.videoUrlHint),
                prefixIcon: const Icon(Icons.download_rounded),
              ),
              validator: (v) => (_type == RoomType.download && (v == null || !v.startsWith('http')))
                  ? context.tr(TranslationKeys.videoUrlHint)
                  : null,
            ),
          ],
        );
      case RoomType.upload:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr(TranslationKeys.typeUploadDesc), style: context.text.bodySmall),
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
      return _progress(context, context.tr(TranslationKeys.uploadingVideo), state.uploadProgress);
    }
    if (state.status == CreateRoomStatus.downloading) {
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
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.check_rounded),
      label: Text(context.tr(TranslationKeys.create)),
    );
  }

  Widget _progress(BuildContext context, String label, double? value, {String? trailing}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: context.text.bodyMedium)),
            if (trailing != null) Text(trailing, style: context.text.titleSmall),
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
