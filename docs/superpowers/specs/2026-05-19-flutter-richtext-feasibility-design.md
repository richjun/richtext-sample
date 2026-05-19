# Flutter Web Rich Text Feasibility — Design Spec

- **Date:** 2026-05-19
- **Goal:** Verify whether Flutter Web 3.24.x can implement a PowerPoint-style text box with rich paragraph/run formatting and box-level transforms. Produce a small test app and an automated playwright report.
- **Target platforms:** Web (verification target), Windows (required for any chosen external package).
- **Local Flutter:** 3.24.0 (treated as equivalent to 3.24.3 for verification).

## 1. Scope

### In scope
Build a small Flutter Web/Windows test app with:

**Paragraph-level**
- Text alignment: Left / Center / Right
- Indentation (들여쓰기)
- Negative indentation = outdent (들여쓰기 레벨을 한 단계 감소, 하한 0). Hanging indent (텍스트가 마진보다 왼쪽으로 튀어나가는 형태)는 별도 명시로 **not supported / out of scope**.
- Bullet (•)

**Run-level**
- Font family (앱에 등록된 셋 중 선택: Roboto, NotoSansKR, Courier)
- Font size
- Font color
- Highlight (background color)
- Bold / Italic / Underline / Strikethrough
- Superscript / Subscript

**Text Box (object)**
- Corner handle drag = proportional scale of the whole box (텍스트도 함께 확대됨, `Transform.scale`)
- Side handle drag = box width/height resize (텍스트 reflow, Quill 너비만 변경)
- Rotation handle (`Transform.rotate`)

Paragraphs와 runs는 모두 멀티 인스턴스를 지원해야 한다.

### Out of scope
- True hanging indent (negative margin past 0).
- Polished UX (focus rings, snap, smart guides, multi-select, undo/redo, copy/paste 정교화).
- 모바일 빌드, 접근성 전반.
- 임의 폰트 로딩 (pubspec에 미리 등록한 셋만).

## 2. Architecture

Slide-canvas + transformable text box object model.

```
┌─────────────────────────────────────────────────────┬────────────────┐
│  Canvas (Stack)                                      │ Inspection     │
│  ┌──────────────────┐   ┌──────────────────┐         │ Panel          │
│  │ TextBox(rotated) │   │ TextBox          │         │ <div data-     │
│  │  ┌────────────┐  │   │  ...             │         │  testid=       │
│  │  │ Quill      │  │   │                  │         │  "state-json"> │
│  │  │ Editor     │  │   │                  │         │  {…}           │
│  │  └────────────┘  │   │                  │         │ </div>         │
│  │ ◯——◯——◯ handles  │   │                  │         │                │
│  └──────────────────┘   └──────────────────┘         │                │
│                                                      │                │
│  Top toolbar: B I U S, color, highlight, sub/sup,    │                │
│  align L/C/R, indent +/–, bullet, font, size         │                │
└─────────────────────────────────────────────────────┴────────────────┘
```

### Components
- **CanvasPage** — root `Stack`; owns app state (boxes, selectedBoxId). Holds the toolbar (top), canvas (center), inspection panel (right).
- **TextBox** — `Positioned` → `Transform.rotate(rotationDeg)` → `Transform.scale(scale)` → `SizedBox(width,height)` → `QuillEditor`. Box is selectable; selecting reveals handles.
- **TransformHandles** — 8 resize handles (4 corner, 4 side) + 1 rotate handle. `GestureDetector`로 드래그하면 박스 모델을 갱신.
- **RichToolbar** — flutter_quill의 `QuillSimpleToolbar`를 그대로 쓰지 않고, 필요한 버튼만 직접 배치해 `data-testid` semantics를 부여. 각 버튼은 현재 선택 박스의 `QuillController`를 통해 속성을 토글.
- **InspectionPanel** — 상태 모델의 단방향 직렬화. 매 상태 변경마다 즉시 갱신.
- **AppState** — 박스 리스트 + 선택 상태 + 박스별 `QuillController` 보관. `ChangeNotifier`.

### Handle behavior (PowerPoint 관례 채택)
- **Corner handle**: drag delta → `scale *= newDist / origDist` (proportional). 텍스트가 같이 확대된다.
- **Side handle**: drag delta → `width`/`height` 변경. Quill의 너비만 바뀌고 텍스트는 reflow.
- **Rotate handle**: 박스 중심 기준 각도 계산 → `rotationDeg`. `Transform.rotate`만 갱신.

