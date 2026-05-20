import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'state.dart';
import 'test_registry.dart';

class _Choice {
  final String id;
  final String label;
  final Attribute attr;
  // Non-null for color/highlight choices: the actual color to show as a swatch.
  final Color? swatch;
  const _Choice(this.id, this.label, this.attr, {this.swatch});
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

          _colorBtn('tb-color', Icons.format_color_text, _colors(prefix: 'color'),
              _currentColor('color') ?? Colors.black),
          _colorBtn('tb-highlight', Icons.highlight, _colors(prefix: 'hl'),
              _currentColor('background')),

          const VerticalDivider(),
          _pickerBtn('tb-font', Icons.font_download, [
            _Choice('font-Roboto', 'Roboto', Attribute.fromKeyValue('font', 'Roboto')!),
            _Choice('font-Poppins', 'Poppins', Attribute.fromKeyValue('font', 'Poppins')!),
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
    final isColor = prefix == 'color';
    final choices = [
      for (final hex in hexCodes)
        _Choice(
          '$prefix-$hex',
          '#$hex',
          isColor
              ? Attribute.fromKeyValue('color', '#$hex')!
              : Attribute.fromKeyValue('background', '#$hex')!,
          swatch: _hexToColor(hex),
        ),
    ];
    if (!isColor) {
      // Highlight only: a transparent option that clears the background, i.e.
      // removes the highlight so the page shows through. Cloning with a null
      // value drops the attribute entirely (same pattern as toggling off).
      choices.add(_Choice(
        'hl-transparent',
        '투명',
        Attribute.clone(Attribute.background, null),
        swatch: Colors.transparent,
      ));
    }
    return choices;
  }

  // flutter_quill stores colors as '#RRGGBB'; mirror its parsing so the swatch
  // matches what actually renders (see flutter_quill stringToColor()).
  Color _hexToColor(String hex) {
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'ff$h';
    return Color(int.parse(h, radix: 16));
  }

  // Current color of the selection for an attribute key, or null if unset.
  Color? _currentColor(String key) {
    final v = _ctrl?.getSelectionStyle().attributes[key]?.value;
    if (v is String && v.isNotEmpty) {
      try {
        return _hexToColor(v);
      } catch (_) {
        return null;
      }
    }
    return null;
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
      itemBuilder: (_) => [for (final c in choices) _menuItem(c)],
    );
  }

  // Color/highlight picker: an underline beneath the icon shows the current
  // selection color, and the dropdown items show actual color swatches.
  Widget _colorBtn(
      String id, IconData icon, List<_Choice> choices, Color? current) {
    return PopupMenuButton<_Choice>(
      key: keyFor(id),
      tooltip: id,
      onSelected: (c) => _apply(c.attr),
      itemBuilder: (_) => [for (final c in choices) _menuItem(c)],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(height: 2),
            Container(
              width: 18,
              height: 3,
              decoration: BoxDecoration(
                color: current ?? Colors.transparent,
                border: current == null
                    ? Border.all(color: Colors.grey.shade400, width: 0.5)
                    : null,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<_Choice> _menuItem(_Choice c) => PopupMenuItem<_Choice>(
        key: keyFor(c.id),
        value: c,
        child: c.swatch == null
            ? Text(c.label)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: c.swatch,
                      border: Border.all(color: Colors.grey.shade500),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(c.label),
                ],
              ),
      );

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
