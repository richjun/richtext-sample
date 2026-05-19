import 'package:flutter_test/flutter_test.dart';
import 'package:richtext/state.dart';

void main() {
  test('addBox + select roundtrip', () {
    final s = AppState();
    final b = BoxModel(id: 'box-1', x: 0, y: 0, width: 100, height: 50);
    s.addBox(b);
    s.select('box-1');
    expect(s.selectedBox?.id, 'box-1');
  });
}
