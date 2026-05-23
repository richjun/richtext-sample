# Save / Restore via temp.json — Design

**Date:** 2026-05-23
**Status:** Approved

## Goal

Add **저장(Save)** and **복원(Restore)** buttons. Save writes the current panel
JSON to a platform-appropriate `temp.json`. Restore reads it back and restores
the editor state faithfully.

## Decision: round-trip format

Save the **existing panel JSON (Lab format)** verbatim — `serializeAppState()`
output. Restore reconstructs the Quill document from `paragraphs[]` plus box
geometry. `temp.json` is therefore byte-identical to what the inspection panel
shows. (Chosen over a Quill-native Delta file so the saved artifact equals the
panel JSON; this also demonstrates that the panel values alone — without the
removed `selection` field — suffice to restore the document.)

## Components

| File | Role |
|------|------|
| `lib/deserialize.dart` (new) | `applyAppState(AppState, Map json)` — Lab JSON → Quill document + box geometry. Inverse of `serialize.dart`. |
| `lib/temp_store.dart` (new) | Platform-split interface: `Future<String> saveTemp(json)`, `Future<String?> loadTemp()`. Conditional import like `js_inspector.dart`. |
| `lib/temp_store_io.dart` (new) | Desktop/mobile: `dart:io`, `${Directory.systemTemp.path}/temp.json` (Windows = `%TEMP%\temp.json`). No new dependency. |
| `lib/temp_store_web.dart` (new) | Web: `package:web` `localStorage['temp.json']` (no filesystem path on web). |
| `lib/inspection_panel.dart` (edit) | Save / Restore buttons above the JSON; SnackBar feedback. |

Conditional import (default = io, web overrides):
```dart
import 'temp_store_io.dart'
    if (dart.library.js_interop) 'temp_store_web.dart' as impl;
```

## Data flow

- **Save:** `serializeAppState(state)` → `saveTemp(json)` → SnackBar (desktop shows path).
- **Restore:** `loadTemp()` → `jsonDecode` → `applyAppState(state, json)`:
  - `offset`/`size`/`transform.rotation` → `boxes.first` x/y/w/h/rotationDeg (via `mutateBox`).
  - `paragraphs[]` → build Quill `Delta` → `Document.fromDelta` → `controller.document = doc`.

## Lab → Quill attribute mapping (deserialize)

Inline (run.style), emitted only when non-default; mirror the values the toolbar
produces so rendering is identical:

| Lab | Quill attr |
|-----|-----------|
| `bold:true` | `bold` |
| `italic:true` | `italic` |
| `underline:'sng'` | `underline` |
| `strikethrough:'single'` | `strike` |
| `color:'0xFFRRGGBB'` (≠ black) | `color:'#RRGGBB'` |
| `highlight:'0xFFRRGGBB'` | `background:'#RRGGBB'` |
| `font` (≠ 'Roboto') | `font` |
| `size` (≠ 14) | `size` |
| `baseline:30 / -25` | `script:'super' / 'sub'` |

Block (paragraph), attached to the line-ending `\n`:

| Lab | Quill attr |
|-----|-----------|
| `align` (≠ 'left') | `align` |
| `level` (> 0) | `indent` |
| `bullet != null` | `list:'bullet'` |

Empty run (`text:''`): skip the insert, still emit `\n` → preserves the blank line.

## Error handling

- `loadTemp() == null` → SnackBar "저장된 상태가 없습니다".
- JSON parse / apply failure → catch → SnackBar "복원 실패: …".
- Save success → SnackBar "저장됨: <path>".

## Testing

- **Round-trip stability (unit):** `serialize(s1) == serialize(applyAppState(fresh, serialize(s1)))`
  over text with mixed formatting + non-default geometry. Proves faithful
  document/geometry restore without `selection`.
- Deserialize is a pure function; the IO layer is a thin shim.

## Scope / limits

- **Single box (`box-1`)** — matches current serialize scope.
- **Restored:** text + all applied formatting + box position/size/rotation.
- **Not restored:** caret/selection position, staged (toggled-but-unapplied)
  formatting — `selection` was removed earlier (accepted). This is the only
  exception to "그대로".
