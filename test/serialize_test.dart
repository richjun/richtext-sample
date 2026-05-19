import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:richtext/serialize.dart';
import 'package:richtext/state.dart';

void main() {
  test('empty state serializes to selectedBoxId=null and empty boxes', () {
    final s = AppState();
    final json = jsonDecode(serializeAppState(s));
    expect(json['selectedBoxId'], null);
    expect(json['boxes'], []);
  });

  test('one box with default content serializes to spec shape', () {
    final s = AppState()
      ..addBox(BoxModel(id: 'box-1', x: 10, y: 20, width: 300, height: 100))
      ..select('box-1');
    final j = jsonDecode(serializeAppState(s));
    expect(j['selectedBoxId'], 'box-1');
    expect(j['boxes'][0]['id'], 'box-1');
    expect(j['boxes'][0]['x'], 10);
    expect(j['boxes'][0]['scale'], 1.0);
    expect(j['boxes'][0]['rotationDeg'], 0.0);
    expect(j['boxes'][0]['paragraphs'][0]['align'], 'left');
    expect(j['boxes'][0]['selection']['resolvedAttrs']['bold'], false);
  });
}
