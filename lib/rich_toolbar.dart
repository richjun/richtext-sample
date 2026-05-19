import 'package:flutter/material.dart';
import 'state.dart';

class RichToolbar extends StatelessWidget {
  final AppState state;
  const RichToolbar({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: const Color(0xFFE9E9E9),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: const Row(children: [Text('(toolbar)')]),
    );
  }
}
