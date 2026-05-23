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

  // True when the selection already carries [a] (same key *and* value). Used to
  // light up toggle/alignment buttons. Compares against a pre-read attribute map
  // so the whole toolbar reads the selection style once per build.
  bool _isOn(Map<String, Attribute> attrs, Attribute a) =>
      attrs[a.key]?.value == a.value;

  @override
  Widget build(BuildContext context) {
    // Mark the toolbar as part of the editor's tap region. flutter_quill's
    // editor unfocuses on a tap *outside* its TextFieldTapRegion (desktop-only,
    // via EditableText's default onTapOutside) — which would drop the caret the
    // moment a toolbar button is pressed. Sharing the tap-region group makes a
    // toolbar tap count as "inside", so focus (and the caret) is preserved.
    // Tapping the empty canvas is still "outside" and deselects as before.
    //
    // Snapshot the selection style once: every button below reads its active
    // state from this map rather than calling getSelectionStyle() each time.
    final attrs = _ctrl?.getSelectionStyle().attributes ??
        const <String, Attribute>{};
    final align = attrs['align']?.value as String?;
    // Picker current values fall back to the app defaults (Roboto / size 14)
    // when the selection has no explicit attribute, so the buttons and their
    // menus always show a marked-active choice.
    final font = (attrs['font']?.value as String?) ?? 'Roboto';
    final size = attrs['size']?.value ?? 14;
    return TextFieldTapRegion(
      child: Container(
        height: 44,
        color: const Color(0xFFE9E9E9),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _icon('tb-bold', Icons.format_bold,
                () => _toggleSimple(Attribute.bold),
                active: _isOn(attrs, Attribute.bold)),
            _icon('tb-italic', Icons.format_italic,
                () => _toggleSimple(Attribute.italic),
                active: _isOn(attrs, Attribute.italic)),
            _icon('tb-underline', Icons.format_underline,
                () => _toggleSimple(Attribute.underline),
                active: _isOn(attrs, Attribute.underline)),
            _icon('tb-strike', Icons.format_strikethrough,
                () => _toggleSimple(Attribute.strikeThrough),
                active: _isOn(attrs, Attribute.strikeThrough)),
            const VerticalDivider(),
            _colorBtn(
                'tb-color',
                Icons.format_color_text,
                _colors(prefix: 'color'),
                _currentColor('color') ?? Colors.black,
                attrs['color']?.value as String?),
            _colorBtn('tb-highlight', Icons.highlight, _colors(prefix: 'hl'),
                _currentColor('background'), attrs['background']?.value as String?),
            const VerticalDivider(),
            _pickerBtn(
              'tb-font',
              Icons.font_download,
              [
                _Choice('font-Roboto', 'Roboto',
                    Attribute.fromKeyValue('font', 'Roboto')!),
                _Choice('font-Poppins', 'Poppins',
                    Attribute.fromKeyValue('font', 'Poppins')!),
                _Choice('font-Courier', 'Courier',
                    Attribute.fromKeyValue('font', 'Courier')!),
              ],
              label: font,
              currentValue: font,
            ),
            _pickerBtn(
              'tb-size',
              Icons.format_size,
              [
                _Choice('size-12', '12', Attribute.fromKeyValue('size', 12)!),
                _Choice('size-14', '14', Attribute.fromKeyValue('size', 14)!),
                _Choice('size-20', '20', Attribute.fromKeyValue('size', 20)!),
              ],
              label: '$size',
              currentValue: size,
            ),
            const VerticalDivider(),
            _icon('tb-superscript', Icons.superscript,
                () => _toggleSimple(Attribute.superscript),
                active: _isOn(attrs, Attribute.superscript)),
            _icon('tb-subscript', Icons.subscript,
                () => _toggleSimple(Attribute.subscript),
                active: _isOn(attrs, Attribute.subscript)),
            const VerticalDivider(),
            // Alignment is a radio group: a selected line with no `align`
            // attribute is left-aligned. Guard on having a controller so the
            // button doesn't light up when nothing is selected.
            _icon('tb-align-left', Icons.format_align_left,
                () => _apply(Attribute.leftAlignment),
                active: _ctrl != null && (align == null || align == 'left')),
            _icon('tb-align-center', Icons.format_align_center,
                () => _apply(Attribute.centerAlignment),
                active: align == 'center'),
            _icon('tb-align-right', Icons.format_align_right,
                () => _apply(Attribute.rightAlignment),
                active: align == 'right'),
            // Delegate to flutter_quill's indent logic so the toolbar matches
            // the Tab key exactly (caps at level 5 = six levels, 0..5).
            _icon('tb-indent', Icons.format_indent_increase,
                () => _ctrl?.indentSelection(true)),
            _icon('tb-outdent', Icons.format_indent_decrease,
                () => _ctrl?.indentSelection(false)),
            _icon('tb-bullet', Icons.format_list_bulleted,
                () => _toggleSimple(Attribute.ul),
                active: _isOn(attrs, Attribute.ul)),
          ]),
        ),
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

  Widget _icon(String id, IconData icon, VoidCallback onTap,
          {bool active = false}) =>
      IconButton(
        key: keyFor(id),
        tooltip: id,
        isSelected: active,
        icon: Icon(icon, size: 18),
        // When active, fill with a soft blue and tint the glyph so the button
        // reads as "on". Inactive buttons keep the default flat look.
        style: active
            ? IconButton.styleFrom(
                backgroundColor: Colors.blue.shade100,
                foregroundColor: Colors.blue.shade800,
              )
            : null,
        onPressed: onTap,
      );

  // Font/size picker: the icon sits above a small label showing the current
  // selection value, and the active choice is checked in the dropdown. Values
  // are compared as strings since `size` may arrive as an int or a string.
  Widget _pickerBtn(String id, IconData icon, List<_Choice> choices,
      {required String label, Object? currentValue}) {
    return PopupMenuButton<_Choice>(
      key: keyFor(id),
      tooltip: id,
      onSelected: (c) => _apply(c.attr),
      itemBuilder: (_) => [
        for (final c in choices)
          _menuItem(c, active: '${c.attr.value}' == '$currentValue'),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  // Color/highlight picker: an underline beneath the icon shows the current
  // selection color, and the dropdown items show actual color swatches.
  Widget _colorBtn(String id, IconData icon, List<_Choice> choices,
      Color? current, String? currentValue) {
    return PopupMenuButton<_Choice>(
      key: keyFor(id),
      tooltip: id,
      onSelected: (c) => _apply(c.attr),
      itemBuilder: (_) => [
        for (final c in choices)
          _menuItem(c, active: c.attr.value == currentValue),
      ],
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

  PopupMenuItem<_Choice> _menuItem(_Choice c, {bool active = false}) =>
      PopupMenuItem<_Choice>(
        key: keyFor(c.id),
        value: c,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Fixed-width leading slot keeps labels aligned whether or not the
            // row carries the active checkmark.
            SizedBox(
              width: 20,
              child: active ? const Icon(Icons.check, size: 16) : null,
            ),
            if (c.swatch != null) ...[
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
            ],
            Text(c.label),
          ],
        ),
      );

}
