import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/translations.dart' show FlutterQuillLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:richtext/canvas_page.dart';
import 'package:richtext/state.dart';
import 'package:richtext/test_registry.dart';

// Regression test for: "on Windows, pressing a toolbar button makes the caret
// disappear". flutter_quill's editor wraps itself in a TextFieldTapRegion whose
// default onTapOutside unfocuses the editor on desktop platforms. A toolbar
// button lives outside the editor, so tapping it drops editor focus (and the
// caret) on desktop — but not on web/mobile. The toolbar must be marked as part
// of the editor's tap region so the button press keeps focus.
void main() {
  Future<BoxModel> pumpEditorWithFocus(WidgetTester tester) async {
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

    // Put the caret in the editor (focus + a real selection).
    box.focusNode.requestFocus();
    box.controller.updateSelection(
      const TextSelection(baseOffset: 0, extentOffset: 5),
      ChangeSource.local,
    );
    await tester.pumpAndSettle();
    expect(box.focusNode.hasFocus, isTrue,
        reason: 'precondition: editor should be focused before tapping toolbar');
    return box;
  }

  testWidgets('tapping a toolbar icon button keeps editor focus (caret stays)',
      (tester) async {
    // onTapOutside only unfocuses on desktop embedders; force one. Reset inside
    // the test body (try/finally) — Flutter verifies foundation debug vars are
    // unset right after the body returns, before any tearDown runs.
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      final box = await pumpEditorWithFocus(tester);

      await tester.tap(find.byKey(keyFor('tb-bold')));
      await tester.pumpAndSettle();

      expect(
        box.focusNode.hasFocus,
        isTrue,
        reason: 'editor lost focus (caret vanished) when the Bold button was '
            'pressed on desktop',
      );

      // Stop the caret-blink timer so the test framework sees no pending timers.
      box.focusNode.unfocus();
      await tester.pump();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
