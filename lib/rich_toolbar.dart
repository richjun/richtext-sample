import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'state.dart';

class RichToolbar extends StatelessWidget {
  final AppState state;
  const RichToolbar({super.key, required this.state});

  QuillController? get _ctrl => state.selectedBox?.controller;

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
      child: Row(children: [
        _icon('tb-bold', Icons.format_bold, () => _toggleSimple(Attribute.bold)),
        _icon('tb-italic', Icons.format_italic, () => _toggleSimple(Attribute.italic)),
        _icon('tb-underline', Icons.format_underline, () => _toggleSimple(Attribute.underline)),
        _icon('tb-strike', Icons.format_strikethrough, () => _toggleSimple(Attribute.strikeThrough)),
      ]),
    );
  }

  Widget _icon(String id, IconData icon, VoidCallback onTap) => Semantics(
        identifier: id,
        button: true,
        child: IconButton(
          tooltip: id,
          icon: Icon(icon, size: 18),
          onPressed: onTap,
        ),
      );
}
