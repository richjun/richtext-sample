import 'package:flutter/material.dart';
import 'inspection_panel.dart';
import 'rich_toolbar.dart';
import 'state.dart';
import 'text_box.dart';

class CanvasPage extends StatelessWidget {
  final AppState state;
  const CanvasPage({super.key, required this.state});

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
                          children: [
                            for (final b in state.boxes)
                              TextBox(state: state, box: b),
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
