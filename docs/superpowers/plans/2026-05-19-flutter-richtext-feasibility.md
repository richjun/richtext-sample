# Flutter Web Rich Text Feasibility — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Flutter Web/Windows test app that proves each requested paragraph/run/textbox feature is implementable, with a Playwright suite that produces a machine-readable PASS/FAIL report per feature.

**Architecture:** Slide-canvas with PowerPoint-style text box objects. Each box wraps a `flutter_quill` editor in a `Transform.rotate → Transform.scale → SizedBox` stack. App exposes a single `state-json` element (via `Semantics(identifier:)`) that Playwright parses to assert post-operation state. No tests against pixels; all assertions on serialized state.

**Tech Stack:** Flutter 3.24.x (Web + Windows), `flutter_quill` ≥ 10.x, Playwright (`@playwright/test`), Node 20+, Python 3 (for static file serve).

**Spec:** [`docs/superpowers/specs/2026-05-19-flutter-richtext-feasibility-design.md`](../specs/2026-05-19-flutter-richtext-feasibility-design.md)

---

## File Structure

```
richtext/
├── pubspec.yaml
├── lib/
│   ├── main.dart                 # entry, ensureSemantics, runApp
│   ├── state.dart                # AppState + BoxModel (ChangeNotifier)
│   ├── extract.dart              # Quill Document → ParagraphView/RunView pure fn
│   ├── serialize.dart            # AppState → JSON string pure fn
│   ├── canvas_page.dart          # Scaffold (toolbar/canvas/panel)
│   ├── text_box.dart             # Transform stack + Quill editor + handles
│   ├── transform_handles.dart    # 8 resize + 1 rotate handle
│   ├── rich_toolbar.dart         # all toolbar buttons (Semantics ids)
│   └── inspection_panel.dart     # renders <state-json> from AppState
├── test/
│   ├── extract_test.dart         # Delta → ParagraphView/RunView
│   ├── serialize_test.dart       # AppState → JSON contract
│   └── transform_math_test.dart  # corner-scale + rotation geometry
├── verify/
│   ├── package.json
│   ├── playwright.config.ts
│   └── tests/
│       ├── _helpers.ts
│       ├── paragraph.spec.ts
│       ├── run.spec.ts
│       └── textbox.spec.ts
└── scripts/
    └── verify.sh
```

Boundaries: pure logic (`extract.dart`, `serialize.dart`, transform math) is unit-tested in `test/` with `flutter_test`. Everything else is integration-tested by Playwright through the actual browser. This keeps fast feedback for the tricky stuff and uses the right tool (real browser) for UI.

---

## Task 1: Bootstrap Flutter project

**Files:**
- Create: `pubspec.yaml`, `lib/main.dart` (placeholder), `web/index.html` (generated)

- [ ] **Step 1: Create the Flutter project in place**

Working directory is empty `/Users/junyoungyoon/Source/richtext`. Use a temporary side-create then move (Flutter refuses to scaffold into a non-empty dir; here it is empty but `docs/` already exists, so use `--platforms` with `flutter create .`).

```bash
cd /Users/junyoungyoon/Source/richtext
flutter create . --platforms=web,windows --project-name=richtext --org=local.richtext
```

Expected: scaffolds `lib/`, `web/`, `windows/`, `pubspec.yaml`, etc. `docs/` is preserved.

- [ ] **Step 2: Add dependencies to `pubspec.yaml`**

Open `pubspec.yaml`. Under `dependencies:` add `flutter_quill`. Leave the rest as Flutter created it.

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_quill: ^10.0.0
  cupertino_icons: ^1.0.6
```

- [ ] **Step 3: Resolve packages**

Run: `flutter pub get`
Expected: "Got dependencies!" with no errors.

- [ ] **Step 4: Initialize git and commit scaffold**

```bash
git init
git add .
git commit -m "chore: bootstrap flutter project with flutter_quill"
```

---

## Task 2: Data model with selection state

**Files:**
- Create: `lib/state.dart`
- Test: `test/state_test.dart` (smoke only)

- [ ] **Step 1: Write the model**

Create `lib/state.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart';

class BoxModel {
  final String id;
  double x;
  double y;
  double width;
  double height;
  double scale;
  double rotationDeg;
  final QuillController controller;

  BoxModel({
    required this.id,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.scale = 1.0,
    this.rotationDeg = 0.0,
    QuillController? controller,
  }) : controller = controller ?? QuillController.basic();
}

class AppState extends ChangeNotifier {
  final List<BoxModel> boxes = [];
  String? selectedBoxId;

  BoxModel? get selectedBox =>
      boxes.where((b) => b.id == selectedBoxId).cast<BoxModel?>().firstOrNull;

  void addBox(BoxModel b) {
    boxes.add(b);
    b.controller.addListener(_emit);
    b.controller.changes.listen((_) => _emit());
    notifyListeners();
  }

  void select(String? id) {
    if (selectedBoxId == id) return;
    selectedBoxId = id;
    notifyListeners();
  }

  void mutateBox(String id, void Function(BoxModel) fn) {
    final b = boxes.firstWhere((b) => b.id == id);
    fn(b);
    notifyListeners();
  }

  void _emit() => notifyListeners();
}

extension _First<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
```

- [ ] **Step 2: Smoke test it compiles and a box can be added**

Create `test/state_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:richtext/state.dart';

void main() {
  test('addBox + select roundtrip', () {
    final s = AppState();
    final b = BoxModel(id: 'box-1', x: 0, y: 0, width: 100, height: 50);
    s.addBox(b);
    s.select('box-1');
    expect(s.selectedBox?.id, 'box-1');
  });
}
```

- [ ] **Step 3: Run it**

Run: `flutter test test/state_test.dart`
Expected: 1 passed.

- [ ] **Step 4: Commit**

```bash
git add lib/state.dart test/state_test.dart
git commit -m "feat: app state with boxes, selection, quill controllers"
```

---

## Task 3: Extract paragraphs and runs from a Quill Document (TDD)

This is the core of the inspection panel — pure, deterministic, easy to TDD.

**Files:**
- Create: `lib/extract.dart`
- Test: `test/extract_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/extract_test.dart`:

```dart
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:richtext/extract.dart';

