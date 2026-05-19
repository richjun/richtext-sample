import 'package:flutter/material.dart';
import 'package:flutter_quill/translations.dart' show FlutterQuillLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'canvas_page.dart';
import 'js_inspector.dart';
import 'state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // NOTE: SemanticsBinding.instance.ensureSemantics() intentionally NOT called.
  // Forcing semantics on intercepts pointer events at <flt-semantics> nodes
  // and prevents Quill's TapGestureRecognizer from reaching the editor,
  // which in turn blocks the Flutter text-editing-host from being attached.
  // Playwright targeting now uses coordinate-based clicks driven by
  // window.__inspector.layout() instead of flt-semantics-identifier.
  final state = AppState();
  state.addBox(BoxModel(
    id: 'box-1',
    x: 80, y: 80, width: 360, height: 180,
  ));
  state.select('box-1');
  installInspector(state);
  runApp(RichTextApp(state: state));
}

class RichTextApp extends StatelessWidget {
  final AppState state;
  const RichTextApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'richtext',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ko')],
      home: CanvasPage(state: state),
    );
  }
}
