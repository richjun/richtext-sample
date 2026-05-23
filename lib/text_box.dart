import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'state.dart';
import 'test_registry.dart';

class TextBox extends StatelessWidget {
  final AppState state;
  final BoxModel box;
  const TextBox({
    super.key,
    required this.state,
    required this.box,
  });

  // flutter_quill's default `indent` and `lists` block styles put their 6px gap
  // on the TOP of the block (verticalSpacing (6, 0)). That top gap drops the
  // text ~6px on the first indent/bullet, and — because changing indent level
  // splits a list into separate blocks — it also makes an indented item jump up
  // when the inter-block top gap disappears.
  //
  // Move the gap to the BOTTOM (verticalSpacing (0, 6)) instead. The first
  // element then has no gap above it (no downward drop), while the gap between
  // consecutive blocks stays 6 (prev.bottom + next.top = 6), matching the
  // within-block line gap (lineSpacing (0, 6)) — so indenting never shifts an
  // item vertically. Every other property is preserved.
  static const _blockSpacing = VerticalSpacing(0, 6);

  DefaultStyles _blockStyleOverrides(BuildContext context) {
    final defaults = DefaultStyles.getInstance(context);
    final indent = defaults.indent;
    final lists = defaults.lists;
    return DefaultStyles(
      indent: indent == null
          ? null
          : DefaultTextBlockStyle(
              indent.style,
              indent.horizontalSpacing,
              _blockSpacing,
              indent.lineSpacing,
              indent.decoration,
            ),
      lists: lists == null
          ? null
          : DefaultListBlockStyle(
              lists.style,
              lists.horizontalSpacing,
              _blockSpacing,
              lists.lineSpacing,
              lists.decoration,
              lists.checkboxUIBuilder,
              indentWidthBuilder: lists.indentWidthBuilder,
              numberPointWidthBuilder: lists.numberPointWidthBuilder,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedBoxId == box.id;
    return Positioned(
      left: box.x,
      top: box.y,
      child: Transform.rotate(
        angle: box.rotationDeg * math.pi / 180.0,
        child: SizedBox(
          width: box.width,
          height: box.height,
          child: GestureDetector(
            key: keyFor(box.id),
            behavior: HitTestBehavior.translucent,
            onTapDown: (_) => state.select(box.id),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: selected ? Colors.blue : Colors.grey.shade400,
                  width: selected ? 2 : 1,
                ),
              ),
              child: QuillEditor(
                controller: box.controller,
                focusNode: box.focusNode,
                scrollController: box.scrollController,
                configurations: QuillEditorConfigurations(
                  padding: const EdgeInsets.all(8),
                  autoFocus: false,
                  expands: true,
                  customStyles: _blockStyleOverrides(context),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
