import 'package:flutter/material.dart';

import '../models/scene_config.dart';
import '../services/scene_state.dart';

/// A bottom sheet to drive the scene at runtime: day/night, characters with
/// pose overrides, and one checkbox per decorative object.
class DebugObjectsSheet extends StatelessWidget {
  const DebugObjectsSheet({
    super.key,
    required this.config,
    required this.state,
  });

  final SceneConfig config;
  final SceneState state;

  static Future<void> show(
    BuildContext context, {
    required SceneConfig config,
    required SceneState state,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DebugObjectsSheet(config: config, state: state),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _headerRow(),
              const Divider(height: 1),
              _ambianceRow(),
              _rockingRow(),
              _parallaxRow(),
              const Divider(height: 1),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (config.characters.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          'Personnages',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      for (final char in config.characters)
                        _CharacterTile(char: char, state: state),
                      const Divider(height: 24),
                    ],
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
                      child: Text(
                        'Objets',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    for (final object in config.objects)
                      CheckboxListTile(
                        value: state.isVisible(object.id),
                        onChanged: (v) =>
                            state.setVisible(object.id, v ?? false),
                        title: Text(object.label),
                        subtitle: Text(
                          '${object.id} • slot ${object.slotId} • '
                          '${object.animation.name}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _headerRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
      child: Row(
        children: [
          const Text(
            'Debug',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: state.hideAll,
            icon: const Icon(Icons.visibility_off_outlined),
            label: const Text('Tout masquer'),
          ),
        ],
      ),
    );
  }

  Widget _rockingRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.train_outlined, size: 18),
          const SizedBox(width: 8),
          const Text('Roulis du train',
              style: TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Switch(
            value: state.isRocking,
            onChanged: state.setRocking,
          ),
        ],
      ),
    );
  }

  Widget _parallaxRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.landscape_outlined, size: 18),
          const SizedBox(width: 8),
          const Text('Paysage qui défile',
              style: TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Switch(
            value: state.isParallax,
            onChanged: state.setParallax,
          ),
        ],
      ),
    );
  }

  Widget _ambianceRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          const Text('Ambiance', style: TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          SegmentedButton<WagonTime>(
            segments: const [
              ButtonSegment(
                value: WagonTime.day,
                label: Text('Jour'),
                icon: Icon(Icons.wb_sunny_outlined),
              ),
              ButtonSegment(
                value: WagonTime.night,
                label: Text('Nuit'),
                icon: Icon(Icons.nightlight_outlined),
              ),
            ],
            selected: {state.time},
            onSelectionChanged: (s) => state.setTime(s.first),
          ),
        ],
      ),
    );
  }
}

class _CharacterTile extends StatelessWidget {
  const _CharacterTile({required this.char, required this.state});

  final CharacterConfig char;
  final SceneState state;

  @override
  Widget build(BuildContext context) {
    final visible = state.isCharacterVisible(char.id);
    final manualPinned = state.isPoseManuallyPinned(char.id);
    final currentIndex = state.currentPoseIndex(char.id);
    final playing = state.isActionPlaying(char.id);
    final activeAction = state.activeAction(char.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          value: visible,
          onChanged: (v) => state.setCharacterVisible(char.id, v),
          title: Text(char.label),
          subtitle: Text(
            '${char.poses.length} poses • ${char.actions.length} actions • '
            'cycle ${char.cycleSeconds}s',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        if (visible) ...[
          if (char.actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Actions',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      if (playing) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'En cours : ${activeAction?.label ?? ''}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => state.stopAction(char.id),
                          icon: const Icon(Icons.stop_circle_outlined, size: 16),
                          label: const Text('Stop'),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final action in char.actions)
                        ActionChip(
                          label: Text(action.label),
                          avatar: const Icon(Icons.play_arrow, size: 16),
                          onPressed: () => state.playAction(char.id, action.id),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Poses',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    FilterChip(
                      label: const Text('Auto'),
                      avatar: const Icon(Icons.refresh, size: 16),
                      selected: !manualPinned && !playing,
                      onSelected: (_) => state.setManualPose(char.id, null),
                    ),
                    for (var i = 0; i < char.poses.length; i++)
                      FilterChip(
                        label: Text(char.poses[i].label),
                        selected: manualPinned && currentIndex == i,
                        onSelected: (_) => state.setManualPose(char.id, i),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