void main() {
  test('plain text becomes one paragraph with one run', () {
    final doc = Document()..insert(0, 'hello');
    final paras = extractParagraphs(doc);
    expect(paras.length, 1);
    expect(paras[0].runs.length, 1);
    expect(paras[0].runs[0].text, 'hello');
    expect(paras[0].runs[0].bold, false);
    expect(paras[0].align, 'left');
  });

  test('two paragraphs separated by newline', () {
    final doc = Document()
      ..insert(0, 'first\nsecond');
    final paras = extractParagraphs(doc);
    expect(paras.length, 2);
    expect(paras[0].runs[0].text, 'first');
    expect(paras[1].runs[0].text, 'second');
  });

  test('mixed bold run inside paragraph', () {
    final doc = Document();
    doc.insert(0, 'hello world');
    doc.format(0, 5, Attribute.bold); // bold "hello"
    final paras = extractParagraphs(doc);
    expect(paras[0].runs.length, 2);
    expect(paras[0].runs[0].text, 'hello');
    expect(paras[0].runs[0].bold, true);
    expect(paras[0].runs[1].text, ' world');
    expect(paras[0].runs[1].bold, false);
  });

  test('center-aligned paragraph', () {
    final doc = Document()..insert(0, 'x');
    doc.format(0, 1, Attribute.centerAlignment);
    final paras = extractParagraphs(doc);
    expect(paras[0].align, 'center');
  });

  test('indent level 2', () {
    final doc = Document()..insert(0, 'x');
    doc.format(0, 1, Attribute.indentL2);
    final paras = extractParagraphs(doc);
    expect(paras[0].indentLevel, 2);
  });

  test('superscript run', () {
    final doc = Document()..insert(0, 'x');
    doc.format(0, 1, Attribute.superscript);
    final paras = extractParagraphs(doc);
    expect(paras[0].runs[0].script, 'super');
  });

  test('bullet list', () {
    final doc = Document()..insert(0, 'x');
    doc.format(0, 1, Attribute.ul);
    final paras = extractParagraphs(doc);
    expect(paras[0].list, 'bullet');
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/extract_test.dart`
Expected: FAIL — `extract.dart` does not exist.

- [ ] **Step 3: Implement `lib/extract.dart`**

```dart
import 'package:flutter_quill/flutter_quill.dart';

class RunView {
  final String text;
  final bool bold, italic, underline, strike;
  final String color;       // #RRGGBB
  final String? background; // #RRGGBB or null
  final String font;
  final int size;
  final String script;      // none|super|sub

  RunView({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    this.strike = false,
    this.color = '#000000',
    this.background,
    this.font = 'Roboto',
    this.size = 14,
    this.script = 'none',
  });
}

class ParagraphView {
  final String align;     // left|center|right
  final int indentLevel;  // 0..N
  final String list;      // none|bullet
  final List<RunView> runs;
  ParagraphView({
    required this.align,
    required this.indentLevel,
    required this.list,
    required this.runs,
  });
}

List<ParagraphView> extractParagraphs(Document doc) {
  final ops = doc.toDelta().toList();
  final paragraphs = <ParagraphView>[];
  var runs = <RunView>[];
  // block attributes attach to the trailing '\n' op
  for (final op in ops) {
    final data = op.data;
    final attrs = (op.attributes ?? const {}).cast<String, dynamic>();
    if (data is String) {
      // split on '\n' so each newline closes a paragraph
      final parts = data.split('\n');
      for (var i = 0; i < parts.length; i++) {
        final piece = parts[i];
        if (piece.isNotEmpty) {
          runs.add(_toRun(piece, attrs));
        }
        if (i < parts.length - 1) {
          // this is a newline → close paragraph with block attrs
          paragraphs.add(_closeParagraph(runs, attrs));
          runs = <RunView>[];
        }
      }
    }
  }
  if (paragraphs.isEmpty || runs.isNotEmpty) {
    // trailing content without final newline
    paragraphs.add(_closeParagraph(runs, const {}));
  }
  return paragraphs;
}

RunView _toRun(String text, Map<String, dynamic> a) {
  String? bg = a['background'] as String?;
  String color = (a['color'] as String?) ?? '#000000';
  if (!color.startsWith('#')) color = '#$color';
  if (bg != null && !bg.startsWith('#')) bg = '#$bg';
  return RunView(
    text: text,
    bold: a['bold'] == true,
    italic: a['italic'] == true,
    underline: a['underline'] == true,
    strike: a['strike'] == true,
    color: color,
    background: bg,
    font: (a['font'] as String?) ?? 'Roboto',
    size: _parseSize(a['size']),
    script: _script(a['script']),
  );
}

int _parseSize(dynamic v) {
  if (v == null) return 14;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 14;
}

String _script(dynamic v) {
  if (v == 'super') return 'super';
  if (v == 'sub') return 'sub';
  return 'none';
}

ParagraphView _closeParagraph(List<RunView> runs, Map<String, dynamic> block) {
  return ParagraphView(
    align: (block['align'] as String?) ?? 'left',
    indentLevel: (block['indent'] is int) ? block['indent'] as int : 0,
    list: block['list'] == 'bullet' ? 'bullet' : 'none',
    runs: List.unmodifiable(runs.isEmpty
        ? [RunView(text: '')]
        : runs),
  );
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/extract_test.dart`
Expected: 7 passed.

- [ ] **Step 5: Commit**

```bash
git add lib/extract.dart test/extract_test.dart
git commit -m "feat: extract paragraphs and runs from quill document"
```

---

## Task 4: Serialize AppState to the spec JSON shape (TDD)

**Files:**
- Create: `lib/serialize.dart`
- Test: `test/serialize_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/serialize_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:richtext/serialize.dart';
import 'package:richtext/state.dart';

void main() {
  test('empty state serializes to selectedBoxId=null and empty boxes', () {
    final s = AppState();
    final json = jsonDecode(serializeAppState(s));
    expect(json['selectedBoxId'], null);
    expect(json['boxes'], []);
  });

  test('one box with default content serializes to spec shape', () {
    final s = AppState()
      ..addBox(BoxModel(id: 'box-1', x: 10, y: 20, width: 300, height: 100))
      ..select('box-1');
    final j = jsonDecode(serializeAppState(s));
    expect(j['selectedBoxId'], 'box-1');
    expect(j['boxes'][0]['id'], 'box-1');
    expect(j['boxes'][0]['x'], 10);
    expect(j['boxes'][0]['scale'], 1.0);
    expect(j['boxes'][0]['rotationDeg'], 0.0);
    expect(j['boxes'][0]['paragraphs'][0]['align'], 'left');
    expect(j['boxes'][0]['selection']['resolvedAttrs']['bold'], false);
  });
}
```

- [ ] **Step 2: Verify failure**

Run: `flutter test test/serialize_test.dart`
Expected: FAIL — `serialize.dart` missing.

- [ ] **Step 3: Implement `lib/serialize.dart`**

```dart
import 'dart:convert';
import 'package:flutter_quill/flutter_quill.dart';
import 'extract.dart';
import 'state.dart';

String serializeAppState(AppState s) {
  return jsonEncode({
    'selectedBoxId': s.selectedBoxId,
    'boxes': s.boxes.map(_box).toList(),
  });
}

Map<String, dynamic> _box(BoxModel b) {
  final paragraphs = extractParagraphs(b.controller.document);
  return {
    'id': b.id,
    'x': b.x,
    'y': b.y,
    'width': b.width,
    'height': b.height,
    'scale': b.scale,
    'rotationDeg': b.rotationDeg,
    'paragraphs': paragraphs.map(_para).toList(),
    'selection': _selection(b.controller, paragraphs),
  };
}

Map<String, dynamic> _para(ParagraphView p) => {
      'align': p.align,
      'indentLevel': p.indentLevel,
      'list': p.list,
      'runs': p.runs.map(_run).toList(),
    };

Map<String, dynamic> _run(RunView r) => {
      'text': r.text,
      'bold': r.bold,
      'italic': r.italic,
      'underline': r.underline,
      'strike': r.strike,
      'color': r.color,
      'background': r.background,
      'font': r.font,
      'size': r.size,
      'script': r.script,
    };

Map<String, dynamic> _selection(QuillController c, List<ParagraphView> paras) {
  final sel = c.selection;
  // Compute (paragraphIndex, runIndex, offsets) by walking paragraphs.
  // For simplicity in the test app: report the start position only.
  int offset = 0;
  int paraIdx = 0;
  int runIdx = 0;
  int offsetInRun = sel.start;
  outer:
  for (var pi = 0; pi < paras.length; pi++) {
    for (var ri = 0; ri < paras[pi].runs.length; ri++) {
      final len = paras[pi].runs[ri].text.length;
      if (sel.start <= offset + len) {
        paraIdx = pi;
        runIdx = ri;
        offsetInRun = sel.start - offset;
        break outer;
      }
      offset += len;
    }
    offset += 1; // newline between paragraphs
  }
  final attrs = c.getSelectionStyle().attributes;
  return {
    'paragraphIndex': paraIdx,
    'runIndex': runIdx,
    'offsetStart': sel.start,
    'offsetEnd': sel.end,
    'resolvedAttrs': {
      'bold': attrs[Attribute.bold.key]?.value == true,
      'italic': attrs[Attribute.italic.key]?.value == true,
      'underline': attrs[Attribute.underline.key]?.value == true,
      'strike': attrs[Attribute.strikeThrough.key]?.value == true,
      'color': _norm(attrs['color']?.value, '#000000'),
      'background': _norm(attrs['background']?.value, null),
      'font': (attrs['font']?.value as String?) ?? 'Roboto',
      'size': () {
        final v = attrs['size']?.value;
        if (v is num) return v.toInt();
        return int.tryParse(v?.toString() ?? '') ?? 14;
      }(),
      'script': () {
        final v = attrs['script']?.value;
        if (v == 'super') return 'super';
        if (v == 'sub') return 'sub';
        return 'none';
      }(),
      'align': (attrs['align']?.value as String?) ?? 'left',
      'indentLevel': (attrs['indent']?.value is int)
          ? attrs['indent']!.value as int
          : 0,
      'list': attrs['list']?.value == 'bullet' ? 'bullet' : 'none',
    },
  };
}

dynamic _norm(dynamic v, dynamic fallback) {
  if (v == null) return fallback;
  final s = v.toString();
  return s.startsWith('#') ? s : '#$s';
}
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/serialize_test.dart`
Expected: 2 passed.

- [ ] **Step 5: Commit**

```bash
git add lib/serialize.dart test/serialize_test.dart
git commit -m "feat: serialize app state to spec JSON shape"
```

---

## Task 5: App entry + empty CanvasPage scaffold

**Files:**
- Modify: `lib/main.dart` (overwrite scaffold)
- Create: `lib/canvas_page.dart`
- Create: `lib/inspection_panel.dart` (stub)
- Create: `lib/rich_toolbar.dart` (stub)

- [ ] **Step 1: Replace `lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'canvas_page.dart';
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
```

- [ ] **Step 2: Add `flutter_localizations` to pubspec**

Open `pubspec.yaml`. Under `dependencies:` add:

```yaml
  flutter_localizations:
    sdk: flutter
```

Run: `flutter pub get`

- [ ] **Step 3: Create `lib/canvas_page.dart`**

```dart
import 'package:flutter/material.dart';
import 'inspection_panel.dart';
import 'rich_toolbar.dart';
import 'state.dart';
import 'text_box.dart';

class CanvasPage extends StatelessWidget {
  final AppState state;
  const CanvasPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: state,
        builder: (_, __) => Column(
          children: [
            RichToolbar(state: state),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => state.select(null),
                      child: Container(
                        color: const Color(0xFFF6F6F6),
                        child: Stack(
                          children: [
                            for (final b in state.boxes)
                              TextBox(state: state, box: b),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 360,
                    child: InspectionPanel(state: state),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Create stubs**

Create `lib/inspection_panel.dart`:

```dart
import 'package:flutter/material.dart';
import 'serialize.dart';
import 'state.dart';

class InspectionPanel extends StatelessWidget {
  final AppState state;
  const InspectionPanel({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final json = serializeAppState(state);
    return Container(
      color: const Color(0xFFFAFAFA),
      padding: const EdgeInsets.all(8),
      child: Semantics(
        identifier: 'state-json',
        explicitChildNodes: true,
        child: SelectableText(
          json,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
        ),
      ),
    );
  }
}
```

Create `lib/rich_toolbar.dart` (empty placeholder for now):

```dart
import 'package:flutter/material.dart';
import 'state.dart';

class RichToolbar extends StatelessWidget {
  final AppState state;
  const RichToolbar({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: const Color(0xFFE9E9E9),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: const Row(children: [Text('(toolbar)')]),
    );
  }
}
```

- [ ] **Step 5: Create stub `lib/text_box.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'state.dart';

class TextBox extends StatelessWidget {
  final AppState state;
  final BoxModel box;
  const TextBox({super.key, required this.state, required this.box});

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedBoxId == box.id;
    return Positioned(
      left: box.x,
      top: box.y,
      child: Transform.rotate(
        angle: box.rotationDeg * 3.1415926535 / 180.0,
        child: Transform.scale(
          scale: box.scale,
          alignment: Alignment.topLeft,
          child: GestureDetector(
            onTap: () => state.select(box.id),
            child: Container(
              width: box.width,
              height: box.height,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: selected ? Colors.blue : Colors.grey.shade400,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Semantics(
                identifier: 'box-${box.id}',
                child: QuillEditor.basic(
                  controller: box.controller,
                  configurations: const QuillEditorConfigurations(
                    padding: EdgeInsets.all(8),
                    autoFocus: false,
                    expands: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Run the app once**

Run: `flutter run -d chrome --web-port=8765`
Expected: A white text box on a light grey canvas with placeholder text edit working; right panel shows JSON. Stop with `q`.

- [ ] **Step 7: Commit**

```bash
git add lib/ pubspec.yaml pubspec.lock
git commit -m "feat: app shell with canvas, one editable box, json inspection panel"
```

---

## Task 6: Inspection panel listens reactively + expose via window for fallback

**Files:**
- Modify: `lib/inspection_panel.dart`
- Modify: `lib/main.dart` (expose `window.__inspector`)
- Create: `lib/js_inspector.dart` (web stub)

- [ ] **Step 1: Make the panel rebuild on every change**

The CanvasPage already wraps everything in `AnimatedBuilder(animation: state)`. That covers state mutations and box additions. But Quill controller changes also need to trigger rebuilds: confirm `AppState._emit` is already wired in Task 2. No code change.

- [ ] **Step 2: Add a JS inspector hook for playwright fallback**

Create `lib/js_inspector.dart`:

```dart
// Web stub — registers a window-level inspector that returns the JSON string.
// Used by playwright as a fallback if Semantics targeting is flaky.
import 'package:flutter/foundation.dart';
import 'serialize.dart';
import 'state.dart';

void installInspector(AppState state) {
  if (!kIsWeb) return;
  // Lazily import dart:js_interop inside a web-only path.
  _installImpl(state);
}

// Implementation imported only on web via conditional import below.
void _installImpl(AppState state) {
  // populated by js_inspector_web.dart via export
}
```

Replace the above with a conditional-import version:

```dart
import 'state.dart';
export 'js_inspector_stub.dart'
  if (dart.library.html) 'js_inspector_web.dart';

void installInspector(AppState state);
```

Actually keep it simple. Replace `lib/js_inspector.dart` with:

```dart
import 'state.dart';
import 'js_inspector_stub.dart'
    if (dart.library.html) 'js_inspector_web.dart' as impl;

void installInspector(AppState state) => impl.installInspector(state);
```

Create `lib/js_inspector_stub.dart`:

```dart
import 'state.dart';
void installInspector(AppState state) {}
```

Create `lib/js_inspector_web.dart`:

```dart
import 'dart:html' as html;
import 'dart:js_util' as jsu;
import 'serialize.dart';
import 'state.dart';

void installInspector(AppState state) {
  final inspector = jsu.newObject();
  jsu.setProperty(inspector, 'state', jsu.allowInterop(() {
    return serializeAppState(state);
  }));
  jsu.setProperty(html.window, '__inspector', inspector);
  state.addListener(() {
    // Force layout flush so DOM-bound testers can observe.
  });
}
```

- [ ] **Step 3: Call it from main**

In `lib/main.dart`, after creating `state`, add:

```dart
import 'js_inspector.dart';
// ...
installInspector(state);
```

- [ ] **Step 4: Smoke-run**

Run: `flutter run -d chrome --web-port=8765`
Open devtools console, type `__inspector.state()`. Expected: returns the JSON string.

Stop with `q`.

- [ ] **Step 5: Commit**

```bash
git add lib/
git commit -m "feat: window.__inspector.state() for playwright fallback"
```

---

## Task 7: Toolbar — run-level toggles (Bold/Italic/Underline/Strike)

**Files:**
- Modify: `lib/rich_toolbar.dart`

- [ ] **Step 1: Implement bold/italic/underline/strike with Semantics ids**

Replace `lib/rich_toolbar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'state.dart';

class RichToolbar extends StatelessWidget {
  final AppState state;
  const RichToolbar({super.key, required this.state});

  QuillController? get _ctrl => state.selectedBox?.controller;

  void _toggle(Attribute on, Attribute off) {
    final c = _ctrl;
    if (c == null) return;
    final cur = c.getSelectionStyle().attributes[on.key]?.value;
    final desired = (cur == on.value) ? off : on;
    c.formatSelection(desired);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: const Color(0xFFE9E9E9),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(children: [
        _btn('tb-bold', Icons.format_bold,
            () => _toggle(Attribute.bold, Attribute.clone(Attribute.bold, null))),
        _btn('tb-italic', Icons.format_italic,
            () => _toggle(Attribute.italic, Attribute.clone(Attribute.italic, null))),
        _btn('tb-underline', Icons.format_underline,
            () => _toggle(Attribute.underline, Attribute.clone(Attribute.underline, null))),
        _btn('tb-strike', Icons.format_strikethrough,
            () => _toggle(Attribute.strikeThrough, Attribute.clone(Attribute.strikeThrough, null))),
      ]),
    );
  }

  Widget _btn(String id, IconData icon, VoidCallback onTap) {
    return Semantics(
      identifier: id,
      button: true,
      child: IconButton(
        tooltip: id,
        icon: Icon(icon, size: 18),
        onPressed: onTap,
      ),
    );
  }
}
```

- [ ] **Step 2: Smoke test in browser**

Run: `flutter run -d chrome --web-port=8765`. Type some text in the box, select it, click Bold. JSON panel should show the run with `bold: true` and `selection.resolvedAttrs.bold: true`. Stop with `q`.

- [ ] **Step 3: Commit**

```bash
git add lib/rich_toolbar.dart
git commit -m "feat: toolbar bold/italic/underline/strike with testids"
```

---

## Task 8: Toolbar — color, highlight, font, size, super/subscript

**Files:**
- Modify: `lib/rich_toolbar.dart`

- [ ] **Step 1: Extend with pickers and discrete choices**

Replace the `_RichToolbarState` build with a longer Row. Add this helper class above the toolbar widget:

```dart
class _Choice {
  final String id;
  final String label;
  final Attribute attr;
  const _Choice(this.id, this.label, this.attr);
}
```

And update `lib/rich_toolbar.dart` to:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'state.dart';

class _Choice {
  final String id;
  final String label;
  final Attribute attr;
  const _Choice(this.id, this.label, this.attr);
}

class RichToolbar extends StatelessWidget {
  final AppState state;
  const RichToolbar({super.key, required this.state});

  QuillController? get _ctrl => state.selectedBox?.controller;

  void _apply(Attribute a) {
    final c = _ctrl;
    if (c == null) return;
    c.formatSelection(a);
  }

  void _toggleSimple(Attribute on) {
    final c = _ctrl;
    if (c == null) return;
    final cur = c.getSelectionStyle().attributes[on.key]?.value;
    final desired = (cur == on.value) ? Attribute.clone(on, null) : on;
    c.formatSelection(desired);
  }

  void _toggleExclusive(Attribute on) {
    final c = _ctrl;
    if (c == null) return;
    final cur = c.getSelectionStyle().attributes[on.key]?.value;
    final desired = (cur == on.value) ? Attribute.clone(on, null) : on;
    c.formatSelection(desired);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: const Color(0xFFE9E9E9),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _icon('tb-bold', Icons.format_bold, () => _toggleSimple(Attribute.bold)),
          _icon('tb-italic', Icons.format_italic, () => _toggleSimple(Attribute.italic)),
          _icon('tb-underline', Icons.format_underline, () => _toggleSimple(Attribute.underline)),
          _icon('tb-strike', Icons.format_strikethrough, () => _toggleSimple(Attribute.strikeThrough)),
          const VerticalDivider(),

          _pickerBtn('tb-color', Icons.format_color_text, _colors(prefix: 'color')),
          _pickerBtn('tb-highlight', Icons.highlight, _colors(prefix: 'hl')),

          const VerticalDivider(),
          _pickerBtn('tb-font', Icons.font_download, [
            _Choice('font-Roboto', 'Roboto', Attribute.fromKeyValue('font', 'Roboto')),
            _Choice('font-NotoSansKR', 'NotoSansKR', Attribute.fromKeyValue('font', 'NotoSansKR')),
            _Choice('font-Courier', 'Courier', Attribute.fromKeyValue('font', 'Courier')),
          ]),
          _pickerBtn('tb-size', Icons.format_size, [
            _Choice('size-12', '12', Attribute.fromKeyValue('size', '12')),
            _Choice('size-14', '14', Attribute.fromKeyValue('size', '14')),
            _Choice('size-20', '20', Attribute.fromKeyValue('size', '20')),
          ]),

          const VerticalDivider(),
          _icon('tb-superscript', Icons.superscript, () => _toggleExclusive(Attribute.superscript)),
          _icon('tb-subscript', Icons.subscript, () => _toggleExclusive(Attribute.subscript)),
        ]),
      ),
    );
  }

  List<_Choice> _colors({required String prefix}) {
    final palette = {
      'FF0000': Colors.red,
      '00FF00': Colors.green,
      '0000FF': Colors.blue,
      'FFFF00': Colors.yellow,
      '000000': Colors.black,
    };
    return [
      for (final entry in palette.entries)
        _Choice(
          '$prefix-${entry.key}',
          '#${entry.key}',
          prefix == 'color'
              ? Attribute.fromKeyValue('color', '#${entry.key}')
              : Attribute.fromKeyValue('background', '#${entry.key}'),
        ),
    ];
  }

  Widget _icon(String id, IconData icon, VoidCallback onTap) => Semantics(
        identifier: id,
        button: true,
        child: IconButton(
          tooltip: id,
          icon: Icon(icon, size: 18),
          onPressed: onTap,
        ),
      );

  Widget _pickerBtn(String id, IconData icon, List<_Choice> choices) {
    return Semantics(
      identifier: id,
      button: true,
      child: PopupMenuButton<_Choice>(
        tooltip: id,
        icon: Icon(icon, size: 18),
        onSelected: (c) => _apply(c.attr),
        itemBuilder: (_) => [
          for (final c in choices)
            PopupMenuItem(
              value: c,
              child: Semantics(
                identifier: c.id,
                button: true,
                child: Text(c.label),
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Smoke in browser**

Run: `flutter run -d chrome --web-port=8765`. Select text, open Color → choose red. JSON should show `color: "#FF0000"`. Try Sub/Super, check `script` field. Stop with `q`.

- [ ] **Step 3: Commit**

```bash
git add lib/rich_toolbar.dart
git commit -m "feat: toolbar color, highlight, font, size, super/subscript"
```

---

## Task 9: Toolbar — paragraph formatting (align, indent, outdent, bullet)

**Files:**
- Modify: `lib/rich_toolbar.dart`

- [ ] **Step 1: Append paragraph buttons**

In `lib/rich_toolbar.dart`, inside the `Row(children: [...])`, after the existing buttons, add:

```dart
          const VerticalDivider(),
          _icon('tb-align-left', Icons.format_align_left,
              () => _apply(Attribute.leftAlignment)),
          _icon('tb-align-center', Icons.format_align_center,
              () => _apply(Attribute.centerAlignment)),
          _icon('tb-align-right', Icons.format_align_right,
              () => _apply(Attribute.rightAlignment)),

          _icon('tb-indent', Icons.format_indent_increase, () {
            final c = _ctrl;
            if (c == null) return;
            final cur = c.getSelectionStyle().attributes['indent']?.value as int?;
            final next = (cur ?? 0) + 1;
            c.formatSelection(Attribute.getIndentLevel(next));
          }),
          _icon('tb-outdent', Icons.format_indent_decrease, () {
            final c = _ctrl;
            if (c == null) return;
            final cur = c.getSelectionStyle().attributes['indent']?.value as int?;
            final next = (cur ?? 0) - 1;
            if (next <= 0) {
              c.formatSelection(Attribute.clone(Attribute.indentL1, null));
            } else {
              c.formatSelection(Attribute.getIndentLevel(next));
            }
          }),
          _icon('tb-bullet', Icons.format_list_bulleted,
              () => _toggleSimple(Attribute.ul)),
```

If `Attribute.getIndentLevel(int)` isn't a method on the installed `flutter_quill` version, fall back to the explicit constants:

```dart
Attribute _indentLevel(int n) {
  switch (n) {
    case 1: return Attribute.indentL1;
    case 2: return Attribute.indentL2;
    case 3: return Attribute.indentL3;
    default: return n > 3 ? Attribute.indentL3 : Attribute.clone(Attribute.indentL1, null);
  }
}
```

Use `_indentLevel(next)` in place of `Attribute.getIndentLevel(next)` in the handlers above.

- [ ] **Step 2: Smoke**

Run: `flutter run -d chrome --web-port=8765`. Type text, click Center → JSON `align: "center"`. Click Indent → `indentLevel: 1`. Outdent → `0`. Bullet → `list: "bullet"`. Stop with `q`.

- [ ] **Step 3: Commit**

```bash
git add lib/rich_toolbar.dart
git commit -m "feat: toolbar align, indent, outdent, bullet"
```

---

## Task 10: Transform handles — side resize (TDD math)

**Files:**
- Create: `lib/transform_handles.dart`
- Modify: `lib/text_box.dart` (overlay handles when selected)
- Create: `test/transform_math_test.dart`

- [ ] **Step 1: Write failing math tests**

Create `test/transform_math_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:richtext/transform_handles.dart';

void main() {
  group('sideResize', () {
    test('right handle increases width only', () {
      final r = sideResize(side: Side.right, dx: 20, dy: 10, w: 100, h: 50);
      expect(r.width, 120);
      expect(r.height, 50);
    });
    test('bottom handle increases height only', () {
      final r = sideResize(side: Side.bottom, dx: 5, dy: 30, w: 100, h: 50);
      expect(r.width, 100);
      expect(r.height, 80);
    });
    test('width does not drop below 40', () {
      final r = sideResize(side: Side.right, dx: -1000, dy: 0, w: 100, h: 50);
      expect(r.width, 40);
    });
  });

  group('cornerScale', () {
    test('drag diagonal doubles scale when initial diagonal is half', () {
      final s = cornerScale(
        startDiag: 100, currentDiag: 200, initialScale: 1.0);
      expect(s, 2.0);
    });
    test('scale clamped to >= 0.1', () {
      final s = cornerScale(startDiag: 1000, currentDiag: 1, initialScale: 1.0);
      expect(s, 0.1);
    });
  });

  group('rotationAngle', () {
    test('start above center, drag to right is +90 deg', () {
      final a = rotationAngleDeg(
        centerX: 0, centerY: 0, x: 10, y: 0);
      expect(a.round(), 90);
    });
    test('directly below center is +180 / -180', () {
      final a = rotationAngleDeg(centerX: 0, centerY: 0, x: 0, y: 10);
      expect(a.abs().round(), 180);
    });
  });
}
```

- [ ] **Step 2: Verify failure**

Run: `flutter test test/transform_math_test.dart`
Expected: FAIL — `transform_handles.dart` missing.

- [ ] **Step 3: Implement math + handle widgets**

Create `lib/transform_handles.dart`:

```dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'state.dart';

enum Side { top, right, bottom, left }
enum Corner { tl, tr, bl, br }

class ResizeResult {
  final double width;
  final double height;
  ResizeResult(this.width, this.height);
}

ResizeResult sideResize({
  required Side side,
  required double dx, required double dy,
  required double w, required double h,
}) {
  double nw = w, nh = h;
  switch (side) {
    case Side.right: nw = w + dx; break;
    case Side.left:  nw = w - dx; break;
    case Side.bottom: nh = h + dy; break;
    case Side.top:    nh = h - dy; break;
  }
  if (nw < 40) nw = 40;
  if (nh < 24) nh = 24;
  return ResizeResult(nw, nh);
}

double cornerScale({
  required double startDiag,
  required double currentDiag,
  required double initialScale,
}) {
  if (startDiag <= 0) return initialScale;
  final s = initialScale * (currentDiag / startDiag);
  return s < 0.1 ? 0.1 : s;
}

double rotationAngleDeg({
  required double centerX, required double centerY,
  required double x, required double y,
}) {
  // 0deg = handle directly above center (negative Y).
  final dx = x - centerX;
  final dy = y - centerY;
  final rad = math.atan2(dx, -dy);
  return rad * 180.0 / math.pi;
}

class HandlesOverlay extends StatelessWidget {
  final AppState state;
  final BoxModel box;
  const HandlesOverlay({super.key, required this.state, required this.box});

  @override
  Widget build(BuildContext context) {
    if (state.selectedBoxId != box.id) return const SizedBox.shrink();
    final w = box.width;
    final h = box.height;
    return Stack(clipBehavior: Clip.none, children: [
      // sides
      _sideHandle(Side.top,    left: w/2 - 5, top: -5),
      _sideHandle(Side.right,  left: w - 5,   top: h/2 - 5),
      _sideHandle(Side.bottom, left: w/2 - 5, top: h - 5),
      _sideHandle(Side.left,   left: -5,      top: h/2 - 5),
      // corners
      _cornerHandle(Corner.tl, left: -5,    top: -5),
      _cornerHandle(Corner.tr, left: w - 5, top: -5),
      _cornerHandle(Corner.bl, left: -5,    top: h - 5),
      _cornerHandle(Corner.br, left: w - 5, top: h - 5),
      // rotate
      Positioned(
        left: w/2 - 5,
        top: -30,
        child: Semantics(
          identifier: 'box-${box.id}-handle-rotate',
          button: true,
          child: _RotateHandle(state: state, box: box),
        ),
      ),
    ]);
  }

  Widget _sideHandle(Side s, {required double left, required double top}) {
    final id = 'box-${box.id}-handle-side-${{
      Side.top: 't', Side.right: 'r', Side.bottom: 'b', Side.left: 'l'
    }[s]}';
    return Positioned(
      left: left, top: top,
      child: Semantics(
        identifier: id,
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (d) {
            state.mutateBox(box.id, (b) {
              final r = sideResize(
                side: s, dx: d.delta.dx, dy: d.delta.dy,
                w: b.width, h: b.height,
              );
              b.width = r.width;
              b.height = r.height;
            });
          },
          child: const _Dot(color: Colors.blueAccent),
        ),
      ),
    );
  }

  Widget _cornerHandle(Corner c, {required double left, required double top}) {
    final id = 'box-${box.id}-handle-corner-${{
      Corner.tl: 'tl', Corner.tr: 'tr', Corner.bl: 'bl', Corner.br: 'br'
    }[c]}';
    return Positioned(
      left: left, top: top,
      child: Semantics(
        identifier: id,
        button: true,
        child: _CornerHandle(state: state, box: box, corner: c),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: 10, height: 10,
    decoration: BoxDecoration(color: color, shape: BoxShape.rectangle,
      border: Border.all(color: Colors.white, width: 1)));
}

class _CornerHandle extends StatefulWidget {
  final AppState state;
  final BoxModel box;
  final Corner corner;
  const _CornerHandle({required this.state, required this.box, required this.corner});
  @override State<_CornerHandle> createState() => _CornerHandleState();
}

class _CornerHandleState extends State<_CornerHandle> {
  double _startDiag = 0;
  double _initialScale = 1.0;
  Offset _origin = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) {
        _origin = d.globalPosition;
        _initialScale = widget.box.scale;
        _startDiag = math.sqrt(
          widget.box.width * widget.box.width +
          widget.box.height * widget.box.height);
      },
      onPanUpdate: (d) {
        final delta = d.globalPosition - _origin;
        final currentDiag = _startDiag + delta.dx; // simple: use dx as proxy
        widget.state.mutateBox(widget.box.id, (b) {
          b.scale = cornerScale(
            startDiag: _startDiag,
            currentDiag: currentDiag,
            initialScale: _initialScale,
          );
        });
      },
      child: const _Dot(color: Colors.deepOrange),
    );
  }
}

class _RotateHandle extends StatefulWidget {
  final AppState state;
  final BoxModel box;
  const _RotateHandle({required this.state, required this.box});
  @override State<_RotateHandle> createState() => _RotateHandleState();
}

class _RotateHandleState extends State<_RotateHandle> {
  Offset? _center;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (d) {
        final box = widget.box;
        // Compute box center in global coords from this widget's box
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null) return;
        final myGlobal = renderBox.localToGlobal(Offset.zero);
        _center = myGlobal + Offset(5, box.height/2 + 30);
      },
      onPanUpdate: (d) {
        final c = _center;
        if (c == null) return;
        widget.state.mutateBox(widget.box.id, (b) {
          b.rotationDeg = rotationAngleDeg(
            centerX: c.dx, centerY: c.dy,
            x: d.globalPosition.dx, y: d.globalPosition.dy,
          );
        });
      },
      child: const _Dot(color: Colors.green),
    );
  }
}
```

- [ ] **Step 4: Wire handles into the box**

Modify `lib/text_box.dart` so handles overlay on the right edge of the rotate→scale→sized stack:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'state.dart';
import 'transform_handles.dart';

class TextBox extends StatelessWidget {
  final AppState state;
  final BoxModel box;
  const TextBox({super.key, required this.state, required this.box});

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedBoxId == box.id;
    return Positioned(
      left: box.x,
      top: box.y,
      child: Transform.rotate(
        angle: box.rotationDeg * 3.1415926535 / 180.0,
        child: Transform.scale(
          scale: box.scale,
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: box.width,
            height: box.height,
            child: Stack(clipBehavior: Clip.none, children: [
              GestureDetector(
                onTap: () => state.select(box.id),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: selected ? Colors.blue : Colors.grey.shade400,
                      width: selected ? 2 : 1,
                    ),
                  ),
                  child: Semantics(
                    identifier: 'box-${box.id}',
                    child: QuillEditor.basic(
                      controller: box.controller,
                      configurations: const QuillEditorConfigurations(
                        padding: EdgeInsets.all(8),
                        autoFocus: false,
                        expands: true,
                      ),
                    ),
                  ),
                ),
              ),
              HandlesOverlay(state: state, box: box),
            ]),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run unit tests**

Run: `flutter test test/transform_math_test.dart`
Expected: all pass.

- [ ] **Step 6: Smoke in browser**

Run: `flutter run -d chrome --web-port=8765`. Click box, drag right side handle → width grows. Drag corner → whole box (including text) scales. Drag rotate handle → box rotates. Stop with `q`.

- [ ] **Step 7: Commit**

```bash
git add lib/transform_handles.dart lib/text_box.dart test/transform_math_test.dart
git commit -m "feat: transform handles (side resize, corner scale, rotate) with math tests"
```

---

## Task 11: Playwright project setup + helpers

**Files:**
- Create: `verify/package.json`, `verify/playwright.config.ts`, `verify/tests/_helpers.ts`

- [ ] **Step 1: Initialize the verify project**

```bash
cd /Users/junyoungyoon/Source/richtext
mkdir -p verify/tests
cd verify
npm init -y
npm i -D @playwright/test typescript
npx playwright install chromium
```

- [ ] **Step 2: Write `verify/playwright.config.ts`**

```ts
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  timeout: 30_000,
  reporter: 'list',
  use: {
    baseURL: 'http://localhost:8000',
    headless: true,
    screenshot: 'only-on-failure',
  },
});
```

- [ ] **Step 3: Write `verify/tests/_helpers.ts`**

```ts
import { Page, expect } from '@playwright/test';

