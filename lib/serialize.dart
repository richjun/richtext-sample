import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart';
import 'extract.dart';
import 'state.dart';

const _prettyEncoder = JsonEncoder.withIndent('  ');

String serializeAppState(AppState s) {
  // Output a single Lab TextObject (the first box). The selectedBoxId field and
  // the boxes[] wrapper are intentionally omitted.
  if (s.boxes.isEmpty) return _prettyEncoder.convert(<String, dynamic>{});
  // Only the first box is emitted; its stacking index is 0 (bottom of the
  // Stack). element.pdf: higher zIndex renders on top.
  return _prettyEncoder.convert(_box(s.boxes.first, 0));
}

// Lab TextObject. Field groups mirror the spec's "구버전 fallback + 신규 Rich
// Text 병기" mapping (§4):
//   1. 구버전 fallback  — objectId, locked, objectType, text, textAlign,
//      textStyle, offset, size, boundingBox, textFrame (legacy readers show
//      flattened plain text + one representative style). zIndex (element.pdf
//      stacking order) is emitted alongside.
//   2. 신규 Rich Text   — paragraphs.
//   3. editor-only(보존) — transform (rotation), selection. Not part of the Lab
//      document model; kept for diagnostics. §5.7: rotation은 직렬화 보존,
//      §5.5: deserializers ignore unknown fields.
Map<String, dynamic> _box(BoxModel b, int zIndex) {
  final paragraphs = extractParagraphs(b.controller.document);
  // §5.1: every paragraph in a TextObject shares one align value; the first
  // paragraph's align represents the whole object.
  final align = paragraphs.isEmpty ? 'left' : paragraphs.first.align;
  // §1.2 textStyle is a single representative style for legacy readers: the
  // first run of the first paragraph. extractParagraphs guarantees ≥1 paragraph
  // with ≥1 run, so .first is safe here.
  final head = paragraphs.first.runs.first;
  // Plain-text fallback: run texts concatenated per paragraph, paragraphs joined
  // by '\n' (§5.3).
  final text =
      paragraphs.map((p) => p.runs.map((r) => r.text).join()).join('\n');
  return {
    // ── 구버전 fallback ──────────────────────────────────────────────
    'objectId': b.id,
    'locked': false, // box-level lock isn't modeled in this PoC.
    'objectType': 'text',
    // element.pdf: stacking order. Integer, higher renders on top.
    'zIndex': zIndex,
    'text': text,
    'textAlign': align,
    'textStyle': {
      'color': _labColor(head.color),
      'fontWeight': head.bold ? 'bold' : 'normal',
      'fontStyle': head.italic ? 'italic' : 'normal',
      // Legacy fallback size is in px; runs[].style.size stays in pt.
      // pt→px = ×96/72 (§EMU 단위 변환).
      'fontSize': _round2(head.size * 96 / 72),
      'fontFamily': head.font,
      // §1.2 fallback decoration is none|underline only.
      'textDecoration': head.underline ? 'underline' : 'none',
    },
    'offset': {'x': b.x, 'y': b.y},
    'size': {'width': b.width, 'height': b.height},
    // Real box geometry, pre-transform (element.pdf §3.1).
    'boundingBox': {'x': b.x, 'y': b.y, 'width': b.width, 'height': b.height},
    'textFrame': {
      // No stroke/fill is modeled: the grey/blue border is selection chrome,
      // not a document stroke → transparent. The box renders an opaque white
      // fill. Margins mirror the editor's EdgeInsets.all(8) padding.
      'strokeColor': '0x00000000',
      'strokeWidth': 0.0,
      'filledColor': '0xFFFFFFFF',
      'marginLeft': 8.0,
      'marginTop': 8.0,
      'marginRight': 8.0,
      'marginBottom': 8.0,
    },
    // ── editor-only transform (Lab document model 밖, 보존용) ────────
    // element.pdf §3.2 Transform object: rotation (0–360, clockwise around the
    // bounding-box center). flipH/flipV omitted (the editor doesn't model
    // flips). Negative rotationDeg is normalized into [0, 360) by Dart's %.
    'transform': {
      'rotation': b.rotationDeg % 360,
    },
    // ── 신규: Rich Text ──────────────────────────────────────────────
    'paragraphs': paragraphs.map((p) => _para(p, align)).toList(),
    // ── editor-only diagnostics (보존용) ────────────────────────────
    'selection': _selection(b.controller, paragraphs),
  };
}

// Lab paragraph: { level, align, indent, bullet, runs }
// - level  ← quill indent level (0..N); indent (pt) is unused by this app → 0.0
// - bullet ← § 5.2 simplified form { "char": "•" } | null
Map<String, dynamic> _para(ParagraphView p, String align) => {
      'level': p.indentLevel,
      'align': align,
      'indent': 0.0,
      'bullet': _bullet(p.list),
      'runs': p.runs.map(_run).toList(),
    };

// Lab run: { text, style: { font, size, color, highlight, bold, italic,
//   underline, strikethrough, baseline } }
Map<String, dynamic> _run(RunView r) => {
      'text': r.text,
      'style': {
        'font': r.font,
        'size': r.size.toDouble(),
        'color': _labColor(r.color),
        'highlight': r.background == null ? null : _labColor(r.background!),
        'bold': r.bold,
        'italic': r.italic,
        'underline': r.underline ? 'sng' : 'none',
        'strikethrough': r.strike ? 'single' : 'none',
        'baseline': _baseline(r.script),
      },
    };

Map<String, dynamic>? _bullet(String list) =>
    list == 'bullet' ? {'char': '•'} : null;

// Round to 2 decimals to match the spec examples (e.g. 80pt → 106.67px).
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
  final bg = attrs['background']?.value;
  final script = () {
    final v = attrs['script']?.value;
    if (v == 'super') return 'super';
    if (v == 'sub') return 'sub';
    return 'none';
  }();
  // resolvedAttrs uses Lab vocabulary/values, kept flat for diagnostics.
  return {
    'paragraphIndex': paraIdx,
    'runIndex': runIdx,
    'offsetStart': sel.start,
    'offsetEnd': sel.end,
    'resolvedAttrs': {
      'font': (attrs['font']?.value as String?) ?? 'Roboto',
      'size': () {
        final v = attrs['size']?.value;
        if (v is num) return v.toDouble();
        return double.tryParse(v?.toString() ?? '') ?? 14.0;
      }(),
      'color': _labColor(_hashHex(attrs['color']?.value, '#000000')),
      'highlight': bg == null ? null : _labColor(_hashHex(bg, '#000000')),
      'bold': attrs[Attribute.bold.key]?.value == true,
      'italic': attrs[Attribute.italic.key]?.value == true,
      'underline':
          attrs[Attribute.underline.key]?.value == true ? 'sng' : 'none',
      'strikethrough':
          attrs[Attribute.strikeThrough.key]?.value == true ? 'single' : 'none',
      'baseline': _baseline(script),
      'align': (attrs['align']?.value as String?) ?? 'left',
      'level': (attrs['indent']?.value is int) ? attrs['indent']!.value as int : 0,
      'bullet': _bullet(attrs['list']?.value == 'bullet' ? 'bullet' : 'none'),
    },
  };
}

// Normalize a quill color value (may be '#RRGGBB' or 'RRGGBB') to '#RRGGBB'.
String _hashHex(dynamic v, String fallback) {
  if (v == null) return fallback;
  final s = v.toString();
  return s.startsWith('#') ? s : '#$s';
}
