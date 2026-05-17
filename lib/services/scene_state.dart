import 'package:flutter/foundation.dart';

import '../models/scene_config.dart';

/// Tracks which objects are currently visible in the wagon.
///
/// All objects start hidden. The debug menu (or future game logic) toggles
/// them on and off; listeners rebuild whenever the visibility set changes.
class SceneState extends ChangeNotifier {
  SceneState(this.config);

  final SceneConfig config;
  final Set<String> _visible = <String>{};

  bool isVisible(String objectId) => _visible.contains(objectId);

  void setVisible(String objectId, bool visible) {
    final changed = visible ? _visible.add(objectId) : _visible.remove(objectId);
    if (changed) notifyListeners();
  }

  void toggle(String objectId) => setVisible(objectId, !isVisible(objectId));

  void hideAll() {
    if (_visible.isEmpty) return;
    _visible.clear();
    notifyListeners();
  }
}