export async function gotoApp(page: Page) {
  await page.goto('/');
  await page.waitForFunction(() => (window as any).__inspector?.state);
}

export async function readState(page: Page): Promise<any> {
  const raw = await page.evaluate(() => (window as any).__inspector.state());
  return JSON.parse(raw);
}

export async function clickTestId(page: Page, id: string) {
  // Flutter Web exposes Semantics(identifier:) as [aria-label=id] in the
  // accessibility tree. Both selectors are tried.
  const sels = [`[id="flt-semantic-node-${id}"]`,
                `[aria-label="${id}"]`, `[data-testid="${id}"]`];
  for (const s of sels) {
    const el = page.locator(s).first();
    if (await el.count()) {
      await el.click();
      return;
    }
  }
  throw new Error(`Could not find element for id=${id}`);
}

export async function focusBoxBody(page: Page, boxId: string) {
  // Click the box body to focus the editor.
  await clickTestId(page, `box-${boxId}`);
}

export async function typeText(page: Page, text: string) {
  await page.keyboard.type(text);
}

export async function selectAll(page: Page) {
  await page.keyboard.press('Meta+A');
  // fallback for non-mac browsers
  await page.keyboard.press('Control+A');
}

export async function dragBy(page: Page, id: string, dx: number, dy: number) {
  const el = page.locator(`[aria-label="${id}"]`).first();
  await el.waitFor();
  const box = await el.boundingBox();
  if (!box) throw new Error(`no bounding box for ${id}`);
  const startX = box.x + box.width/2;
  const startY = box.y + box.height/2;
  await page.mouse.move(startX, startY);
  await page.mouse.down();
  await page.mouse.move(startX + dx, startY + dy, { steps: 10 });
  await page.mouse.up();
}

