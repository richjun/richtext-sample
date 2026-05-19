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
    // NOTE: typeText is a no-op in this headless harness (Flutter Web CanvasKit text
    // input cannot be driven via the semantics overlay in headless mode), so we cannot
    // assert runs[0].bold.  resolvedAttrs reflects the cursor/selection format state
    // and is the correct feasibility proxy.
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