## 3. Feature → Implementation Mapping

| 카테고리 | 기능 | 구현 경로 | 위험/주의 |
|---|---|---|---|
| Paragraph | Align L/C/R | Quill `align` 블록 속성 | 안정 |
| Paragraph | Indent | Quill `indent` 블록 속성 (level 1..N) | 안정 |
| Paragraph | Negative Indent (outdent) | Quill `indent` 레벨 감소 (하한 0) | 안정. hanging indent는 not supported. |
| Paragraph | Bullet | Quill `list: bullet` | 안정 |
| Run | Bold/Italic/Underline/Strike | `b`/`i`/`u`/`s` | 안정 |
| Run | Font Color | `color` (#RRGGBB) | 안정 |
| Run | Highlight | `background` | 안정 |
| Run | Font Type | `font` — 앱에 미리 등록한 폰트 셋에서 선택 | 등록된 셋만 검증 |
| Run | Font Size | `size` (pt) | 안정 |
| Run | Superscript / Subscript | `script: super` / `sub` (flutter_quill ≥ 9) | CanvasKit에서 baseline shift 표시 정상 여부 별도 확인 — 검증 항목 |
| Box | 코너 드래그 (proportional scale) | `Transform.scale` 박스 전체 | 텍스트 함께 확대 |
| Box | 사이드 드래그 (resize) | 박스 width/height → Quill reflow | 안정 |
| Box | 회전 | `Transform.rotate` | 캐럿 hit-test OK 예상. IME composition box 위치는 unrotated일 수 있음 — 입력 자체는 동작, 그래픽만 어색할 수 있음. **XFAIL 항목**. |

### 외부 패키지
- `flutter_quill` (≥ 10.x) — Web + Windows 공식 지원. 본 앱의 리치 텍스트 엔진.
- 그 외 추가 RTE 패키지 없음.

## 4. Inspection Panel JSON Schema

`<div data-testid="state-json">` 안에 직렬화된 단일 JSON 문자열을 둔다. 매 상태 변경마다 즉시 갱신.

```json
{
  "selectedBoxId": "box-1",
  "boxes": [
    {
      "id": "box-1",
      "x": 120, "y": 80,
      "width": 360, "height": 180,
      "scale": 1.0,
      "rotationDeg": 0,
      "paragraphs": [
        {
          "align": "left",
          "indentLevel": 0,
          "list": "none",
          "runs": [
            {
              "text": "Hello ",
              "bold": false, "italic": false, "underline": false, "strike": false,
              "color": "#000000",
              "background": null,
              "font": "Roboto",
              "size": 14,
              "script": "none"
            }
          ]
        }
      ],
      "selection": {
        "paragraphIndex": 0,
        "runIndex": 1,
        "offsetStart": 0,
        "offsetEnd": 5,
        "resolvedAttrs": {
          "bold": true, "italic": false, "underline": false, "strike": false,
          "color": "#000000", "background": null,
          "font": "Roboto", "size": 14, "script": "none",
          "align": "left", "indentLevel": 0, "list": "none"
        }
      }
    }
  ]
}
```

### Field semantics
- `align`: `"left" | "center" | "right"`
- `indentLevel`: 0..N integer
- `list`: `"none" | "bullet"`
- `script`: `"none" | "super" | "sub"`
- `color`/`background`: `"#RRGGBB"` or `null`
- `scale`: float, default 1.0
- `rotationDeg`: float, 0–360 (음수 허용)
- `selection.resolvedAttrs`: 현재 캐럿/선택 위치에서 적용 중인 속성. "방금 토글한 게 진짜 먹었나" 시점 검증용.

### Update triggers
- Quill `DocumentChangeNotification` (텍스트/속성 변경)
- 선택 영역 변경
- 박스 드래그/스케일/회전 완료
- 박스 선택 전환

## 5. Test ID Conventions

Flutter Web에서 위젯에 testid를 붙이려면 `Semantics(identifier:)`로 라벨링하고 앱 시작 시 `SemanticsBinding.instance.ensureSemantics()`를 호출. (HTML accessibility 트리에 노출.)

```
Toolbar:
  tb-bold / tb-italic / tb-underline / tb-strike
  tb-align-left / tb-align-center / tb-align-right
  tb-indent / tb-outdent / tb-bullet
  tb-color  (opens picker)   →   color-FF0000, color-00FF00, ...
  tb-highlight                →   hl-FFFF00, hl-00FFFF, ...
  tb-font                     →   font-Roboto, font-NotoSansKR, font-Courier
  tb-size                     →   size-12, size-14, size-20
  tb-superscript / tb-subscript

Box:
  box-{id}
  box-{id}-handle-corner-tl / -tr / -bl / -br
  box-{id}-handle-side-t / -r / -b / -l
  box-{id}-handle-rotate

Inspection:
  state-json     ← <div>의 innerText가 JSON 문자열
```

### Fallback
Semantics 경로가 막힐 경우 → 글로벌 `window.__inspector`를 노출시켜 `page.evaluate('window.__inspector.click("tb-bold")')`로 우회. 동일 효과.

## 6. Playwright Verification Plan

### Layout
```
richtext/
├── pubspec.yaml                      # Flutter Web + Windows
├── lib/
│   ├── main.dart
│   ├── canvas_page.dart
│   ├── text_box.dart
│   ├── transform_handles.dart
│   ├── rich_toolbar.dart
│   ├── inspection_panel.dart
│   └── state.dart
├── fonts/                            # Roboto, NotoSansKR, Courier
├── verify/                           # playwright 프로젝트
│   ├── package.json                  # @playwright/test
│   ├── playwright.config.ts
│   └── tests/
│       ├── _helpers.ts               # readState, clickToolbar, selectRunRange
│       ├── paragraph.spec.ts
│       ├── run.spec.ts
│       └── textbox.spec.ts
└── scripts/
    └── verify.sh                     # build web → serve → playwright test
```

### Run flow (`scripts/verify.sh`)
1. `flutter build web --release` (Semantics enable build)
2. `python3 -m http.server 8000 -d build/web &`
3. `cd verify && npx playwright test --reporter=list`
4. 결과 리포트 → 기능별 PASS / FAIL / XFAIL

### Per-feature test pattern
```ts
test('Bold toggles on selected range', async ({ page }) => {
  await selectRunRange(page, 'box-1', { para: 0, run: 0, start: 0, end: 5 });
  await page.getByTestId('tb-bold').click();
  const state = await readState(page);
  expect(state.boxes[0].paragraphs[0].runs[0].bold).toBe(true);
  expect(state.boxes[0].selection.resolvedAttrs.bold).toBe(true);
});
```

### Test inventory
- `paragraph.spec.ts` — align L/C/R, indent, outdent (level 1→0 = stop), bullet on/off.
- `run.spec.ts` — bold, italic, underline, strike, color (red), highlight (yellow), font switch (NotoSansKR), size (20), superscript, subscript.
- `textbox.spec.ts` — corner-tl drag (scale ↓/↑), side-r drag (width ↑), rotate handle (45°), with ±1 tolerance on numeric fields.

### XFAIL items (사전 명시)
- 회전 박스 내 IME composition box 위치 — 입력은 OK, 그래픽만 어색할 수 있음. 시각 확인 항목으로 분리.
- 진짜 hanging indent — Quill로 불가능, "not supported" 결론으로 보고.

## 7. Open Risks / Verification Targets
- **CanvasKit에서 sub/sup baseline shift** — 실제로 위/아래로 그려지는지 검증 필요.
- **Transform.rotate + Quill caret hit-testing** — 회전 박스에서 클릭으로 캐럿 위치가 맞게 잡히는지.
- **Transform.scale + Quill gestures** — 스케일된 박스 내 텍스트 선택/캐럿이 정확한지.
- **Semantics(identifier:) 노출** — playwright의 `getByTestId`가 Flutter Web에서 안정적으로 동작하는지. 폴백 글로벌 인스펙터 준비.
- **Windows 빌드 통과 여부** — 검증은 Web으로만 하되 `flutter build windows`는 패키지 호환성 스모크 체크로 1회 실행해 통과시킴.

## 8. Deliverables
1. 동작하는 Flutter Web 앱 (`flutter run -d chrome`).
2. `scripts/verify.sh` 1회 실행으로 빌드 + 서브 + playwright 테스트 통과.
3. 본 spec 옆에 verification report (PASS/FAIL/XFAIL 표).
4. `flutter build windows` 통과 여부 1회 보고.