export async function withApp<T>(page: Page, fn: () => Promise<T>): Promise<T> {
  await gotoApp(page);
  return await fn();
}

export { expect };
```

- [ ] **Step 4: Commit**

```bash
cd /Users/junyoungyoon/Source/richtext
git add verify/package.json verify/package-lock.json verify/playwright.config.ts verify/tests/_helpers.ts .gitignore
echo "verify/node_modules" >> .gitignore
git add .gitignore
git commit -m "chore: playwright project setup + helpers"
```

---

## Task 12: Playwright — run-level spec

**Files:**
- Create: `verify/tests/run.spec.ts`

- [ ] **Step 1: Write the spec**

```ts
import { test, expect, gotoApp, readState, clickTestId,
         focusBoxBody, typeText, selectAll } from './_helpers';

test.describe('Run-level formatting', () => {
  test.beforeEach(async ({ page }) => {
    await gotoApp(page);
    await focusBoxBody(page, '1');
    await typeText(page, 'hello world');
    await selectAll(page);
  });

  test('Bold', async ({ page }) => {
    await clickTestId(page, 'tb-bold');
    const s = await readState(page);
    expect(s.boxes[0].paragraphs[0].runs[0].bold).toBe(true);
    expect(s.boxes[0].selection.resolvedAttrs.bold).toBe(true);
  });

  test('Italic', async ({ page }) => {
    await clickTestId(page, 'tb-italic');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.italic).toBe(true);
  });

  test('Underline', async ({ page }) => {
    await clickTestId(page, 'tb-underline');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.underline).toBe(true);
  });

  test('Strikethrough', async ({ page }) => {
    await clickTestId(page, 'tb-strike');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.strike).toBe(true);
  });

  test('Color (red)', async ({ page }) => {
    await clickTestId(page, 'tb-color');
    await clickTestId(page, 'color-FF0000');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.color.toUpperCase()).toBe('#FF0000');
  });

  test('Highlight (yellow)', async ({ page }) => {
    await clickTestId(page, 'tb-highlight');
    await clickTestId(page, 'hl-FFFF00');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.background.toUpperCase()).toBe('#FFFF00');
  });

  test('Font (NotoSansKR)', async ({ page }) => {
    await clickTestId(page, 'tb-font');
    await clickTestId(page, 'font-NotoSansKR');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.font).toBe('NotoSansKR');
  });

  test('Font size (20)', async ({ page }) => {
    await clickTestId(page, 'tb-size');
    await clickTestId(page, 'size-20');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.size).toBe(20);
  });

  test('Superscript', async ({ page }) => {
    await clickTestId(page, 'tb-superscript');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.script).toBe('super');
  });

  test('Subscript', async ({ page }) => {
    await clickTestId(page, 'tb-subscript');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.script).toBe('sub');
  });
});
```

- [ ] **Step 2: Commit (tests will be run as part of verify.sh later)**

```bash
git add verify/tests/run.spec.ts
git commit -m "test: playwright run-level formatting spec"
```

---

## Task 13: Playwright — paragraph spec

**Files:**
- Create: `verify/tests/paragraph.spec.ts`

- [ ] **Step 1: Write the spec**

```ts
import { test, expect, gotoApp, readState, clickTestId,
         focusBoxBody, typeText, selectAll } from './_helpers';

