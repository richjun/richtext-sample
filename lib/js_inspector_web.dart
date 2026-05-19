import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'serialize.dart';
import 'state.dart';

void installInspector(AppState state) {
  final inspector = JSObject();
  inspector.setProperty(
    'state'.toJS,
    (() => serializeAppState(state).toJS).toJS,
  );
  web.window.setProperty('__inspector'.toJS, inspector);
}
