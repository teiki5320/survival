import 'package:flutter/material.dart';

import '../models/scene_config.dart';
import '../services/scene_state.dart';
import 'animated_object.dart';

/// Renders the wagon background, all visible objects, and any visible
/// characters at their current pose position.
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
            return AnimatedBuilder(
              animation: state,
              builder: (context, _) {
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 600),
                        child: Image.asset(
                          config.backgroundFor(state.time),
                          key: ValueKey(state.time),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    for (final object in config.objects)
                      if (state.isVisible(object.id))
                        _positionedObject(object, w, h),
                    for (final char in config.characters)
                      if (state.isCharacterVisible(char.id))
                        _positionedCharacter(char, w, h),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _positionedObject(WagonObject object, double w, double h) {
    final slot = config.slotFor(object);
    return _slotPositioned(
      slot,
      w,
      h,
      key: ValueKey('obj_${object.id}'),
      child: AnimatedObject(
        animation: object.animation,
        child: Image.asset(object.asset, fit: BoxFit.contain),
      ),
    );
  }

  Widget _positionedCharacter(CharacterConfig char, double w, double h) {
    final pose = state.currentPose(char);
    final slot = config.slotForPose(pose);
    // AnimatedSwitcher with a fade keyed on pose id gives a soft cross-fade
    // when the pose changes (auto-cycle or manual pick).
    return _slotPositioned(
      slot,
      w,
      h,
      key: ValueKey('char_${char.id}_slot_${slot.id}'),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: Image.asset(
          pose.asset,
          key: ValueKey('char_${char.id}_pose_${pose.id}'),
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _slotPositioned(
    SlotConfig slot,
    double w,
    double h, {
    required Key key,
    required Widget child,
  }) {
    final width = slot.width * w;
    final height = slot.height * h;
    final left = slot.x * w - width / 2;
    final top = slot.y * h - height / 2;
    return Positioned(
      key: key,
      left: left,
      top: top,
      width: width,
      height: height,
      child: child,
    );
  }
}
