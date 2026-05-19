import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_quill/translations.dart' show FlutterQuillLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'canvas_page.dart';
import 'js_inspector.dart';
import 'state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
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
