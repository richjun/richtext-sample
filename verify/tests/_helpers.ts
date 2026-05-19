import { Page, expect } from '@playwright/test';

export async function gotoApp(page: Page) {
  await page.goto('/');
  // Wait for the Flutter web build to register the inspector bridge.
  await page.waitForFunction(() => (window as any).__inspector?.state, { timeout: 15_000 });
}

export async function readState(page: Page): Promise<any> {
  const raw = await page.evaluate(() => (window as any).__inspector.state());
  return JSON.parse(raw);
}

export async function clickTestId(page: Page, id: string) {
  // Flutter Web exposes Semantics(identifier:) primarily as [aria-label=id] in
  // the accessibility tree. Try a few selector forms.
  const sels = [
    `[aria-label="${id}"]`,
    `[id="flt-semantic-node-${id}"]`,
    `[data-testid="${id}"]`,
  ];
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
  await clickTestId(page, `box-${boxId}`);
}

export async function typeText(page: Page, text: string) {
  await page.keyboard.type(text);
}

export async function selectAll(page: Page) {
  // Try both macOS and other-platform shortcuts.
  await page.keyboard.press('Meta+A');
  await page.keyboard.press('Control+A');
}

export async function dragBy(page: Page, id: string, dx: number, dy: number) {
  const el = page.locator(`[aria-label="${id}"]`).first();
  await el.waitFor();
  const box = await el.boundingBox();
  if (!box) throw new Error(`no bounding box for ${id}`);
  const startX = box.x + box.width / 2;
  const startY = box.y + box.height / 2;
  await page.mouse.move(startX, startY);
  await page.mouse.down();
  await page.mouse.move(startX + dx, startY + dy, { steps: 10 });
  await page.mouse.up();
}

export { expect };