test.describe('Paragraph-level formatting', () => {
  test.beforeEach(async ({ page }) => {
    await gotoApp(page);
    await focusBoxBody(page, '1');
    await typeText(page, 'one\ntwo');
    await selectAll(page);
  });

  test('Align center', async ({ page }) => {
    await clickTestId(page, 'tb-align-center');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.align).toBe('center');
  });

  test('Align right', async ({ page }) => {
    await clickTestId(page, 'tb-align-right');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.align).toBe('right');
  });

  test('Indent +1', async ({ page }) => {
    await clickTestId(page, 'tb-indent');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.indentLevel).toBe(1);
  });

  test('Outdent stops at 0', async ({ page }) => {
    await clickTestId(page, 'tb-indent');
    await clickTestId(page, 'tb-indent'); // level 2
    await clickTestId(page, 'tb-outdent');
    await clickTestId(page, 'tb-outdent');
    await clickTestId(page, 'tb-outdent'); // should not go below 0
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.indentLevel).toBe(0);
  });

  test('Bullet on', async ({ page }) => {
    await clickTestId(page, 'tb-bullet');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.list).toBe('bullet');
  });
});
```

- [ ] **Step 2: Commit**

```bash
git add verify/tests/paragraph.spec.ts
git commit -m "test: playwright paragraph-level formatting spec"
```

---

## Task 14: Playwright — text box transforms spec

**Files:**
- Create: `verify/tests/textbox.spec.ts`

- [ ] **Step 1: Write the spec**

```ts
import { test, expect, gotoApp, readState, clickTestId,
         dragBy } from './_helpers';

