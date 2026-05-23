import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:richtext/list_outdent_rule.dart';

// Pressing Enter on an EMPTY nested list item should outdent one level
// (indent 3 -> 2 -> 1 -> 0) instead of flutter_quill's default behavior of
// stripping the `list` attribute and stranding the indent.
//
// At level 0 (a list item with no indent) the custom rule defers to the
// built-in AutoExitBlockRule, which removes the list and yields a plain
// paragraph.

void main() {
  // Builds a single empty list line, installs the custom rule, presses Enter
  // at the caret (start of the empty line), and returns the resulting ops.
  List<Map<String, dynamic>> enterOn(Map<String, dynamic> attributes) {
    final doc = Document.fromJson([
      {'insert': '\n', 'attributes': attributes},
    ]);
    installListOutdentRules(doc);
    doc.insert(0, '\n');
    return List<Map<String, dynamic>>.from(doc.toDelta().toJson());
  }

  group('outdent empty list item by one level', () {
    test('bullet level 3 -> level 2', () {
      expect(
        enterOn({'list': 'bullet', 'indent': 3}),
        [
          {
            'insert': '\n',
            'attributes': {'list': 'bullet', 'indent': 2}
          }
        ],
      );
    });

    test('bullet level 2 -> level 1', () {
      expect(
        enterOn({'list': 'bullet', 'indent': 2}),
        [
          {
            'insert': '\n',
            'attributes': {'list': 'bullet', 'indent': 1}
          }
        ],
      );
    });

    test('bullet level 1 -> level 0 (indent removed, list kept)', () {
      expect(
        enterOn({'list': 'bullet', 'indent': 1}),
        [
          {
            'insert': '\n',
            'attributes': {'list': 'bullet'}
          }
        ],
      );
    });

    test('ordered list nested outdents the same way', () {
      expect(
        enterOn({'list': 'ordered', 'indent': 2}),
        [
          {
            'insert': '\n',
            'attributes': {'list': 'ordered', 'indent': 1}
          }
        ],
      );
    });
  });

  group('delegation to built-in rules', () {
    test('bullet level 0 -> plain paragraph (built-in exits the list)', () {
      expect(
        enterOn({'list': 'bullet'}),
        [
          {'insert': '\n'}
        ],
      );
    });

    test('non-list indented paragraph is not treated as a list', () {
      // Custom rule returns null (no list key); built-in AutoExitBlockRule
      // strips the lone indent, yielding a plain paragraph.
      expect(
        enterOn({'indent': 2}),
        [
          {'insert': '\n'}
        ],
      );
    });
  });

  test('non-empty list item creates a new sibling, no outdent', () {
    final doc = Document.fromJson([
      {'insert': 'X'},
      {
        'insert': '\n',
        'attributes': {'list': 'bullet', 'indent': 2}
      },
    ]);
    installListOutdentRules(doc);
    // caret at end of "X" (index 1), press Enter
    doc.insert(1, '\n');
    // "X" stays a bullet at indent 2 and a new empty bullet appears below at the
    // same level. The two list lines share attributes, so they collapse into a
    // single "\n\n" op. Crucially: no outdent (no indent 1) and the list is kept.
    expect(
      doc.toDelta().toJson(),
      [
        {'insert': 'X'},
        {
          'insert': '\n\n',
          'attributes': {'list': 'bullet', 'indent': 2}
        },
      ],
    );
  });
}
