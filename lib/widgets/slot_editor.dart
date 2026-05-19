import 'package:flutter/material.dart';

import '../models/scene_config.dart';
import '../services/scene_state.dart';

/// Universal slot editor — pick any slot from the chip row, then drag the
/// 4 corners to fit. A small handle in the middle of the rectangle lets
/// you move the whole slot without resizing. The live JSON for the slot
/// is shown at the top; copy it into scene.json once the fit looks right.
class SlotEditor extends StatelessWidget {
  const SlotEditor({
    super.key,
    required this.state,
    required this.config,
    required this.boxWidth,
    required this.boxHeight,
  });

  final SceneState state;
  final SceneConfig config;
  final double boxWidth;
  final double boxHeight;

  static const double _handleRadius = 22;
  static const Color _color = Color(0xFFFFD400);

  @override
  Widget build(BuildContext context) {
    final selectedId = state.editingSlotId;
    final rect =
        selectedId != null ? state.getEffectiveSlotRect(selectedId) : null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (selectedId != null && rect != null) ..._editorOverlay(selectedId, rect),
        _topBar(selectedId, rect),
        _bottomBar(),
      ],
    );
  }

  List<Widget> _editorOverlay(String slotId, Rect rect) {
    final left = rect.left * boxWidth;
    final top = rect.top * boxHeight;
    final width = rect.width * boxWidth;
    final height = rect.height * boxHeight;
    return [
      // Outline
      Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: _color, width: 2),
            ),
          ),
        ),
      ),
      // Center move-handle (drag without resize)
      Positioned(
        left: left + width / 2 - _handleRadius,
        top: top + height / 2 - _handleRadius,
        width: _handleRadius * 2,
        height: _handleRadius * 2,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) {
            state.translateSlot(
              slotId,
              details.delta.dx / boxWidth,
              details.delta.dy / boxHeight,
            );
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _color.withOpacity(0.15),
              border: Border.all(color: _color, width: 2),
            ),
            child: const Icon(Icons.open_with, color: _color, size: 20),
          ),
        ),
      ),
      _corner(slotId, WindowCorner.topLeft, left, top),
      _corner(slotId, WindowCorner.topRight, left + width, top),
      _corner(slotId, WindowCorner.bottomLeft, left, top + height),
      _corner(slotId, WindowCorner.bottomRight, left + width, top + height),
    ];
  }

  Widget _corner(String slotId, WindowCorner corner, double cx, double cy) {
    return Positioned(
      left: cx - _handleRadius,
      top: cy - _handleRadius,
      width: _handleRadius * 2,
      height: _handleRadius * 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          state.dragSlotCorner(
            slotId,
            corner,
            details.delta.dx / boxWidth,
            details.delta.dy / boxHeight,
          );
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _color.withOpacity(0.35),
            border: Border.all(color: _color, width: 3),
          ),
        ),
      ),
    );
  }

  Widget _topBar(String? selectedId, Rect? rect) {
    final ids = config.slots.keys.toList();
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          color: Colors.black.withOpacity(0.55),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (selectedId != null && rect != null) _readout(selectedId, rect),
              const SizedBox(height: 6),
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: ids.length,
                  itemBuilder: (context, i) {
                    final id = ids[i];
                    final isSelected = id == selectedId;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: FilterChip(
                        label: Text(id, style: const TextStyle(fontSize: 11)),
                        selected: isSelected,
                        onSelected: (_) => state.setEditingSlot(id),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _readout(String slotId, Rect rect) {
    final cx = (rect.left + rect.right) / 2;
    final cy = (rect.top + rect.bottom) / 2;
    final w = rect.width;
    final h = rect.height;
    final text = '"$slotId": { '
        '"x": ${cx.toStringAsFixed(3)}, '
        '"y": ${cy.toStringAsFixed(3)}, '
        '"width": ${w.toStringAsFixed(3)}, '
        '"height": ${h.toStringAsFixed(3)} '
        '}';
    return SelectableText(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontFamily: 'monospace',
      ),
    );
  }

  Widget _bottomBar() {
    return Positioned(
      bottom: 16,
      left: 16,
      child: SafeArea(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.tonal(
              onPressed: () {
                if (state.editingSlotId != null) {
                  state.resetSlot(state.editingSlotId!);
                }
              },
              child: const Text('Reset'),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: state.resetAllSlotOverrides,
              child: const Text('Reset tout'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () => state.setSlotEditorActive(false),
              child: const Text('Fermer l\'éditeur'),
            ),
          ],
        ),
      ),
    );
  }
}
