import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart';
import 'extract.dart';
import 'state.dart';

String serializeAppState(AppState s) {
  return jsonEncode({
    'selectedBoxId': s.selectedBoxId,
    'boxes': s.boxes.map(_box).toList(),
  });
}

Map<String, dynamic> _box(BoxModel b) {
  final paragraphs = extractParagraphs(b.controller.document);
  return {
    'id': b.id,
    'x': b.x,
    'y': b.y,
    'width': b.width,
    'height': b.height,
    'scale': b.scale,
    'rotationDeg': b.rotationDeg,
    'paragraphs': paragraphs.map(_para).toList(),
    'selection': _selection(b.controller, paragraphs),
  };
}

Map<String, dynamic> _para(ParagraphView p) => {
      'align': p.align,
      'indentLevel': p.indentLevel,
      'list': p.list,
      'runs': p.runs.map(_run).toList(),
    };

Map<String, dynamic> _run(RunView r) => {
      'text': r.text,
      'bold': r.bold,
      'italic': r.italic,
      'underline': r.underline,
      'strike': r.strike,
      'color': r.color,
      'background': r.background,
      'font': r.font,
      'size': r.size,
      'script': r.script,
    };

Map<String, dynamic> _selection(
    QuillController c, List<ParagraphView> paras) {
  final sel = c.selection;
  int offset = 0;
  int paraIdx = 0;
  int runIdx = 0;
  outer:
  for (var pi = 0; pi < paras.length; pi++) {
    for (var ri = 0; ri < paras[pi].runs.length; ri++) {
      final len = paras[pi].runs[ri].text.length;
      if (sel.start <= offset + len) {
        paraIdx = pi;
        runIdx = ri;
        break outer;
      }
      offset += len;
    }
    offset += 1; // newline between paragraphs
  }
  final attrs = c.getSelectionStyle().attributes;
  return {
    'paragraphIndex': paraIdx,
    'runIndex': runIdx,
    'offsetStart': sel.start,
    'offsetEnd': sel.end,
    'resolvedAttrs': {
      'bold': attrs[Attribute.bold.key]?.value == true,
      'italic': attrs[Attribute.italic.key]?.value == true,
      'underline': attrs[Attribute.underline.key]?.value == true,
      'strike': attrs[Attribute.strikeThrough.key]?.value == true,
      'color': _norm(attrs['color']?.value, '#000000'),
      'background': _norm(attrs['background']?.value, null),
      'font': (attrs['font']?.value as String?) ?? 'Roboto',
      'size': () {
        final v = attrs['size']?.value;
        if (v is num) return v.toInt();
        return int.tryParse(v?.toString() ?? '') ?? 14;
      }(),
      'script': () {
        final v = attrs['script']?.value;
        if (v == 'super') return 'super';
        if (v == 'sub') return 'sub';
        return 'none';
      }(),
      'align': (attrs['align']?.value as String?) ?? 'left',
      'indentLevel': (attrs['indent']?.value is int)
          ? attrs['indent']!.value as int
          : 0,
      'list': attrs['list']?.value == 'bullet' ? 'bullet' : 'none',
    },
  };
}

dynamic _norm(dynamic v, dynamic fallback) {
  if (v == null) return fallback;
  final s = v.toString();
  return s.startsWith('#') ? s : '#$s';
}
