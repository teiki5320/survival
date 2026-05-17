import 'package:flutter/material.dart';

import '../models/scene_config.dart';
import '../services/scene_state.dart';

/// A bottom sheet with one checkbox per object so the scene can be composed
/// at runtime without a game system behind it.
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
                child: Row(
                  children: [
                    const Text(
                      'Debug — objets',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: state.hideAll,
                      icon: const Icon(Icons.visibility_off_outlined),
                      label: const Text('Tout masquer'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: config.objects.length,
                  itemBuilder: (context, index) {
                    final object = config.objects[index];
                    final visible = state.isVisible(object.id);
                    return CheckboxListTile(
                      value: visible,
                      onChanged: (v) => state.setVisible(object.id, v ?? false),
                      title: Text(object.label),
                      subtitle: Text(
                        '${object.id} • slot ${object.slotId} • ${object.animation.name}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
