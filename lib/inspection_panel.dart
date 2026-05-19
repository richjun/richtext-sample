import 'package:flutter/material.dart';
import 'serialize.dart';
import 'state.dart';

class InspectionPanel extends StatelessWidget {
  final AppState state;
  const InspectionPanel({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final json = serializeAppState(state);
    return Container(
      color: const Color(0xFFFAFAFA),
      padding: const EdgeInsets.all(8),
      child: Semantics(
        identifier: 'state-json',
        explicitChildNodes: true,
        child: SelectableText(
          json,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        ),
      ),
    );
  }
}
