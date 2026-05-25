import 'dart:convert';
import 'extract.dart';
import 'state.dart';

const _prettyEncoder = JsonEncoder.withIndent('  ');

// Emits the first box as a Lab TextObject: { textRotation, paragraphs }.
// This same JSON drives the inspection panel and save/restore. Box geometry
// (offset/size) is intentionally not part of the Lab format.
String serializeAppState(AppState s) {
  if (s.boxes.isEmpty) return _prettyEncoder.convert(<String, dynamic>{});
  return _prettyEncoder.convert(_labObject(s.boxes.first));
}

Map<String, dynamic> _labObject(BoxModel b) {
  final paragraphs = extractParagraphs(b.controller.document);
  return {
    // rotation (0–360, clockwise around the bounding-box center). Negative
    // rotationDeg is normalized into [0, 360) by Dart's %.
    'textRotation': b.rotationDeg % 360,
    'paragraphs': paragraphs.map(_para).toList(),
  };
}

// Lab paragraph: { level, alignment, bullet, runs }. bullet is a boolean:
// true when the paragraph is an unordered-list item, false otherwise.
Map<String, dynamic> _para(ParagraphView p) => {
      'level': p.indentLevel,
      'alignment': p.align,
      'bullet': p.list == 'bullet',
      'runs': p.runs.map(_run).toList(),
    };

// Lab run: style holds formatting (no color); fill carries the solid text color.
Map<String, dynamic> _run(RunView r) => {
      'text': r.text,
      'style': {
        // No highlight → transparent (0x00000000), not null.
        'highlight':
            r.background == null ? '0x00000000' : _labColor(r.background!),
        'font': r.font,
        // pt→px = ×96/72 (§EMU 단위 변환).
        'size': _round2(r.size * 96 / 72),
        'bold': r.bold,
        'italic': r.italic,
        'underline': r.underline ? 'sng' : 'none',
        'strikethrough': r.strike ? 'single' : 'none',
        'baseline': _baseline(r.script),
      },
      'fill': {
        'data': {'color': _labColor(r.color)},
      },
    };

// Round to 2 decimals to match the spec examples (e.g. 32pt → 42.67px).
double _round2(double v) => (v * 100).round() / 100;

// '#RRGGBB' → '0xFFRRGGBB' (opaque). App colors are 6-digit hex; Lab uses
// 0xAARRGGBB.
String _labColor(String hex) {
  var h = hex.replaceFirst('#', '').toUpperCase();
  if (h.length == 6) h = 'FF$h';
  return '0x$h';
}

// script → baseline (%): super = +30.0, sub = −25.0 (§3.3 주3), none = 0.0.
double _baseline(String script) {
  if (script == 'super') return 30.0;
  if (script == 'sub') return -25.0;
  return 0.0;
}
