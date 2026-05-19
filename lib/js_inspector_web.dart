import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'serialize.dart';
import 'state.dart';
import 'test_registry.dart';

void installInspector(AppState state) {
  final inspector = JSObject();
  inspector.setProperty(
    'state'.toJS,
    (() => serializeAppState(state).toJS).toJS,
  );
  inspector.setProperty(
    'layout'.toJS,
    (() => jsonEncode(layoutSnapshot()).toJS).toJS,
  );
  web.window.setProperty('__inspector'.toJS, inspector);
}
