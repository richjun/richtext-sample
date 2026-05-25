import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:richtext/serialize.dart';
import 'package:richtext/state.dart';

void main() {
  test('empty state serializes to an empty object', () {
    final s = AppState();
    final json = jsonDecode(serializeAppState(s));
    expect(json, <String, dynamic>{});
  });

  test('one box serializes to Lab { textRotation, paragraphs } shape', () {
    final s = AppState()
      ..addBox(BoxModel(id: 'box-1', x: 10, y: 20, width: 300, height: 100))
      ..select('box-1');
    final j = jsonDecode(serializeAppState(s)) as Map<String, dynamic>;

    // Lab format: only textRotation + paragraphs (no box wrapper).
    expect(j.keys.toSet(), {'textRotation', 'paragraphs'});
    expect(j['textRotation'], 0.0);

    final p = (j['paragraphs'] as List).first as Map<String, dynamic>;
    // Paragraph: level, alignment, bullet, runs (no lineSpacing/indent/etc).
    expect(p.keys.toSet(), {'level', 'alignment', 'bullet', 'runs'});
    expect(p['level'], 0);
    expect(p['alignment'], 'left');
    expect(p['bullet'], false); // boolean: no bullet

    final run = (p['runs'] as List).first as Map<String, dynamic>;
    expect(run.keys.toSet(), {'text', 'style', 'fill'});

    final style = run['style'] as Map<String, dynamic>;
    expect(style.containsKey('color'), false); // color moved to fill
    expect(style['highlight'], '0x00000000'); // transparent default
    expect(style['font'], 'Roboto');

    // fill: { data: { color } } — no type / opacity.
    final fill = run['fill'] as Map<String, dynamic>;
    expect(fill.keys.toSet(), {'data'});
    final data = fill['data'] as Map<String, dynamic>;
    expect(data.keys.toSet(), {'color'});
    expect(data['color'], '0xFF000000');
  });
}