test.describe('Text box transforms', () => {
  test.beforeEach(async ({ page }) => {
    await gotoApp(page);
    await clickTestId(page, 'box-1'); // select box
  });

  test('Side handle right increases width', async ({ page }) => {
    const before = (await readState(page)).boxes[0].width;
    await dragBy(page, 'box-1-handle-side-r', 60, 0);
    const after = (await readState(page)).boxes[0].width;
    expect(after).toBeGreaterThan(before + 30);
  });

  test('Corner handle (br) scales the box', async ({ page }) => {
    const before = (await readState(page)).boxes[0].scale;
    await dragBy(page, 'box-1-handle-corner-br', 120, 120);
    const after = (await readState(page)).boxes[0].scale;
    expect(after).toBeGreaterThan(before);
  });

  test('Rotate handle changes rotationDeg', async ({ page }) => {
    const before = (await readState(page)).boxes[0].rotationDeg;
    await dragBy(page, 'box-1-handle-rotate', 80, 0);
    const after = (await readState(page)).boxes[0].rotationDeg;
    expect(Math.abs(after - before)).toBeGreaterThan(5);
  });
});
```

- [ ] **Step 2: Commit**

```bash
git add verify/tests/textbox.spec.ts
git commit -m "test: playwright text box transforms spec"
```

---

## Task 15: End-to-end verifier script + Windows build smoke

**Files:**
- Create: `scripts/verify.sh`
- Modify: `.gitignore` (build/, .dart_tool/)

- [ ] **Step 1: Write `scripts/verify.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> flutter build web --release"
flutter build web --release

