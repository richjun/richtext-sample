import { Page, expect, test } from '@playwright/test';

export async function gotoApp(page: Page) {
  await page.goto('/');
  await page.waitForFunction(() => (window as any).__inspector?.state, { timeout: 30_000 });
  await page.waitForFunction(() => (window as any).__inspector?.layout, { timeout: 5_000 });
  await page.waitForTimeout(400);
}

export async function readState(page: Page): Promise<any> {
  const raw = await page.evaluate(() => (window as any).__inspector.state());
  return JSON.parse(raw);
}

// Get bounding box of a registered element by its testid.
export async function readLayout(page: Page, id: string): Promise<{x:number,y:number,width:number,height:number}> {
  const layoutJson = await page.evaluate(() => (window as any).__inspector.layout());
  const layout = JSON.parse(layoutJson);
  if (!layout[id]) {
    throw new Error(`Layout for id "${id}" not found. Available: ${Object.keys(layout).join(', ')}`);
  }
  return layout[id];
}

// Wait until a registered id appears in the layout (e.g., a popup menu item
// that's only mounted after the parent is clicked).
async function waitForLayout(page: Page, id: string, timeout = 5_000): Promise<{x:number,y:number,width:number,height:number}> {
  const t0 = Date.now();
  while (Date.now() - t0 < timeout) {
    const layoutJson = await page.evaluate(() => (window as any).__inspector.layout());
    const layout = JSON.parse(layoutJson);
    if (layout[id]) return layout[id];
    await page.waitForTimeout(50);
  }
  throw new Error(`Timeout waiting for layout for id "${id}"`);
}

// Click the center of a registered element (toolbar button, popup item, etc).
export async function clickTestId(page: Page, id: string) {
  const r = await waitForLayout(page, id);
  await page.mouse.click(r.x + r.width / 2, r.y + r.height / 2);
  await page.waitForTimeout(80);
}

// Click somewhere inside the box body (focus the editor).
export async function clickBoxBody(page: Page, boxId: string, offX = 30, offY = 30) {
  const r = await waitForLayout(page, `box-${boxId}`);
  await page.mouse.click(r.x + offX, r.y + offY);
  await page.waitForTimeout(200);
}

export async function typeText(page: Page, text: string) {
  await page.keyboard.type(text, { delay: 25 });
}

export async function selectAll(page: Page) {
  // ControlOrMeta maps to Cmd on macOS and Ctrl on Windows/Linux, so this
  // selects all on every platform. (Pressing a literal Control+A on macOS
  // instead moves the caret to line start, collapsing the selection.)
  await page.keyboard.press('ControlOrMeta+A');
  await page.waitForTimeout(80);
}

// Drag a registered handle by (dx, dy) pixels.
export async function dragHandle(page: Page, handleId: string, dx: number, dy: number) {
  const r = await waitForLayout(page, handleId);
  const cx = r.x + r.width / 2;
  const cy = r.y + r.height / 2;
  await page.mouse.move(cx, cy);
  await page.mouse.down();
  for (let i = 1; i <= 20; i++) {
    await page.mouse.move(cx + (dx * i) / 20, cy + (dy * i) / 20);
    await page.waitForTimeout(10);
  }
  await page.mouse.up();
  await page.waitForTimeout(200);
}

// Take a labeled screenshot and attach it to the test report.
export async function shot(page: Page, label: string) {
  const buf = await page.screenshot({ fullPage: false });
  await test.info().attach(label, { body: buf, contentType: 'image/png' });
}

export { test, expect };
