import 'package:flutter/material.dart';

import '../models/scene_config.dart';
import '../services/scene_state.dart';
import 'animated_object.dart';

/// Renders the wagon background and all currently visible objects on top.
///
/// Layout strategy: the view fixes its own aspect ratio to the configured
/// wagon ratio (default 2:3 portrait) so positions stay correct on any
/// device. Slot coordinates are normalized (0..1) and converted to pixels
/// against the wagon's box at build time.
class WagonView extends StatelessWidget {
  const WagonView({
    super.key,
    required this.config,
    required this.state,
  });

  final SceneConfig config;
  final SceneState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: AspectRatio(
        aspectRatio: config.aspectRatio,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    config.background,
                    fit: BoxFit.cover,
                  ),
                ),
                AnimatedBuilder(
                  animation: state,
                  builder: (context, _) {
                    return Stack(
                      children: [
                        for (final object in config.objects)
                          if (state.isVisible(object.id))
                            _positionedObject(object, w, h),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _positionedObject(WagonObject object, double w, double h) {
    final slot = config.slotFor(object);
    final width = slot.width * w;
    final height = slot.height * h;
    final left = slot.x * w - width / 2;
    final top = slot.y * h - height / 2;
    return Positioned(
      key: ValueKey('obj_${object.id}'),
      left: left,
      top: top,
      width: width,
      height: height,
      child: AnimatedObject(
        animation: object.animation,
        child: Image.asset(
          object.asset,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
