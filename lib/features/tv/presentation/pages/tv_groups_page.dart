import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '/core/extensions/context_extensions.dart';
import '/core/localization/translation_keys.dart';
import '/core/shared/status_view.dart';
import '/injections/injection.dart';
import '../../domain/entities/tv_node.dart';
import '../bloc/tv_groups/tv_groups_cubit.dart';
import '../bloc/tv_groups/tv_groups_state.dart';
import 'tv_channels_page.dart';

/// The Live TV tab: a grid of channel groups (beIN, Arabic, Kids, …). Tapping a
/// group opens its channel list ([TvChannelsPage]). Fully isolated — fetches the
/// catalogue from the provider and plays on-device; touches no other feature.
class TvGroupsPage extends StatelessWidget {
  const TvGroupsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TvGroupsCubit>(
      create: (_) => sl<TvGroupsCubit>()..load(),
      child: const _TvGroupsView(),
    );
  }
}

class _TvGroupsView extends StatelessWidget {
  const _TvGroupsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(TranslationKeys.tvTitle)),
        actions: [
          IconButton(
            tooltip: context.tr(TranslationKeys.retry),
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => context.read<TvGroupsCubit>().refresh(),
          ),
        ],
      ),
      body: BlocBuilder<TvGroupsCubit, TvGroupsState>(
        builder: (context, state) {
          return switch (state.status) {
            TvGroupsStatus.initial || TvGroupsStatus.loading =>
              const Center(child: CircularProgressIndicator()),
            TvGroupsStatus.failure => StatusView(
              icon: Icons.cloud_off_rounded,
              title: context.tr(TranslationKeys.errorUnknown),
              message: context.tr(state.errorKey ?? TranslationKeys.errorUnknown),
              actionLabel: context.tr(TranslationKeys.retry),
              onAction: () => context.read<TvGroupsCubit>().load(),
            ),
            TvGroupsStatus.success => _grid(context, state),
          };
        },
      ),
    );
  }

  Widget _grid(BuildContext context, TvGroupsState state) {
    if (state.groups.isEmpty) {
      return StatusView(
        icon: Icons.live_tv_outlined,
        title: context.tr(TranslationKeys.tvEmpty),
      );
    }
    return RefreshIndicator(
      onRefresh: () => context.read<TvGroupsCubit>().refresh(),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          childAspectRatio: 1.35,
        ),
        itemCount: state.groups.length,
        itemBuilder: (_, i) => _GroupCard(group: state.groups[i]),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final TvNode group;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(builder: (_) => TvChannelsPage(node: group)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(_iconFor(group.name), size: 34, color: context.colors.primary),
              const Spacer(),
              Text(
                group.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                '${group.channelCount} ${context.tr(TranslationKeys.tvChannels)}',
                style: context.text.bodySmall?.copyWith(color: context.colors.outline),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A flavour icon picked from the group name (purely cosmetic).
  IconData _iconFor(String name) {
    final n = name.toUpperCase();
    if (n.contains('SPORT')) return Icons.sports_soccer_rounded;
    if (n.contains('KIDS')) return Icons.child_care_rounded;
    if (n.contains('NEWS')) return Icons.newspaper_rounded;
    if (n.contains('EVENT')) return Icons.stadium_rounded;
    if (n.contains('MAX') || n.contains('ENTERTAIN') ||
        n.contains('MBC') || n.contains('SHAHID') || n.contains('WEYYAK')) {
      return Icons.movie_rounded;
    }
    return Icons.live_tv_rounded;
  }
}
