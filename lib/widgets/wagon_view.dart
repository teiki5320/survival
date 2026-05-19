import 'package:flutter/material.dart';

import '../models/scene_config.dart';
import '../services/scene_state.dart';
import 'animated_object.dart';
import 'character_display.dart';
import 'cracked_glass.dart';
import 'dust_particles.dart';
import 'scrolling_landscape.dart';
import 'slot_editor.dart';
import 'train_rocking.dart';
import 'window_corner_editor.dart';
import 'window_rain.dart';

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
            return ClipRect(
              child: AnimatedBuilder(
                animation: state,
                builder: (context, _) {
                  return TrainRocking(
                    enabled: state.isRocking,
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        // 1. Wagon background — kept intact (no cut). The
                        //    original window content is hidden by the
                        //    landscape overlay below at the windowArea.
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
                        // 2. Scrolling landscape, positioned precisely
                        //    inside the wagon's window rectangle. Sitting
                        //    on top of the wagon means we never bleed onto
                        //    the wagon's frame — adjusting fit is just a
                        //    matter of tuning windowArea in scene.json,
                        //    no cut script to re-run.
                        if (config.landscapeFor(state.time) != null)
                          _landscapeInWindow(state, w, h),
                        for (final object in config.objects)
                          if (state.isVisible(object.id))
                            _positionedObject(object, w, h),
                        for (final char in config.characters)
                          if (state.isCharacterVisible(char.id))
                            _positionedCharacter(char, w, h),
                        // Atmosphere: dust motes drifting on top of
                        // everything except UI editors.
                        if (state.isDustEnabled)
                          Positioned.fill(
                            child: DustParticles(enabled: state.isDustEnabled),
                          ),
                        if (state.isEditingWindow)
                          Positioned.fill(
                            child: WindowCornerEditor(
                              state: state,
                              boxWidth: w,
                              boxHeight: h,
                            ),
                          ),
                        if (state.isSlotEditorActive)
                          Positioned.fill(
                            child: SlotEditor(
                              state: state,
                              config: config,
                              boxWidth: w,
                              boxHeight: h,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _landscapeInWindow(SceneState state, double w, double h) {
    final rect = state.effectiveWindowArea;
    final radiusPx = config.windowCornerRadius * (w < h ? w : h);
    final radius = BorderRadius.circular(radiusPx);
    final crack = state.windowCrack;
    return Positioned(
      left: rect.left * w,
      top: rect.top * h,
      width: rect.width * w,
      height: rect.height * h,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: ScrollingLandscape(
                key: ValueKey('land_${state.time}'),
                assetPath: config.landscapeFor(state.time)!,
                enabled: state.isParallax,
              ),
            ),
            if (state.isRainEnabled) WindowRain(enabled: state.isRainEnabled),
            if (crack != null) CrackedGlass(state: crack),
          ],
        ),
      ),
    );
  }

  Widget _positionedObject(WagonObject object, double w, double h) {
    final slot = state.getEffectiveSlotConfig(object.slotId);
    final image = Image.asset(object.asset, fit: BoxFit.contain);
    final animated = AnimatedObject(
      animation: object.animation,
      child: image,
    );
    final child = object.interaction == null
        ? animated
        : GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => state.interactWith(object),
            child: animated,
          );
    return _slotPositioned(
      slot,
      w,
      h,
      key: ValueKey('obj_${object.id}'),
      child: child,
    );
  }

  Widget _positionedCharacter(CharacterConfig char, double w, double h) {
    return Positioned.fill(
      key: ValueKey('char_${char.id}'),
      child: CharacterDisplay(
        character: char,
        currentPose: state.currentPose(char),
        resolveSlot: (pose) => state.getEffectiveSlotConfig(pose.slotId),
        boxWidth: w,
        boxHeight: h,
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
