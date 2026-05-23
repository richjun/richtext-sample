// Platform-split persistence for the save/restore feature. Desktop/mobile use a
// real temp file (dart:io); web overrides with localStorage. Mirrors the
// conditional-import pattern in js_inspector.dart.
import 'temp_store_io.dart' if (dart.library.js_interop) 'temp_store_web.dart'
    as impl;

/// Persists [json] to a platform-appropriate temp.json. Returns a
/// human-readable location (file path on desktop, storage key on web).
Future<String> saveTemp(String json) => impl.saveTemp(json);

/// Reads the persisted temp.json, or null if nothing has been saved yet.
Future<String?> loadTemp() => impl.loadTemp();
