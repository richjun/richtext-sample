import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/translations.dart' show FlutterQuillLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:richtext/canvas_page.dart';
import 'package:richtext/state.dart';

// flutter_quill's default `indent` and `lists` block styles add a 6px top
// spacing, while a plain paragraph has none. The first indent / first bullet
// wraps the line in that block, so the text visibly drops ~6px. The editor must
// override both styles so neither action moves the text vertically.
void main() {
  // RichText for the line whose plain text contains [needle] — avoids matching
  // the bullet leading marker ("•"), which is a separate RichText.
  Finder lineText(String needle) => find.byWidgetPredicate(
      (w) => w is RichText && w.text.toPlainText().contains(needle));

  Future<BoxModel> pumpBox(WidgetTester tester) async {
    final state = AppState();
    state.addBox(BoxModel(id: 'box-1', x: 20, y: 20, width: 320, height: 140));
    state.select('box-1');
    final box = state.selectedBox!;
    box.controller.document.insert(0, 'Test');

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
        const TextSelection.collapsed(offset: 2), ChangeSource.local);
    await tester.pumpAndSettle();
    return box;
  }

  testWidgets('first indent does not shift the line vertically',
      (tester) async {
    final box = await pumpBox(tester);
    final yBefore = tester.getTopLeft(lineText('Test')).dy;

    box.controller.indentSelection(true); // first indent (0 -> 1)
    await tester.pumpAndSettle();
    final yAfter = tester.getTopLeft(lineText('Test')).dy;

    expect(yAfter, closeTo(yBefore, 0.01),
        reason: 'first indent must not move the text down (was +6px)');
    box.focusNode.unfocus();
    await tester.pump();
  });

  testWidgets('making a bullet does not shift the line vertically',
      (tester) async {
    final box = await pumpBox(tester);
    final yBefore = tester.getTopLeft(lineText('Test')).dy;

    box.controller.formatSelection(Attribute.ul); // make it a bullet
    await tester.pumpAndSettle();
    final yAfter = tester.getTopLeft(lineText('Test')).dy;

    expect(yAfter, closeTo(yBefore, 0.01),
        reason: 'first bullet must not move the text down (was +6px)');
    box.focusNode.unfocus();
    await tester.pump();
  });

  // Tab-indenting the second item of a list splits it into its own block (a
  // different indent level). The inter-block gap must stay equal to the
  // within-block line gap, otherwise the indented item jumps vertically.
  testWidgets('Tab-indenting the second bullet does not move it up',
      (tester) async {
    final state = AppState();
    state.addBox(BoxModel(id: 'box-1', x: 20, y: 20, width: 320, height: 160));
    state.select('box-1');
    final box = state.selectedBox!;
    box.controller.document.replace(
      0,
      box.controller.document.length - 1,
      Document.fromJson([
        {'insert': 'A'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'}
        },
        {'insert': 'B'},
        {
          'insert': '\n',
          'attributes': {'list': 'bullet'}
        },
      ]).toDelta(),
    );

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
        const TextSelection.collapsed(offset: 3), ChangeSource.local); // on "B"
    await tester.pumpAndSettle();

    final yBefore = tester.getTopLeft(lineText('B')).dy;
    box.controller.indentSelection(true); // Tab: level 0 -> 1, splits block
    await tester.pumpAndSettle();
    final yAfter = tester.getTopLeft(lineText('B')).dy;

    expect(yAfter, closeTo(yBefore, 0.01),
        reason: 'indenting the second bullet must not move it up (was -6px)');
    box.focusNode.unfocus();
    await tester.pump();
  });
}
