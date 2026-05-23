import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:richtext/deserialize.dart';
import 'package:richtext/serialize.dart';
import 'package:richtext/state.dart';

// Restore fidelity: serializing, restoring into a fresh state, then
// serializing again must produce identical JSON. Proves the panel JSON alone
// (no selection) round-trips the document + geometry.
void main() {
  test('round-trip: serialize -> applyAppState -> serialize is stable', () {
    final c = QuillController.basic();
    c.document.insert(0, 'Hello world\nsecond');
    c.formatText(0, 5, Attribute.bold); // "Hello" bold
    c.formatText(6, 5, Attribute.italic); // "world" italic
    c.formatText(0, 5, Attribute.fromKeyValue('size', 20)!); // "Hello" size 20
    final src = AppState()
      ..addBox(BoxModel(
        id: 'box-1',
        x: 12,
        y: 34,
        width: 321,
        height: 99,
        rotationDeg: 15,
        controller: c,
      ));
    final json1 = serializeAppState(src);

    final dst = AppState()
      ..addBox(BoxModel(id: 'box-1', x: 0, y: 0, width: 1, height: 1));
    applyAppState(dst, jsonDecode(json1) as Map<String, dynamic>);
    final json2 = serializeAppState(dst);

    expect(json2, equals(json1));
  });

  test('round-trip restores color, highlight, underline, align, bullet', () {
    final c = QuillController.basic();
    c.document.insert(0, 'styled');
    c.formatText(0, 6, Attribute.underline);
    c.formatText(0, 6, Attribute.fromKeyValue('color', '#FF0000')!);
    c.formatText(0, 6, Attribute.fromKeyValue('background', '#FFFF00')!);
    c.formatText(0, 6, Attribute.centerAlignment);
    c.formatText(0, 6, Attribute.ul);
    final src = AppState()
      ..addBox(BoxModel(id: 'box-1', x: 0, y: 0, width: 200, height: 80, controller: c));
    final json1 = serializeAppState(src);

    final dst = AppState()
      ..addBox(BoxModel(id: 'box-1', x: 0, y: 0, width: 1, height: 1));
    applyAppState(dst, jsonDecode(json1) as Map<String, dynamic>);

    expect(serializeAppState(dst), equals(json1));
  });

  test('geometry (offset/size/rotation) restores', () {
    final src = AppState()
      ..addBox(BoxModel(
          id: 'box-1', x: 11, y: 22, width: 200, height: 80, rotationDeg: 30));
    final json = serializeAppState(src);

    final dst = AppState()
      ..addBox(BoxModel(id: 'box-1', x: 0, y: 0, width: 1, height: 1));
    applyAppState(dst, jsonDecode(json) as Map<String, dynamic>);

    final b = dst.boxes.first;
    expect(b.x, 11);
    expect(b.y, 22);
    expect(b.width, 200);
    expect(b.height, 80);
    expect(b.rotationDeg, 30);
  });
}
