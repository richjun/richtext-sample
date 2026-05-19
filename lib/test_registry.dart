import 'package:flutter/widgets.dart';

// Registry of GlobalKeys for elements that need to be addressable from
// browser-side test code (playwright). Used in place of Semantics(identifier:)
// since ensureSemantics() interferes with QuillEditor text input.
final Map<String, GlobalKey> testKeys = {};

GlobalKey keyFor(String id) {
  return testKeys.putIfAbsent(id, () => GlobalKey(debugLabel: id));
}

// Returns {id: {x, y, width, height}} for every registered key whose widget
// is currently mounted. Coordinates are in viewport pixels.
Map<String, Map<String, double>> layoutSnapshot() {
  final out = <String, Map<String, double>>{};
  for (final entry in testKeys.entries) {
    final ctx = entry.value.currentContext;
    if (ctx == null) continue;
    final ro = ctx.findRenderObject();
    if (ro is! RenderBox || !ro.attached) continue;
    final offset = ro.localToGlobal(Offset.zero);
    out[entry.key] = {
      'x': offset.dx,
      'y': offset.dy,
      'width': ro.size.width,
      'height': ro.size.height,
    };
  }
  return out;
}
