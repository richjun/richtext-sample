import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/translations.dart' show FlutterQuillLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:richtext/canvas_page.dart';
import 'package:richtext/state.dart';
import 'package:richtext/test_registry.dart';

// The toolbar indent/outdent buttons must delegate to flutter_quill's
// QuillController.indentSelection, so they behave identically to the Tab key:
// indent caps at level 5 (six levels: 0..5), and outdent steps back down and
// removes the indent attribute at the bottom.
void main() {
  Future<BoxModel> pumpEditor(WidgetTester tester) async {
    final state = AppState();
    state.addBox(BoxModel(id: 'box-1', x: 20, y: 20, width: 320, height: 140));
    state.select('box-1');
    final box = state.selectedBox!;
    box.controller.document.insert(0, 'hello world');

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      home: CanvasPage(state: state),
    ));
    await tester.pumpAndSettle();

    box.focusNode.requestFocus();
    box.controller.updateSelection(
      const TextSelection.collapsed(offset: 2),
      ChangeSource.local,
    );
    await tester.pumpAndSettle();
    return box;
  }

  int? indentOf(BoxModel box) =>
      box.controller.getSelectionStyle().attributes['indent']?.value as int?;

  Future<void> tapIndent(WidgetTester tester) async {
    await tester.tap(find.byKey(keyFor('tb-indent')));
    await tester.pumpAndSettle();
  }

  Future<void> tapOutdent(WidgetTester tester) async {
    await tester.tap(find.byKey(keyFor('tb-outdent')));
    await tester.pumpAndSettle();
  }

  testWidgets('indent button reaches level 5 and caps there (6 levels)',
      (tester) async {
    final box = await pumpEditor(tester);
    try {
      expect(indentOf(box), isNull, reason: 'starts with no indent (level 0)');

      final seq = <int?>[];
      for (var i = 0; i < 7; i++) {
        await tapIndent(tester);
        seq.add(indentOf(box));
      }
      expect(seq, [1, 2, 3, 4, 5, 5, 5],
          reason: 'matches Tab: increments to 5 then caps');
    } finally {
      box.focusNode.unfocus();
      await tester.pump();
    }
  });

  testWidgets('outdent button steps down and clears indent at the bottom',
      (tester) async {
    final box = await pumpEditor(tester);
    try {
      for (var i = 0; i < 3; i++) {
        await tapIndent(tester);
      }
      expect(indentOf(box), 3);

      await tapOutdent(tester);
      expect(indentOf(box), 2);
      await tapOutdent(tester);
      expect(indentOf(box), 1);
      await tapOutdent(tester);
      expect(indentOf(box), isNull, reason: 'indent attribute removed at level 0');
    } finally {
      box.focusNode.unfocus();
      await tester.pump();
    }
  });
}
