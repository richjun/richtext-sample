# richtext

Flutter sample exploring a canvas-based rich text editor: movable, resizable text boxes
that each host a [`flutter_quill`](https://pub.dev/packages/flutter_quill) document, with
a shared toolbar, an inspection panel, and a Lab `TextObject` serialization format.

Targets **Web** and **Windows**.

## Features

- Canvas with text boxes you can drag, resize, and rotate (3-point transform handles
  drawn at canvas level so they straddle the box edges without disturbing the editor's
  hit bounds).
- Rich text per box: bold/italic/underline, headings, font family + size, color, lists
  (ordered/unordered with nested indent), alignment, indent/outdent.
- Toolbar reflects the active formatting state at the caret and keeps the editor
  focused when buttons are tapped (desktop-friendly).
- Bullet markers follow the line's text alignment (left/center/right) — requires the
  vendored `flutter_quill` patch (see below).
- Indent / outdent via toolbar or `Tab` / `Shift+Tab`; `Enter` on an empty nested list
  item outdents one level.
- Save/restore document state to `temp.json` (web: `localStorage`; desktop: app
  support dir).
- Inspection panel + JS bridge (`window.__inspector`) for coordinate-based Playwright
  targeting in tests.
- Localization scaffolding for English and Korean.

## Vendored dependencies

Both overrides live under `third_party/` and are pinned via `dependency_overrides`
in `pubspec.yaml`:

- **`quill_native_bridge_windows`** — the published `0.0.2` references the bare
  `GMEM_MOVEABLE` constant, which `win32 >= 5.5` only exposes via
  `GLOBAL_ALLOC_FLAGS`. The Windows build fails to compile without the patch
  (flutter-quill issue #2612).
- **`flutter_quill-10.8.5`** — upstream renders the unordered-list bullet in a fixed
  leading slot pinned to the line's left edge, so center/right-aligning a bullet line
  moves the text but leaves the `•` far left. The patch lets the marker follow the
  line's alignment. See
  `third_party/flutter_quill-10.8.5/lib/src/editor/widgets/text/text_line.dart`
  (search "bullet marker follows alignment").

## Getting started

```bash
flutter pub get

# Web (Chrome)
flutter run -d chrome

# Windows desktop
flutter config --enable-windows-desktop
flutter run -d windows
```

## Build

```bash
# Web release
flutter build web --release

# Windows release + Inno Setup installer (run on Windows)
scripts\windows\build_installer.bat
```

Pushes to `master` trigger the GitHub Actions `Windows Build` workflow, which
publishes the installer as a build artifact.

## Tests

Dart unit/widget tests:

```bash
flutter test
```

End-to-end web verifier (builds release, serves it, runs Playwright specs):

```bash
scripts/verify.sh
```

## Layout

```
lib/
  canvas_page.dart        Canvas + toolbar + inspection panel layout
  text_box.dart           Per-box Quill editor wrapper
  transform_handles.dart  Move/resize/rotate handles
  rich_toolbar.dart       Toolbar (active-state aware)
  state.dart              AppState (boxes, selection, doc ops)
  serialize.dart          Lab TextObject emit
  deserialize.dart        Lab TextObject parse
  extract.dart            Flatten Quill delta to runs
  list_outdent_rule.dart  Enter-in-empty-nested-list outdent rule
  temp_store*.dart        Save/restore (web + io)
  inspection_panel.dart   Right-hand debug panel
  js_inspector*.dart      window.__inspector bridge (Playwright targeting)
third_party/              Vendored patched dependencies
scripts/                  verify.sh + Windows installer build
```
