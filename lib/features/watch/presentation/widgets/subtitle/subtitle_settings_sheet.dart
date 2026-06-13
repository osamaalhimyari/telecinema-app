import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '../../../domain/entities/subtitle_settings.dart';
import '../../bloc/watch_cubit.dart';
import '../../bloc/watch_state.dart';

/// Bottom sheet for the room's **shared** subtitle settings: a timing offset to
/// fix a subtitle that runs before/after the scene, plus text thickness and
/// size. Changes apply live for everyone — dragging previews locally, releasing
/// broadcasts to the room (mirroring the seek-bar's preview/commit split).
Future<void> showSubtitleSettingsSheet(BuildContext context, WatchCubit cubit) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _SubtitleSettingsSheet(cubit: cubit),
  );
}

/// Range/step constants — kept in sync with the server's clamp in `socket.ts`.
const double _offsetMin = -60;
const double _offsetMax = 60;
const double _offsetStep = 0.1;
const double _weightMin = 100;
const double _weightMax = 900;
const double _sizeMin = 14;
const double _sizeMax = 44;

class _SubtitleSettingsSheet extends StatelessWidget {
  const _SubtitleSettingsSheet({required this.cubit});

  final WatchCubit cubit;

  /// Live preview while dragging (no broadcast); the room sees it on release.
  void _preview(SubtitleSettings next) {
    cubit.setSubtitleSettings(next, broadcast: false);
  }

  void _commit(SubtitleSettings next) {
    cubit.setSubtitleSettings(next, broadcast: true);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WatchCubit>.value(
      value: cubit,
      child: BlocSelector<WatchCubit, WatchState, SubtitleSettings>(
        selector: (s) => s.subtitleSettings,
        builder: (context, s) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tune_rounded, size: 20, color: context.colors.primary),
                      const SizedBox(width: 8),
                      Text(context.tr(TranslationKeys.subtitleSettings), style: context.text.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _preview_(context, s),
                  const SizedBox(height: 20),

                  // ---- Timing ------------------------------------------------------
                  Row(
                    children: [
                      Text(context.tr(TranslationKeys.subtitleTiming), style: context.text.titleSmall),
                      const Spacer(),
                      Text(_timingLabel(context, s.offset), style: context.text.bodyMedium),
                    ],
                  ),
                  Slider(
                    value: s.offset.clamp(_offsetMin, _offsetMax),
                    min: _offsetMin,
                    max: _offsetMax,
                    divisions: ((_offsetMax - _offsetMin) / _offsetStep).round(),
                    onChanged: (v) => _preview(s.copyWith(offset: _round1(v))),
                    onChangeEnd: (v) => _commit(s.copyWith(offset: _round1(v))),
                  ),
                  Row(
                    children: [
                      Text(
                        context.tr(TranslationKeys.subtitleTimingHint),
                        style: context.text.bodySmall?.copyWith(color: context.colors.outline),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: s.offset == 0 ? null : () => _commit(s.copyWith(offset: 0)),
                        icon: const Icon(Icons.restart_alt_rounded, size: 18),
                        label: Text(context.tr(TranslationKeys.reset)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // ---- Thickness ---------------------------------------------------
                  Row(
                    children: [
                      Text(context.tr(TranslationKeys.subtitleThickness), style: context.text.titleSmall),
                      const Spacer(),
                      Text('${s.weight}', style: context.text.bodyMedium),
                    ],
                  ),
                  Slider(
                    value: s.weight.toDouble().clamp(_weightMin, _weightMax),
                    min: _weightMin,
                    max: _weightMax,
                    divisions: ((_weightMax - _weightMin) / 100).round(),
                    onChanged: (v) => _preview(s.copyWith(weight: v.round())),
                    onChangeEnd: (v) => _commit(s.copyWith(weight: v.round())),
                  ),
                  const SizedBox(height: 8),

                  // ---- Size --------------------------------------------------------
                  Row(
                    children: [
                      Text(context.tr(TranslationKeys.subtitleSize), style: context.text.titleSmall),
                      const Spacer(),
                      Text('${s.size}', style: context.text.bodyMedium),
                    ],
                  ),
                  Slider(
                    value: s.size.toDouble().clamp(_sizeMin, _sizeMax),
                    min: _sizeMin,
                    max: _sizeMax,
                    divisions: (_sizeMax - _sizeMin).round(),
                    onChanged: (v) => _preview(s.copyWith(size: v.round())),
                    onChangeEnd: (v) => _commit(s.copyWith(size: v.round())),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// A small, live preview of how the subtitle now looks (weight + size).
  Widget _preview_(BuildContext context, SubtitleSettings s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'AaBb — أبجد',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: s.size.toDouble(),
          fontWeight: s.fontWeight,
          height: 1.3,
        ),
      ),
    );
  }

  static double _round1(double v) => (v * 10).round() / 10;

  String _timingLabel(BuildContext context, double offset) {
    if (offset.abs() < 0.05) return context.tr(TranslationKeys.subtitleInSync);
    final secs = offset.abs().toStringAsFixed(1);
    final dir = offset > 0
        ? context.tr(TranslationKeys.subtitleLater)
        : context.tr(TranslationKeys.subtitleEarlier);
    final sign = offset > 0 ? '+' : '−';
    return '$sign$secs s · $dir';
  }
}
