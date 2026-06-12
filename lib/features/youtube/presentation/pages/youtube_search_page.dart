import 'dart:async';

import 'package:flutter/material.dart';

import '/core/errors/exceptions.dart';
import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/injections/injection.dart';
import '../../data/datasources/youtube_remote_datasource.dart';
import '../../domain/entities/youtube_video.dart';
import '../widgets/youtube_picker_sheet.dart';

/// The YouTube search tab: search on-device, preview a result, then create a
/// synchronized room the server downloads (yt-dlp). An isolated feature — it
/// drives the data source directly and reuses the create-room route, touching
/// no other feature's code.
class YoutubeSearchPage extends StatefulWidget {
  const YoutubeSearchPage({super.key});

  @override
  State<YoutubeSearchPage> createState() => _YoutubeSearchPageState();
}

class _YoutubeSearchPageState extends State<YoutubeSearchPage> {
  final _search = TextEditingController();
  final _datasource = sl<YoutubeRemoteDataSource>();

  Timer? _debounce;
  bool _loading = false;
  String? _errorKey;
  List<YoutubeVideo> _results = const [];

  /// Guards against out-of-order responses: only the latest query's result is
  /// applied (a slow earlier search can't overwrite a newer one).
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => _run(value.trim()));
  }

  Future<void> _run(String query) async {
    if (query.isEmpty) {
      setState(() {
        _results = const [];
        _loading = false;
        _errorKey = null;
      });
      return;
    }
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _errorKey = null;
    });
    try {
      final results = await _datasource.search(query);
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = results;
        _loading = false;
        _errorKey = results.isEmpty ? TranslationKeys.youtubeNoResults : null;
      });
    } on ServerException catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loading = false;
        _errorKey = e.message;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loading = false;
        _errorKey = TranslationKeys.youtubeUnavailable;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr(TranslationKeys.youtubeTab))),
      body: Column(
        children: [
          _searchField(context),
          Expanded(child: _body(context)),
        ],
      ),
    );
  }

  Widget _searchField(BuildContext context) {
    final hasText = _search.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _search,
        textInputAction: TextInputAction.search,
        autofocus: false,
        onChanged: (v) {
          setState(() {}); // refresh the clear button
          _onChanged(v);
        },
        onSubmitted: (v) => _run(v.trim()),
        decoration: InputDecoration(
          isDense: true,
          hintText: context.tr(TranslationKeys.youtubeSearchHint),
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: hasText
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _debounce?.cancel();
                    _search.clear();
                    setState(() {
                      _results = const [];
                      _errorKey = null;
                      _loading = false;
                    });
                  },
                )
              : null,
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorKey != null) {
      return _centered(context, context.tr(_errorKey!));
    }
    if (_results.isEmpty) {
      return _centered(context, context.tr(TranslationKeys.youtubeSearchPrompt));
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      itemCount: _results.length,
      itemBuilder: (context, i) => _videoTile(context, _results[i]),
    );
  }

  Widget _centered(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
      ),
    ),
  );

  Widget _videoTile(BuildContext context, YoutubeVideo video) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => startYoutubeRoomFlow(context, video, _datasource),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _thumbnail(context, video),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      video.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _thumbnail(BuildContext context, YoutubeVideo video) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          Image.network(
            video.thumbnailUrl,
            width: 120,
            height: 68,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              width: 120,
              height: 68,
              color: context.colors.surfaceContainerHighest,
              child: Icon(Icons.play_circle_outline_rounded, color: context.colors.onSurfaceVariant),
            ),
          ),
          if (video.durationLabel.isNotEmpty)
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  video.durationLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
