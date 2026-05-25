import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'state.dart';

// Inverse of serialize.dart. Restores [s]'s single box from a Lab JSON map
// produced by serializeAppState: textRotation and the Quill document rebuilt
// from paragraphs[]. Geometry (offset/size) is not part of the Lab format, so
// box position/size is left untouched. Caret/selection and staged
// (toggled-but-unapplied) formatting are not restored — they were never
// serialized.
void applyAppState(AppState s, Map<String, dynamic> json) {
  if (s.boxes.isEmpty) return;
  final box = s.boxes.first;

  final rotation = (json['textRotation'] as num?)?.toDouble() ?? 0.0;
  s.mutateBox(box.id, (b) => b.rotationDeg = rotation);

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
      final attrs = _inlineAttrs(
        (rm['style'] as Map<String, dynamic>?) ?? const {},
        rm['fill'] as Map<String, dynamic>?,
      );
      delta.insert(text, attrs.isEmpty ? null : attrs);
    }
    final block = _blockAttrs(pm);
    delta.insert('\n', block.isEmpty ? null : block);
  }
  return delta;
}

// Emit only non-default attributes, mirroring the values the toolbar produces
// (so restored runs render identically and re-serialize to the same JSON).
Map<String, dynamic> _inlineAttrs(
    Map<String, dynamic> style, Map<String, dynamic>? fill) {
  final a = <String, dynamic>{};
  if (style['bold'] == true) a['bold'] = true;
  if (style['italic'] == true) a['italic'] = true;
  if (style['underline'] == 'sng') a['underline'] = true;
  if (style['strikethrough'] == 'single') a['strike'] = true;

  // Text color now lives in fill.data.color.
  final data = fill?['data'] as Map<String, dynamic>?;
  final color = _labToHash(data?['color'] as String?);
  if (color != null && color != '#000000') a['color'] = color;

  // highlight 0x00000000 (transparent) → no background.
  final highlight = _labToHash(style['highlight'] as String?);
  if (highlight != null) a['background'] = highlight;

  final font = style['font'] as String?;
  if (font != null && font != 'Roboto') a['font'] = font;

  // Lab size is px; the editor stores pt-like values → px × 72/96.
  final size = style['size'] as num?;
  if (size != null) {
    final pt = (size * 72 / 96).round();
    if (pt != 14) a['size'] = pt;
  }

  // baseline > 0 → superscript, < 0 → subscript (tolerant of non-integer values).
  final baseline = style['baseline'] as num?;
  if (baseline != null && baseline > 0) a['script'] = 'super';
  if (baseline != null && baseline < 0) a['script'] = 'sub';

  return a;
}

Map<String, dynamic> _blockAttrs(Map<String, dynamic> p) {
  final a = <String, dynamic>{};
  final align = p['alignment'] as String?;
  if (align != null && align != 'left') a['align'] = align;
  final level = p['level'];
  if (level is int && level > 0) a['indent'] = level;
  if (p['bullet'] == true) a['list'] = 'bullet';
  return a;
}

// Lab color '0xAARRGGBB' -> Quill '#RRGGBB' (alpha dropped; app uses opaque).
// Fully transparent (alpha 00) -> null.
String? _labToHash(String? v) {
  if (v == null) return null;
  var s = v;
  if (s.startsWith('0x') || s.startsWith('0X')) s = s.substring(2);
  if (s.length == 8) {
    if (s.substring(0, 2).toUpperCase() == '00') return null; // transparent
    s = s.substring(2); // drop AA
  }
  if (s.length != 6) return null;
  return '#${s.toUpperCase()}'; // normalize case for idempotent round-trips
}
