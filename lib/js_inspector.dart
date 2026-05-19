import 'state.dart';
import 'js_inspector_stub.dart'
    if (dart.library.js_interop) 'js_inspector_web.dart' as impl;

void installInspector(AppState state) => impl.installInspector(state);