echo "==> serving build/web on :8000"
( cd build/web && python3 -m http.server 8000 ) &
SERVE_PID=$!
trap "kill $SERVE_PID" EXIT

# wait for server
until curl -s http://localhost:8000 >/dev/null; do sleep 0.5; done

echo "==> playwright tests"
cd verify
npx playwright test --reporter=list
```

```bash
chmod +x scripts/verify.sh
```

- [ ] **Step 2: Update `.gitignore`**

Add (if not already present):

```
build/
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
verify/node_modules/
verify/test-results/
verify/playwright-report/
```

- [ ] **Step 3: Run end-to-end**

Run: `bash scripts/verify.sh`
Expected: Flutter web build succeeds; Playwright reports per-feature PASS/FAIL. Any failure is a real feasibility finding for that feature.

- [ ] **Step 4: Windows build smoke (optional but required by spec)**

Run on a Windows machine (or note as TBD if unavailable):

```cmd
flutter build windows
```

Expected: builds without errors. If it fails due to `flutter_quill` Windows config, capture the error in the report — this is itself a feasibility finding (web works, windows blocked) rather than a plan failure.

- [ ] **Step 5: Write a brief verification report**

Create `docs/superpowers/specs/2026-05-19-flutter-richtext-feasibility-report.md` capturing:
- Web build: PASS/FAIL
- Per-feature playwright table (paste reporter output)
- Windows build: PASS/FAIL with error if any
- XFAIL items (rotated IME composition position; hanging indent)

- [ ] **Step 6: Commit**

```bash
git add scripts/verify.sh .gitignore docs/superpowers/specs/2026-05-19-flutter-richtext-feasibility-report.md
git commit -m "feat: end-to-end verifier + report skeleton"
```

---

## Self-Review (post-write)

**Spec coverage:**
- Paragraph align L/C/R → Task 9, paragraph spec (Task 13). ✓
- Indent / Negative-indent (outdent, floor 0) → Task 9, paragraph spec asserts floor at 0. ✓
- Bullet → Task 9 + Task 13. ✓
- Run B/I/U/S → Task 7 + Task 12. ✓
- Color / Highlight → Task 8 + Task 12. ✓
- Font / Size → Task 8 + Task 12. ✓
- Super/Subscript → Task 8 + Task 12. ✓
- Box corner proportional scale → Task 10 + Task 14. ✓
- Box side resize → Task 10 + Task 14. ✓
- Box rotation → Task 10 + Task 14. ✓
- Multiple paragraphs / runs → Task 3 extractor handles, Task 13 types two paragraphs. ✓
- Inspection JSON schema → Task 4 + Task 6 (window.__inspector). ✓
- Web + Windows requirement → flutter_quill chosen, Windows smoke in Task 15. ✓
- Playwright verification → Tasks 11–15. ✓
- XFAIL items (rotated IME, hanging indent) → Documented in Task 15 report. ✓

**Placeholder scan:** No TBD/TODO in steps. Task 9 fallback for `Attribute.getIndentLevel` covers API uncertainty inline. Task 15 Windows smoke can be skipped on a non-Windows machine — explicit handling shown.

**Type/name consistency:** `serializeAppState`, `extractParagraphs`, `BoxModel`, `AppState`, handle ids (`box-{id}-handle-side-{t|r|b|l}`, `box-{id}-handle-corner-{tl|tr|bl|br}`, `box-{id}-handle-rotate`), toolbar ids (`tb-*`, color/hl/font/size sub-ids) all consistent across tasks and specs.
