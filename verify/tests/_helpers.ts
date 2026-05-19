import { Page, expect, test } from '@playwright/test';

export async function gotoApp(page: Page) {
  await page.goto('/');
  // Wait for the Flutter web build to register the inspector bridge.
  await page.waitForFunction(() => (window as any).__inspector?.state, { timeout: 15_000 });
}

export async function readState(page: Page): Promise<any> {
  const raw = await page.evaluate(() => (window as any).__inspector.state());
  return JSON.parse(raw);
}

// Flutter Web (HTML renderer / CanvasKit) exposes Semantics(identifier:) as the
// attribute `flt-semantics-identifier` on <flt-semantics> elements.
//
// For Semantics(button:true) nodes the clickable leaf is a sibling flt-semantics
// with `flt-tappable` and `pointer-events: all`. For popup-menu items the
// `flt-semantics-identifier` node may NOT be in the DOM until the popup is open,
// so we wait up to 5 s for it to appear before clicking.
export async function clickTestId(page: Page, id: string) {
  // Wait for the element to appear in the DOM (handles popup items that aren't visible
  // until the parent popup button is clicked).
  await page.waitForFunction(
    (id: string) => !!document.querySelector(`[flt-semantics-identifier="${id}"]`),
    id,
    { timeout: 5_000 },
  );

  const coords = await page.evaluate((id: string) => {
    // Find the node that carries the identifier attribute.
    const el = document.querySelector(`[flt-semantics-identifier="${id}"]`);
    if (!el) return null;

    // For Semantics(button:true) toolbar items the actual tappable leaf is a
    // child with the `flt-tappable` attribute.
    const tappable = el.querySelector('[flt-tappable]') as HTMLElement | null;
    const target = (tappable || el) as HTMLElement;
    const rect = target.getBoundingClientRect();
    return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 };
  }, id);

  if (!coords) throw new Error(`Could not find element for id=${id}`);
  await page.mouse.click(coords.x, coords.y);
}

// Clicks the body of a text box by its box ID.
// The Dart code wraps the QuillEditor in Semantics(identifier: 'box-${box.id}'),
// so box with id='box-1' gets identifier 'box-box-1'.
export async function focusBoxBody(page: Page, boxId: string) {
  await clickTestId(page, `box-box-${boxId}`);
}

export async function typeText(page: Page, text: string) {
  // NOTE: In Flutter Web (CanvasKit / HTML renderer) keyboard events do not
  // reach the QuillEditor text content via the Playwright keyboard API when
  // running headless. The flt-glass-pane has no bounding box and the
  // flt-semantics text-field activation does not trigger the
  // flt-text-editing-host in a headless browser environment.
  // typeText is kept for API compatibility but has no effect in this harness.
  await page.keyboard.type(text);
}

export async function selectAll(page: Page) {
  // Try both macOS and other-platform shortcuts.
  await page.keyboard.press('Meta+A');
  await page.keyboard.press('Control+A');
}

// Drags an element identified by its flt-semantics-identifier.
// The handle nodes sit in the semantics overlay with pointer-events:all so their
// bounding rect is the correct drag origin. For box handle identifiers the naming
// convention in the Dart code is 'box-${box.id}-handle-*' (e.g. 'box-box-1-handle-side-r').
export async function dragBy(page: Page, id: string, dx: number, dy: number) {
  const coords = await page.evaluate((id: string) => {
    const el = document.querySelector(`[flt-semantics-identifier="${id}"]`);
    if (!el) return null;
    const rect = el.getBoundingClientRect();
    return { x: rect.left + rect.width / 2, y: rect.top + rect.height / 2 };
  }, id);

  if (!coords) throw new Error(`Could not find element for id=${id}`);
  const { x, y } = coords;
  await page.mouse.move(x, y);
  await page.mouse.down();
  await page.mouse.move(x + dx, y + dy, { steps: 10 });
  await page.mouse.up();
}

export { expect, test };
