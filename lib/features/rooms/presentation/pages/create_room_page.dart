import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '/core/constants/categories.dart';
import '/core/constants/reaction_emojis.dart';
import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/features/youtube/data/datasources/youtube_remote_datasource.dart';
import '/features/youtube/presentation/widgets/youtube_stream_picker.dart';
import '/injections/injection.dart';
import '/routes/routes_names.dart';
import '../../domain/entities/create_room_params.dart';
import '../../domain/entities/room_type.dart';
import '../bloc/create_room/create_room_cubit.dart';
import '../bloc/create_room/create_room_state.dart';
import '../bloc/create_room_form/create_room_form_cubit.dart';
import '../bloc/create_room_form/create_room_form_state.dart';

class CreateRoomPage extends StatelessWidget {
  const CreateRoomPage({
    super.key,
    this.initialName,
    this.initialMagnet,
    this.initialVideoUrl,
    this.initialYoutubeUrl,
    this.initialCategory,
    this.initialImdbId,
    this.initialMaxHeight,
    this.initialThumbnail,
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
  final String? initialYoutubeUrl;
  final String? initialCategory;
  final String? initialImdbId;
  final int? initialMaxHeight;
  final String? initialThumbnail;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CreateRoomCubit>(
      create: (_) => sl<CreateRoomCubit>(),
      child: _CreateRoomView(
        initialName: initialName,
        initialMagnet: initialMagnet,
        initialVideoUrl: initialVideoUrl,
        initialYoutubeUrl: initialYoutubeUrl,
        initialCategory: initialCategory,
        initialImdbId: initialImdbId,
        initialMaxHeight: initialMaxHeight,
        initialThumbnail: initialThumbnail,
      ),
    );
  }
}

class _CreateRoomView extends StatelessWidget {
  const _CreateRoomView({
    this.initialName,
    this.initialMagnet,
    this.initialVideoUrl,
    this.initialYoutubeUrl,
    this.initialCategory,
    this.initialImdbId,
    this.initialMaxHeight,
    this.initialThumbnail,
  });

  final String? initialName;
  final String? initialMagnet;
  final String? initialVideoUrl;
  final String? initialYoutubeUrl;
  final String? initialCategory;
  final String? initialImdbId;
  final int? initialMaxHeight;
  final String? initialThumbnail;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<CreateRoomFormCubit>(
      create: (_) => CreateRoomFormCubit(
        initialName: initialName,
        initialMagnet: initialMagnet,
        initialVideoUrl: initialVideoUrl,
        initialYoutubeUrl: initialYoutubeUrl,
        initialCategory: initialCategory,
      ),
      child: _CreateRoomForm(
        initialImdbId: initialImdbId,
        initialMaxHeight: initialMaxHeight,
        initialThumbnail: initialThumbnail,
      ),
    );
  }
}

class _CreateRoomForm extends StatelessWidget {
  const _CreateRoomForm({
    this.initialImdbId,
    this.initialMaxHeight,
    this.initialThumbnail,
  });

  final String? initialImdbId;
  final int? initialMaxHeight;
  final String? initialThumbnail;

  Future<void> _pickVideo(BuildContext context) async {
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (file != null && context.mounted) {
      context.read<CreateRoomFormCubit>().setVideo(file.path, file.name);
    }
  }

