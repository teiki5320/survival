import 'package:flutter/foundation.dart';

import '../models/scene_config.dart';

/// Tracks which objects are currently visible in the wagon and which
/// background variant (day or night) is rendered.
///
/// All objects start hidden. The debug menu (or future game logic) toggles
/// them on and off; listeners rebuild whenever the visibility set or
/// time of day changes.
class SceneState extends ChangeNotifier {
  SceneState(this.config) : _time = config.defaultTime;

  final SceneConfig config;
  final Set<String> _visible = <String>{};
  WagonTime _time;

  WagonTime get time => _time;
  bool get isNight => _time == WagonTime.night;

  bool isVisible(String objectId) => _visible.contains(objectId);

  void setVisible(String objectId, bool visible) {
    final changed = visible ? _visible.add(objectId) : _visible.remove(objectId);
    if (changed) notifyListeners();
  }

  void toggle(String objectId) => setVisible(objectId, !isVisible(objectId));

  void setTime(WagonTime time) {
    if (_time == time) return;
    _time = time;
    notifyListeners();
  }

  void toggleTime() =>
      setTime(_time == WagonTime.day ? WagonTime.night : WagonTime.day);

  void hideAll() {
    if (_visible.isEmpty) return;
    _visible.clear();
    notifyListeners();
  }
}
