import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'state.dart';
import 'transform_handles.dart';

class TextBox extends StatelessWidget {
  final AppState state;
  final BoxModel box;
  const TextBox({super.key, required this.state, required this.box});

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedBoxId == box.id;
    return Positioned(
      left: box.x,
      top: box.y,
      child: Transform.rotate(
        angle: box.rotationDeg * math.pi / 180.0,
        child: Transform.scale(
          scale: box.scale,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: box.width,
            height: box.height,
            child: Stack(clipBehavior: Clip.none, children: [
              GestureDetector(
                onTap: () => state.select(box.id),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: selected ? Colors.blue : Colors.grey.shade400,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Semantics(
                    identifier: 'box-${box.id}',
                    child: QuillEditor.basic(
                      controller: box.controller,
                      configurations: const QuillEditorConfigurations(
                        padding: EdgeInsets.all(8),
                        autoFocus: false,
                        expands: true,
                      ),
                    ),
                  ),
                ),
              ),
              HandlesOverlay(state: state, box: box),
            ]),
          ),
        ),
      ),
    );
  }
}
