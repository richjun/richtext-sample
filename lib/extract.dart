import 'package:flutter_quill/flutter_quill.dart';

class RunView {
  final String text;
  final bool bold, italic, underline, strike;
  final String color; // #RRGGBB
  final String? background; // #RRGGBB or null
  final String font;
  final int size;
  final String script; // none|super|sub

  RunView({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.color = '#000000',
    this.background,
    this.font = 'Roboto',
    this.size = 14,
    this.script = 'none',
  });
}

class ParagraphView {
  final String align; // left|center|right
  final int indentLevel; // 0..N
  final String list; // none|bullet
  final List<RunView> runs;

  ParagraphView({
    required this.align,
    required this.indentLevel,
    required this.list,
    required this.runs,
  });
}

List<ParagraphView> extractParagraphs(Document doc) {
  final ops = doc.toDelta().toList();
  final paragraphs = <ParagraphView>[];
  var runs = <RunView>[];

  for (final op in ops) {
    final data = op.data;
    final attrs = (op.attributes ?? const {}).cast<String, dynamic>();

    if (data is String) {
      final parts = data.split('\n');
      for (var i = 0; i < parts.length; i++) {
        final piece = parts[i];
        if (piece.isNotEmpty) {
          runs.add(_toRun(piece, attrs));
        }
        if (i < parts.length - 1) {
          // The newline op in Quill carries block-level attributes on the '\n'
          // itself; attrs here is from the current op.
          paragraphs.add(_closeParagraph(runs, attrs));
          runs = <RunView>[];
        }
      }
    }
  }

  // Flush any remaining runs (last paragraph has no trailing newline in delta
  // when the doc ends with a plain newline that already closed it).
  if (runs.isNotEmpty) {
    paragraphs.add(_closeParagraph(runs, const {}));
  }

  // A completely empty document still yields one paragraph.
  if (paragraphs.isEmpty) {
    paragraphs.add(_closeParagraph(const [], const {}));
  }

  return paragraphs;
}

RunView _toRun(String text, Map<String, dynamic> a) {
  String? bg = a['background'] as String?;
  String color = (a['color'] as String?) ?? '#000000';
  if (!color.startsWith('#')) color = '#$color';
  if (bg != null && !bg.startsWith('#')) bg = '#$bg';

  return RunView(
    text: text,
    bold: a['bold'] == true,
    italic: a['italic'] == true,
    underline: a['underline'] == true,
    strike: a['strike'] == true,
    color: color,
    background: bg,
    font: (a['font'] as String?) ?? 'Roboto',
    size: _parseSize(a['size']),
    script: _script(a['script']),
  );
}

int _parseSize(dynamic v) {
  if (v == null) return 14;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 14;
}

String _script(dynamic v) {
  if (v == 'super') return 'super';
  if (v == 'sub') return 'sub';
  return 'none';
}

ParagraphView _closeParagraph(
    List<RunView> runs, Map<String, dynamic> block) {
  return ParagraphView(
    align: (block['align'] as String?) ?? 'left',
    indentLevel:
        (block['indent'] is int) ? block['indent'] as int : 0,
    list: block['list'] == 'bullet' ? 'bullet' : 'none',
    runs: List.unmodifiable(runs.isEmpty ? [RunView(text: '')] : runs),
  );
}
