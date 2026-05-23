import 'dart:convert';
import 'package:flutter/material.dart';
import 'deserialize.dart';
import 'serialize.dart';
import 'state.dart';
import 'temp_store.dart';

class InspectionPanel extends StatelessWidget {
  final AppState state;
  const InspectionPanel({super.key, required this.state});

  Future<void> _save(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final where = await saveTemp(serializeAppState(state));
      messenger.showSnackBar(SnackBar(content: Text('저장됨: $where')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('저장 실패: $e')));
    }
  }

  Future<void> _restore(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final raw = await loadTemp();
      if (raw == null) {
        messenger
            .showSnackBar(const SnackBar(content: Text('저장된 상태가 없습니다')));
        return;
      }
      applyAppState(state, jsonDecode(raw) as Map<String, dynamic>);
      messenger.showSnackBar(const SnackBar(content: Text('복원됨')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('복원 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final json = serializeAppState(state);
    return Container(
      color: const Color(0xFFFAFAFA),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ElevatedButton.icon(
                key: const ValueKey('btn-save'),
                onPressed: () => _save(context),
                icon: const Icon(Icons.save, size: 16),
                label: const Text('저장'),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                key: const ValueKey('btn-restore'),
                onPressed: () => _restore(context),
                icon: const Icon(Icons.restore, size: 16),
                label: const Text('복원'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Semantics(
                identifier: 'state-json',
                explicitChildNodes: true,
                child: SelectableText(
                  json,
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
