import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/translations.dart' show FlutterQuillLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:richtext/canvas_page.dart';
import 'package:richtext/state.dart';
import 'package:richtext/test_registry.dart';

// The toolbar buttons must reflect the current selection's attributes: toggle
// buttons (bold/italic/...) light up when active, alignment behaves like a radio
// group, and the font/size pickers show their current value. The toolbar already
// rebuilds on selection change (controller -> AppState -> AnimatedBuilder), so
// these tests format the selection and assert the buttons' `isSelected` flag.
void main() {
  Future<BoxModel> pumpEditorWithSelection(WidgetTester tester) async {
    final state = AppState();
    state.addBox(
      BoxModel(id: 'box-1', x: 20, y: 20, width: 320, height: 140),
    );
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
      const TextSelection(baseOffset: 0, extentOffset: 5),
      ChangeSource.local,
    );
    await tester.pumpAndSettle();
    return box;
  }

  bool selected(WidgetTester tester, String id) =>
      tester.widget<IconButton>(find.byKey(keyFor(id))).isSelected ?? false;

  testWidgets('toggle buttons reflect the selection style', (tester) async {
    final box = await pumpEditorWithSelection(tester);
    try {
      expect(selected(tester, 'tb-bold'), isFalse,
          reason: 'precondition: selection is not bold');

      box.controller.formatSelection(Attribute.bold);
      await tester.pumpAndSettle();

      expect(selected(tester, 'tb-bold'), isTrue,
          reason: 'Bold button should be active when the selection is bold');
      expect(selected(tester, 'tb-italic'), isFalse,
          reason: 'Italic stays inactive');

      box.controller.formatSelection(Attribute.clone(Attribute.bold, null));
      await tester.pumpAndSettle();
      expect(selected(tester, 'tb-bold'), isFalse,
          reason: 'Bold button clears when the selection is no longer bold');
    } finally {
      box.focusNode.unfocus();
      await tester.pump();
    }
  });

  testWidgets('superscript/subscript are mutually exclusive', (tester) async {
    final box = await pumpEditorWithSelection(tester);
    try {
      box.controller.formatSelection(Attribute.superscript);
      await tester.pumpAndSettle();
      expect(selected(tester, 'tb-superscript'), isTrue);
      expect(selected(tester, 'tb-subscript'), isFalse);

      box.controller.formatSelection(Attribute.subscript);
      await tester.pumpAndSettle();
      expect(selected(tester, 'tb-superscript'), isFalse);
      expect(selected(tester, 'tb-subscript'), isTrue);
    } finally {
      box.focusNode.unfocus();
      await tester.pump();
    }
  });

  testWidgets('alignment behaves like a radio group (left is the default)',
      (tester) async {
    final box = await pumpEditorWithSelection(tester);
    try {
      // No `align` attribute yet -> left is the implicit default.
      expect(selected(tester, 'tb-align-left'), isTrue);
      expect(selected(tester, 'tb-align-center'), isFalse);
      expect(selected(tester, 'tb-align-right'), isFalse);

      box.controller.formatSelection(Attribute.centerAlignment);
      await tester.pumpAndSettle();
      expect(selected(tester, 'tb-align-left'), isFalse);
      expect(selected(tester, 'tb-align-center'), isTrue);
      expect(selected(tester, 'tb-align-right'), isFalse);
    } finally {
      box.focusNode.unfocus();
      await tester.pump();
    }
  });
}
