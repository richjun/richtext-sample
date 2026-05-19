import 'package:flutter/material.dart';
import 'inspection_panel.dart';
import 'rich_toolbar.dart';
import 'state.dart';
import 'text_box.dart';
import 'transform_handles.dart';

class CanvasPage extends StatelessWidget {
  final AppState state;
  CanvasPage({super.key, required this.state});

  final GlobalKey _canvasKey = GlobalKey(debugLabel: 'canvas-stack');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: state,
        builder: (_, __) => Column(
          children: [
            RichToolbar(state: state),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => state.select(null),
                      child: Container(
                        color: const Color(0xFFF6F6F6),
                        child: Stack(
                          key: _canvasKey,
                          clipBehavior: Clip.none,
                          children: [
                            for (final b in state.boxes)
                              TextBox(state: state, box: b),
                            // All transform handles render at canvas level so
                            // they can straddle the box edges without being
                            // clipped by the editor SizedBox's hit bounds.
                            for (final b in state.boxes)
                              BoxHandles(
                                key: ValueKey('handles-${b.id}'),
                                state: state,
                                box: b,
                                canvasKey: _canvasKey,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 360,
                    child: InspectionPanel(state: state),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
