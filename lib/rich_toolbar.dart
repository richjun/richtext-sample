import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'state.dart';
import 'test_registry.dart';

class _Choice {
  final String id;
  final String label;
  final Attribute attr;
  const _Choice(this.id, this.label, this.attr);
}

class RichToolbar extends StatelessWidget {
  final AppState state;
  const RichToolbar({super.key, required this.state});

  QuillController? get _ctrl => state.selectedBox?.controller;

  void _apply(Attribute a) {
    final c = _ctrl;
    if (c == null) return;
    c.formatSelection(a);
  }

  void _toggleSimple(Attribute on) {
    final c = _ctrl;
    if (c == null) return;
    final cur = c.getSelectionStyle().attributes[on.key]?.value;
    final desired = (cur == on.value) ? Attribute.clone(on, null) : on;
    c.formatSelection(desired);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: const Color(0xFFE9E9E9),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _icon('tb-bold', Icons.format_bold, () => _toggleSimple(Attribute.bold)),
          _icon('tb-italic', Icons.format_italic, () => _toggleSimple(Attribute.italic)),
          _icon('tb-underline', Icons.format_underline, () => _toggleSimple(Attribute.underline)),
          _icon('tb-strike', Icons.format_strikethrough, () => _toggleSimple(Attribute.strikeThrough)),
          const VerticalDivider(),

          _pickerBtn('tb-color', Icons.format_color_text, _colors(prefix: 'color')),
          _pickerBtn('tb-highlight', Icons.highlight, _colors(prefix: 'hl')),

          const VerticalDivider(),
          _pickerBtn('tb-font', Icons.font_download, [
            _Choice('font-Roboto', 'Roboto', Attribute.fromKeyValue('font', 'Roboto')!),
            _Choice('font-NotoSansKR', 'NotoSansKR', Attribute.fromKeyValue('font', 'NotoSansKR')!),
            _Choice('font-Courier', 'Courier', Attribute.fromKeyValue('font', 'Courier')!),
          ]),
          _pickerBtn('tb-size', Icons.format_size, [
            _Choice('size-12', '12', Attribute.fromKeyValue('size', 12)!),
            _Choice('size-14', '14', Attribute.fromKeyValue('size', 14)!),
            _Choice('size-20', '20', Attribute.fromKeyValue('size', 20)!),
          ]),

          const VerticalDivider(),
          _icon('tb-superscript', Icons.superscript, () => _toggleSimple(Attribute.superscript)),
          _icon('tb-subscript', Icons.subscript, () => _toggleSimple(Attribute.subscript)),
          const VerticalDivider(),
          _icon('tb-align-left', Icons.format_align_left,
              () => _apply(Attribute.leftAlignment)),
          _icon('tb-align-center', Icons.format_align_center,
              () => _apply(Attribute.centerAlignment)),
          _icon('tb-align-right', Icons.format_align_right,
              () => _apply(Attribute.rightAlignment)),
          _icon('tb-indent', Icons.format_indent_increase, () {
            final c = _ctrl;
            if (c == null) return;
            final cur = c.getSelectionStyle().attributes['indent']?.value as int?;
            final next = (cur ?? 0) + 1;
            c.formatSelection(_indentLevel(next));
          }),
          _icon('tb-outdent', Icons.format_indent_decrease, () {
            final c = _ctrl;
            if (c == null) return;
            final cur = c.getSelectionStyle().attributes['indent']?.value as int?;
            final next = (cur ?? 0) - 1;
            if (next <= 0) {
              c.formatSelection(Attribute.clone(Attribute.indentL1, null));
            } else {
              c.formatSelection(_indentLevel(next));
            }
          }),
          _icon('tb-bullet', Icons.format_list_bulleted,
              () => _toggleSimple(Attribute.ul)),
        ]),
      ),
    );
  }

  List<_Choice> _colors({required String prefix}) {
    final hexCodes = ['FF0000', '00FF00', '0000FF', 'FFFF00', '000000'];
    return [
      for (final hex in hexCodes)
        _Choice(
          '$prefix-$hex',
          '#$hex',
          prefix == 'color'
              ? Attribute.fromKeyValue('color', '#$hex')!
              : Attribute.fromKeyValue('background', '#$hex')!,
        ),
    ];
  }

  Widget _icon(String id, IconData icon, VoidCallback onTap) => IconButton(
        key: keyFor(id),
        tooltip: id,
        icon: Icon(icon, size: 18),
        onPressed: onTap,
      );

  Widget _pickerBtn(String id, IconData icon, List<_Choice> choices) {
    return PopupMenuButton<_Choice>(
      key: keyFor(id),
      tooltip: id,
      icon: Icon(icon, size: 18),
      onSelected: (c) => _apply(c.attr),
      itemBuilder: (_) => [
        for (final c in choices)
          PopupMenuItem(
            key: keyFor(c.id),
            value: c,
            child: Text(c.label),
          ),
      ],
    );
  }

  Attribute _indentLevel(int n) {
    switch (n) {
      case 1:
        return Attribute.indentL1;
      case 2:
        return Attribute.indentL2;
      case 3:
        return Attribute.indentL3;
      default:
        if (n > 3) return Attribute.indentL3;
        return Attribute.clone(Attribute.indentL1, null);
    }
  }
}
