# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Flutter app `train_cosy` (pubspec name) — a visual base for a narrative game rendering a cosy train wagon interior with toggleable, gently animated objects. Only the `ios/` platform folder is committed; `android/`, `macos/`, and `web/` are intentionally absent (`web/` is gitignored).

## Common commands

```bash
flutter pub get                 # fetch deps (pubspec.lock is gitignored)
flutter run                     # run on the selected device (iOS by default here)
flutter analyze                 # static analysis with the rules in analysis_options.yaml
flutter test                    # there is no test/ directory yet; add one before relying on this
dart format lib tools           # match repo formatting before committing

python tools/generate_placeholders.py    # regenerate placeholder PNGs in assets/
```

`tools/generate_placeholders.py` requires Pillow (`pip install pillow`). It writes to `assets/background/wagon.png` and `assets/objects/{bed,lamp,plant,plaid}.png`; replace those files with real art without touching code.

## Lint configuration

`analysis_options.yaml` extends `package:flutter_lints/flutter.yaml` and additionally enables `strict-casts`, `strict-inference`, `prefer_const_constructors`, `prefer_const_literals_to_create_immutables`, and `avoid_print`. Treat `flutter analyze` warnings as build failures.

## Architecture

The scene is **data-driven** by `assets/config/scene.json` — code never hard-codes object positions or which objects exist.

- `assets/config/scene.json` declares:
  - `background`: asset path for the wagon image.
  - `aspectRatio`: `[w, h]` pair, used to lock the view's box so normalized coordinates remain stable across devices (default 2:3 portrait).
  - `slots[]`: named anchors with `(x, y, width, height)` **normalized to 0..1** of the wagon box. `(x, y)` is the slot center.
  - `objects[]`: each references a `slot` id and an `asset`, plus an `animation` (`none` | `breathing` | `flickering` | `swaying`).

- `lib/models/scene_config.dart` parses and validates `scene.json`. `SceneConfig.fromJson` throws `FormatException` if an object references an unknown slot, and `_parseAnimation` throws on unknown animation names — keep that strictness when extending the schema.

- `lib/services/scene_state.dart` (`SceneState extends ChangeNotifier`) is the single source of truth for which object ids are currently visible. There is no third-party state management; widgets subscribe via `AnimatedBuilder(animation: state, …)`.

- `lib/widgets/wagon_view.dart` wraps the wagon in `AspectRatio(config.aspectRatio)` and a `LayoutBuilder`, then converts normalized slot coords to pixels: `left = slot.x*w - width/2`, `top = slot.y*h - height/2`. New rendering logic should preserve this center-anchored convention so `scene.json` stays portable.

- `lib/widgets/animated_object.dart` applies a purely decorative loop per `WagonAnimation`. The controller is rebuilt in `didUpdateWidget` when the animation kind changes; preserve that pattern if adding new animation types so a hot-reload swap doesn't leak controllers.

- `lib/widgets/debug_menu.dart` is the runtime composition tool — a bottom sheet with one checkbox per object. It exists so the scene can be exercised before any real game logic is wired up; expect it to be replaced by game systems later, not promoted to user-facing UI.

- `lib/main.dart` loads `SceneConfig` once via `FutureBuilder`, then constructs a single `SceneState` lazily on first build and disposes it on screen teardown.

## Extending the scene

To add a new object: declare a slot (if needed) and an object entry in `scene.json`, drop the PNG into `assets/objects/`, and (if it's a new file path pattern) update `pubspec.yaml`'s `flutter.assets`. No Dart change is required for the common case.

To add a new animation kind: extend the `WagonAnimation` enum, the `_parseAnimation` switch in `scene_config.dart`, the controller-duration `switch` in `animated_object.dart`, and the render `switch` in its `AnimatedBuilder`. All four switches are exhaustive on the enum — the analyzer will flag a missing arm.