  Future<void> _submit(BuildContext context) async {
    final form = context.read<CreateRoomFormCubit>();
    final state = form.state;
    if (!form.formKey.currentState!.validate()) return;
    if (state.type == RoomType.upload && state.videoPath == null) {
      context.showSnack(context.tr(TranslationKeys.pickVideo));
      return;
    }

    // A YouTube room is created by extracting the direct video+audio CDN URLs
    // ON-DEVICE (the server's IP is bot-blocked by YouTube), letting the viewer
    // pick a quality, then submitting them as an ordinary `download` room the
    // server downloads + muxes — no server-side yt-dlp. All YouTube logic stays
    // in the isolated youtube feature; here we just call its picker and submit
    // the resolved links. A null pick (resolve failed / cancelled) just aborts.
    if (state.type == RoomType.youtube) {
      final picked = await pickYoutubeStreams(
        context,
        form.youtubeUrl.text.trim(),
        sl<YoutubeRemoteDataSource>(),
      );
      if (picked == null || !context.mounted) return;
      context.read<CreateRoomCubit>().submit(
        CreateRoomParams(
          name: form.name.text.trim(),
          type: RoomType.download,
          password: form.password.text.trim().isEmpty
              ? null
              : form.password.text.trim(),
          videoUrl: picked.videoUrl,
          audioUrl: picked.audioUrl,
          reactions: state.reactions.isEmpty ? null : List.of(state.reactions),
          category: state.category,
          imdbId: initialImdbId,
          thumbnail: initialThumbnail,
        ),
      );
      return;
    }

    // The "Download (server fetches)" field accepts either an http(s) link or a
    // magnet — the server downloads either to a file. A magnet pasted here is
    // routed to the `magnet` param (server full-download); a magnet in the
    // dedicated Torrent field streams on-device instead.
    final downloadText = form.videoUrl.text.trim();
    final downloadIsMagnet = downloadText.startsWith('magnet:');

    // A Telegram post link is submitted as a `download` too — the server detects
    // the t.me URL and resolves the public post's direct video before fetching,
    // so it lands as a normal file room like any other download.
    final isTelegram = state.type == RoomType.telegram;
    final submitType = isTelegram ? RoomType.download : state.type;

    context.read<CreateRoomCubit>().submit(
      CreateRoomParams(
        name: form.name.text.trim(),
        type: submitType,
        password: form.password.text.trim().isEmpty
            ? null
            : form.password.text.trim(),
        externalUrl: state.type == RoomType.external
            ? form.externalUrl.text.trim()
            : null,
        videoUrl: isTelegram
            ? form.telegramUrl.text.trim()
            : (state.type == RoomType.download && !downloadIsMagnet
                  ? downloadText
                  : null),
        magnet: state.type == RoomType.torrent
            ? form.magnet.text.trim()
            : (state.type == RoomType.download && downloadIsMagnet
                  ? downloadText
                  : null),
        localVideoPath: state.type == RoomType.upload ? state.videoPath : null,
        reactions: state.reactions.isEmpty ? null : List.of(state.reactions),
        category: state.category,
        imdbId: initialImdbId,
        // Server download height cap, used only by the (legacy) catalogue
        // download hand-off; null for a manual paste.
        maxHeight: submitType == RoomType.download ? initialMaxHeight : null,
        // The movie/series poster (from the catalogue). Null → server picks a
        // random placeholder.
        thumbnail: initialThumbnail,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final form = context.read<CreateRoomFormCubit>();
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
                  key: form.formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label(context, TranslationKeys.roomName),
                      TextFormField(
                        controller: form.name,
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
                        controller: form.password,
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

                      _reactionsHeader(context),
                      _selectedReactionsRow(context),
                      _collapsibleReactionsPicker(context),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _submitButton(context, state),
                const SizedBox(height: 28),
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

  /// A copy button for a (often long, prefilled) source field — select-all +
  /// the text toolbar is fiddly on a multi-line magnet, so this copies the whole
  /// field in one tap. Copies the controller's current text and confirms it.
  Widget _copyButton(BuildContext context, TextEditingController controller) {
    return IconButton(
      tooltip: context.tr(TranslationKeys.copy),
      icon: const Icon(Icons.copy_rounded),
      onPressed: () async {
        final text = controller.text.trim();
        if (text.isEmpty) return;
        await Clipboard.setData(ClipboardData(text: text));
        if (context.mounted) {
          context.showSnack(context.tr(TranslationKeys.copied));
        }
      },
    );
  }

  /// A live preview of the currently-chosen reactions, shown above the full
  /// picker. Tapping a chip removes that emoji from the selection ("changeable
  /// by pressing").
  Widget _selectedReactionsRow(BuildContext context) {
    return BlocSelector<CreateRoomFormCubit, CreateRoomFormState, List<String>>(
      selector: (s) => s.reactions,
      builder: (context, reactions) {
        if (reactions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              context.tr(TranslationKeys.chooseReactions),
              style: context.text.bodySmall?.copyWith(
                color: context.colors.outline,
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: reactions.map((emoji) {
              return GestureDetector(
                onTap: () =>
                    context.read<CreateRoomFormCubit>().removeReaction(emoji),
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
                      Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: context.colors.primary,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  /// Tappable header: shows the chosen count and a chevron that expands/collapses
  /// the emoji grid below (kept collapsed by default to keep the form compact).
  Widget _reactionsHeader(BuildContext context) {
    return BlocSelector<CreateRoomFormCubit, CreateRoomFormState, (int, bool)>(
      selector: (s) => (s.reactions.length, s.reactionsExpanded),
      builder: (context, data) {
        final (count, expanded) = data;
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () =>
              context.read<CreateRoomFormCubit>().toggleReactionsExpanded(),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${context.tr(TranslationKeys.chooseReactions)}  ($count/$maxReactions)',
                    style: context.text.titleSmall,
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(Icons.expand_more_rounded),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The emoji grid, revealed/hidden by [_reactionsHeader].
  Widget _collapsibleReactionsPicker(BuildContext context) {
    return BlocSelector<CreateRoomFormCubit, CreateRoomFormState, bool>(
      selector: (s) => s.reactionsExpanded,
      builder: (context, expanded) => AnimatedCrossFade(
        firstChild: const SizedBox(width: double.infinity),
        secondChild: _reactionsPicker(context),
        crossFadeState:
            expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        duration: const Duration(milliseconds: 200),
        sizeCurve: Curves.easeOutCubic,
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
        child:
            BlocSelector<
              CreateRoomFormCubit,
              CreateRoomFormState,
              List<String>
            >(
              selector: (s) => s.reactions,
              builder: (context, reactions) {
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kReactionEmojis.map((emoji) {
                    final selected = reactions.contains(emoji);
                    return GestureDetector(
                      onTap: () => _toggleReaction(context, emoji),
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
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
      ),
    );
  }

  /// Single-select category chips. Tapping the active chip clears the choice
  /// (category is optional), so the param is sent only when one is picked.
  Widget _categorySelector(BuildContext context) {
    return BlocSelector<CreateRoomFormCubit, CreateRoomFormState, String?>(
      selector: (s) => s.category,
      builder: (context, category) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kCategories.map((c) {
            final selected = category == c;
            return ChoiceChip(
              label: Text(context.tr(categoryLabelKey(c))),
              selected: selected,
              onSelected: (_) =>
                  context.read<CreateRoomFormCubit>().setCategory(c),
            );
          }).toList(),
        );
      },
    );
  }

  void _toggleReaction(BuildContext context, String emoji) {
    final added = context.read<CreateRoomFormCubit>().toggleReaction(emoji);
    if (!added) {
      context.showSnack(context.tr(TranslationKeys.chooseReactions));
    }
  }

  /// Source-type picker as a dropdown (the 4 methods no longer fit a segmented
  /// button comfortably). Each option — and the selected value — shows an icon
  /// and a name.
  Widget _typeSelector(BuildContext context) {
    return BlocSelector<CreateRoomFormCubit, CreateRoomFormState, RoomType>(
      selector: (s) => s.type,
      builder: (context, type) {
        return InputDecorator(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<RoomType>(
              value: type,
              isExpanded: true,
              borderRadius: BorderRadius.circular(12),
              icon: const Icon(Icons.arrow_drop_down_rounded),
              items: [
                _typeItem(context, RoomType.torrent, Icons.stream_rounded,
                    TranslationKeys.typeTorrent),
                _typeItem(context, RoomType.download, Icons.link_rounded,
                    TranslationKeys.typeDownload),
                _typeItem(context, RoomType.youtube, Icons.smart_display_outlined,
                    TranslationKeys.typeYoutube),
                _typeItem(context, RoomType.telegram, Icons.send_rounded,
                    TranslationKeys.typeTelegram),
                _typeItem(context, RoomType.upload, Icons.upload_rounded,
                    TranslationKeys.typeUpload),
              ],
              onChanged: (value) {
                if (value != null) {
                  context.read<CreateRoomFormCubit>().setType(value);
                }
              },
            ),
          ),
        );
      },
    );
  }

  DropdownMenuItem<RoomType> _typeItem(
    BuildContext context,
    RoomType value,
    IconData icon,
    String labelKey,
  ) {
    return DropdownMenuItem<RoomType>(
      value: value,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: context.colors.primary),
          const SizedBox(width: 10),
          Text(context.tr(labelKey)),
        ],
      ),
    );
  }

  Widget _sourceField(BuildContext context) {
    final form = context.read<CreateRoomFormCubit>();
    return BlocSelector<CreateRoomFormCubit, CreateRoomFormState, RoomType>(
      selector: (s) => s.type,
      builder: (context, type) {
        switch (type) {
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
                  controller: form.magnet,
                  minLines: 1,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: context.tr(TranslationKeys.magnetUrl),
                    hintText: context.tr(TranslationKeys.magnetUrlHint),
                    prefixIcon: const Icon(Icons.stream_rounded),
                    suffixIcon: _copyButton(context, form.magnet),
                  ),
                  validator: (v) =>
                      (type == RoomType.torrent &&
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
                  controller: form.externalUrl,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: context.tr(TranslationKeys.externalUrl),
                    hintText: context.tr(TranslationKeys.externalUrlHint),
                    prefixIcon: const Icon(Icons.public_rounded),
                    suffixIcon: _copyButton(context, form.externalUrl),
                  ),
                  validator: (v) =>
                      (type == RoomType.external &&
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
                  controller: form.videoUrl,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: context.tr(TranslationKeys.videoUrl),
                    hintText: context.tr(TranslationKeys.videoUrlHint),
                    prefixIcon: const Icon(Icons.download_rounded),
                    suffixIcon: _copyButton(context, form.videoUrl),
                  ),
                  validator: (v) {
                    if (type != RoomType.download) return null;
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
          case RoomType.youtube:
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(TranslationKeys.typeYoutubeDesc),
                  style: context.text.bodySmall,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: form.youtubeUrl,
                  keyboardType: TextInputType.url,
                  minLines: 1,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: context.tr(TranslationKeys.youtubeLink),
                    hintText: context.tr(TranslationKeys.youtubeLinkHint),
                    prefixIcon: const Icon(Icons.smart_display_outlined),
                    suffixIcon: _copyButton(context, form.youtubeUrl),
                  ),
                  validator: (v) {
                    if (type != RoomType.youtube) return null;
                    final t = v?.trim().toLowerCase() ?? '';
                    final ok = t.startsWith('http') &&
                        (t.contains('youtube.com') || t.contains('youtu.be'));
                    return ok ? null : context.tr(TranslationKeys.youtubeLinkHint);
                  },
                ),
              ],
            );
          case RoomType.telegram:
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr(TranslationKeys.typeTelegramDesc),
                  style: context.text.bodySmall,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: form.telegramUrl,
                  keyboardType: TextInputType.url,
                  minLines: 1,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: context.tr(TranslationKeys.telegramLink),
                    hintText: context.tr(TranslationKeys.telegramLinkHint),
                    prefixIcon: const Icon(Icons.send_rounded),
                    suffixIcon: _copyButton(context, form.telegramUrl),
                  ),
                  validator: (v) {
                    if (type != RoomType.telegram) return null;
                    final t = v?.trim().toLowerCase() ?? '';
                    final ok = t.startsWith('http') &&
                        (t.contains('t.me/') || t.contains('telegram.me/'));
                    return ok ? null : context.tr(TranslationKeys.telegramLinkHint);
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
                BlocSelector<CreateRoomFormCubit, CreateRoomFormState, String?>(
                  selector: (s) => s.videoName,
                  builder: (context, videoName) => OutlinedButton.icon(
                    onPressed: () => _pickVideo(context),
                    icon: const Icon(Icons.video_library_outlined),
                    label: Text(
                      videoName ?? context.tr(TranslationKeys.pickVideo),
                    ),
                  ),
                ),
              ],
            );
        }
      },
    );
  }

  Widget _submitButton(BuildContext context, CreateRoomState state) {
    final type = context.read<CreateRoomFormCubit>().state.type;
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
      if (type == RoomType.torrent) {
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
      onPressed: state.isBusy ? null : () => _submit(context),
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
