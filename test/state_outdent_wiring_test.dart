import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:richtext/state.dart';

// Integration: a BoxModel's controller must have the outdent rule wired up,
// without the test registering it manually. This file runs in its own isolate,
// so flutter_quill's rule singleton starts empty — if BoxModel does not install
// the rule, the default (list-stripping) behavior runs and this fails.

void main() {
  test('BoxModel controller outdents an empty nested bullet on Enter', () {
    final box = BoxModel(id: 'b', x: 0, y: 0, width: 100, height: 100);
    final c = box.controller;

    // Make the (empty) line a level-3 bullet.
    c.formatText(0, 0, Attribute.ul);
    c.formatText(0, 0, Attribute.getIndentLevel(3));

    // Press Enter on the empty bullet.
    c.document.insert(0, '\n');

    expect(
      c.document.toDelta().toJson(),
      [
        {
          'insert': '\n',
          'attributes': {'list': 'bullet', 'indent': 2}
        }
      ],
    );
  });
}
