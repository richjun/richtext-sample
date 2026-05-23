import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'state.dart';

// Inverse of serialize.dart. Restores [s]'s single box from a Lab JSON map
// produced by serializeAppState: box geometry from offset/size/transform, and
// the Quill document rebuilt from paragraphs[]. Caret/selection and staged
// (toggled-but-unapplied) formatting are not restored — they were never
// serialized.
void applyAppState(AppState s, Map<String, dynamic> json) {
  if (s.boxes.isEmpty) return;
  final box = s.boxes.first;

  // ── geometry ──────────────────────────────────────────────────────
  final offset = json['offset'] as Map<String, dynamic>?;
  final size = json['size'] as Map<String, dynamic>?;
  final rotation =
      ((json['transform'] as Map?)?['rotation'] as num?)?.toDouble() ?? 0.0;
  s.mutateBox(box.id, (b) {
    if (offset != null) {
      b.x = (offset['x'] as num).toDouble();
      b.y = (offset['y'] as num).toDouble();
    }
    if (size != null) {
      b.width = (size['width'] as num).toDouble();
      b.height = (size['height'] as num).toDouble();
    }
    b.rotationDeg = rotation;
  });

  // ── document ──────────────────────────────────────────────────────
  final paragraphs = (json['paragraphs'] as List?) ?? const [];
  box.controller.document = Document.fromDelta(_buildDelta(paragraphs));
}

// paragraphs[] -> Quill Delta. Inline attrs ride the run text; block attrs
// (align/indent/list) attach to the line-ending '\n', as Quill expects.
Delta _buildDelta(List paragraphs) {
  final delta = Delta();
  if (paragraphs.isEmpty) return delta..insert('\n');
  for (final p in paragraphs) {
    final pm = p as Map<String, dynamic>;
    final runs = (pm['runs'] as List?) ?? const [];
    for (final r in runs) {
      final rm = r as Map<String, dynamic>;
      final text = (rm['text'] as String?) ?? '';
      if (text.isEmpty) continue; // empty run: keep the line, no text insert
      final attrs =
          _inlineAttrs((rm['style'] as Map<String, dynamic>?) ?? const {});
      delta.insert(text, attrs.isEmpty ? null : attrs);
    }
    final block = _blockAttrs(pm);
    delta.insert('\n', block.isEmpty ? null : block);
  }
  return delta;
}

// Emit only non-default attributes, mirroring the values the toolbar produces
// (so restored runs render identically and re-serialize to the same JSON).
Map<String, dynamic> _inlineAttrs(Map<String, dynamic> style) {
  final a = <String, dynamic>{};
  if (style['bold'] == true) a['bold'] = true;
  if (style['italic'] == true) a['italic'] = true;
  if (style['underline'] == 'sng') a['underline'] = true;
  if (style['strikethrough'] == 'single') a['strike'] = true;

  final color = _labToHash(style['color'] as String?);
  if (color != null && color != '#000000') a['color'] = color;

  final highlight = _labToHash(style['highlight'] as String?);
  if (highlight != null) a['background'] = highlight;

  final font = style['font'] as String?;
  if (font != null && font != 'Roboto') a['font'] = font;

  final size = style['size'] as num?;
  if (size != null && size != 14) a['size'] = size.toInt();

  final baseline = style['baseline'] as num?;
  if (baseline == 30) a['script'] = 'super';
  if (baseline == -25) a['script'] = 'sub';

  return a;
}

Map<String, dynamic> _blockAttrs(Map<String, dynamic> p) {
  final a = <String, dynamic>{};
  final align = p['align'] as String?;
  if (align != null && align != 'left') a['align'] = align;
  final level = p['level'];
  if (level is int && level > 0) a['indent'] = level;
  if (p['bullet'] != null) a['list'] = 'bullet';
  return a;
}

// Lab color '0xAARRGGBB' -> Quill '#RRGGBB' (alpha dropped; app uses opaque).
String? _labToHash(String? v) {
  if (v == null) return null;
  var s = v;
  if (s.startsWith('0x') || s.startsWith('0X')) s = s.substring(2);
  if (s.length == 8) s = s.substring(2); // drop AA
  if (s.length != 6) return null;
  return '#$s';
}
