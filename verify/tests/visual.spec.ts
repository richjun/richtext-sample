import {
  test, expect, gotoApp, readState, clickTestId,
  clickBoxBody, typeText, selectAll, dragHandle, shot,
} from './_helpers';

test.describe.configure({ mode: 'serial' });

test.describe('User-flow visual verification', () => {
  test('text input + caret focus', async ({ page }) => {
    await gotoApp(page);
    await shot(page, '01-app-loaded');
    await clickBoxBody(page, '1');
    await typeText(page, 'Hello, RichText!');
    await shot(page, '02-typed-text');
    const s = await readState(page);
    const text = s.boxes[0].paragraphs[0].runs.map((r: any) => r.text).join('');
    expect(text).toContain('Hello');
  });

  test('Bold', async ({ page }) => {
    await gotoApp(page);
    await clickBoxBody(page, '1');
    await typeText(page, 'bold me');
    await selectAll(page);
    await shot(page, '03-bold-before');
    await clickTestId(page, 'tb-bold');
    await shot(page, '04-bold-after');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.bold).toBe(true);
    expect(s.boxes[0].paragraphs[0].runs.some((r: any) => r.bold)).toBe(true);
  });

  test('Italic', async ({ page }) => {
    await gotoApp(page);
    await clickBoxBody(page, '1');
    await typeText(page, 'italic me');
    await selectAll(page);
    await clickTestId(page, 'tb-italic');
    await shot(page, '05-italic');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.italic).toBe(true);
    expect(s.boxes[0].paragraphs[0].runs.some((r: any) => r.italic)).toBe(true);
  });

  test('Underline', async ({ page }) => {
    await gotoApp(page);
    await clickBoxBody(page, '1');
    await typeText(page, 'underline me');
    await selectAll(page);
    await clickTestId(page, 'tb-underline');
    await shot(page, '06-underline');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.underline).toBe(true);
    expect(s.boxes[0].paragraphs[0].runs.some((r: any) => r.underline)).toBe(true);
  });

  test('Strikethrough', async ({ page }) => {
    await gotoApp(page);
    await clickBoxBody(page, '1');
    await typeText(page, 'strike me');
    await selectAll(page);
    await clickTestId(page, 'tb-strike');
    await shot(page, '07-strike');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.strike).toBe(true);
    expect(s.boxes[0].paragraphs[0].runs.some((r: any) => r.strike)).toBe(true);
  });

  test('Font color (red)', async ({ page }) => {
    await gotoApp(page);
    await clickBoxBody(page, '1');
    await typeText(page, 'red text');
    await selectAll(page);
    await clickTestId(page, 'tb-color');
    await clickTestId(page, 'color-FF0000');
    await shot(page, '08-color-red');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.color.toUpperCase()).toBe('#FF0000');
    expect(s.boxes[0].paragraphs[0].runs.some(
      (r: any) => (r.color || '').toUpperCase() === '#FF0000')).toBe(true);
  });

  test('Highlight (yellow)', async ({ page }) => {
    await gotoApp(page);
    await clickBoxBody(page, '1');
    await typeText(page, 'highlighted');
    await selectAll(page);
    await clickTestId(page, 'tb-highlight');
    await clickTestId(page, 'hl-FFFF00');
    await shot(page, '09-highlight-yellow');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.background.toUpperCase()).toBe('#FFFF00');
    expect(s.boxes[0].paragraphs[0].runs.some(
      (r: any) => (r.background || '').toUpperCase() === '#FFFF00')).toBe(true);
  });

  test('Font family (NotoSansKR)', async ({ page }) => {
    await gotoApp(page);
    await clickBoxBody(page, '1');
    await typeText(page, '폰트 변경');
    await selectAll(page);
    await clickTestId(page, 'tb-font');
    await clickTestId(page, 'font-NotoSansKR');
    await shot(page, '10-font-NotoSansKR');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.font).toBe('NotoSansKR');
    expect(s.boxes[0].paragraphs[0].runs.some(
      (r: any) => r.font === 'NotoSansKR')).toBe(true);
  });

  test('Font size (20)', async ({ page }) => {
    await gotoApp(page);
    await clickBoxBody(page, '1');
    await typeText(page, 'BIG');
    await selectAll(page);
    await clickTestId(page, 'tb-size');
    await clickTestId(page, 'size-20');
    await shot(page, '11-size-20');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.size).toBe(20);
    expect(s.boxes[0].paragraphs[0].runs.some((r: any) => r.size === 20)).toBe(true);
  });

  test('Superscript', async ({ page }) => {
    await gotoApp(page);
    await clickBoxBody(page, '1');
    await typeText(page, 'x2');
    await selectAll(page);
    await clickTestId(page, 'tb-superscript');
    await shot(page, '12-superscript');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.script).toBe('super');
  });

  test('Subscript', async ({ page }) => {
    await gotoApp(page);
    await clickBoxBody(page, '1');
    await typeText(page, 'H2O');
    await selectAll(page);
    await clickTestId(page, 'tb-subscript');
    await shot(page, '13-subscript');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.script).toBe('sub');
  });

  test('Align center', async ({ page }) => {
    await gotoApp(page);
    await clickBoxBody(page, '1');
    await typeText(page, 'centered');
    await selectAll(page);
    await clickTestId(page, 'tb-align-center');
    await shot(page, '14-align-center');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.align).toBe('center');
    expect(s.boxes[0].paragraphs[0].align).toBe('center');
  });

  test('Align right', async ({ page }) => {
    await gotoApp(page);
    await clickBoxBody(page, '1');
    await typeText(page, 'right side');
    await selectAll(page);
    await clickTestId(page, 'tb-align-right');
    await shot(page, '15-align-right');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.align).toBe('right');
    expect(s.boxes[0].paragraphs[0].align).toBe('right');
  });

  test('Indent +1 and outdent floors at 0', async ({ page }) => {
    await gotoApp(page);
    await clickBoxBody(page, '1');
    await typeText(page, 'indent me');
    await selectAll(page);
    await clickTestId(page, 'tb-indent');
    await shot(page, '16-indent-1');
    let s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.indentLevel).toBe(1);
    await clickTestId(page, 'tb-indent');
    s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.indentLevel).toBe(2);
    await shot(page, '17-indent-2');
    await clickTestId(page, 'tb-outdent');
    await clickTestId(page, 'tb-outdent');
    await clickTestId(page, 'tb-outdent'); // extra — should still be 0
    s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.indentLevel).toBe(0);
    await shot(page, '18-outdent-floor-0');
  });

  test('Bullet', async ({ page }) => {
    await gotoApp(page);
    await clickBoxBody(page, '1');
    await typeText(page, 'item');
    await selectAll(page);
    await clickTestId(page, 'tb-bullet');
    await shot(page, '19-bullet');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.list).toBe('bullet');
    expect(s.boxes[0].paragraphs[0].list).toBe('bullet');
  });

  // Multi-paragraph / multi-run case from the spec ("paragraph와 run은 멀티로 들어갈수있다")
  test('multiple paragraphs and runs', async ({ page }) => {
    await gotoApp(page);
    await clickBoxBody(page, '1');
    await typeText(page, 'first line');
    await page.keyboard.press('Enter');
    await typeText(page, 'second line');
    await shot(page, '20-two-paragraphs');
    const s = await readState(page);
    expect(s.boxes[0].paragraphs.length).toBeGreaterThanOrEqual(2);
  });

  // ---- Text box transforms ----

  test('Side handle right increases width', async ({ page }) => {
    await gotoApp(page);
    // Box is already selected at startup so handles are visible.
    const before = (await readState(page)).boxes[0].width;
    await shot(page, '21-resize-before');
    await dragHandle(page, 'box-1-handle-side-r', 80, 0);
    await shot(page, '22-resize-after');
    const after = (await readState(page)).boxes[0].width;
    expect(after).toBeGreaterThan(before + 20);
  });

  test('Corner handle (br) proportional scale', async ({ page }) => {
    await gotoApp(page);
    const before = (await readState(page)).boxes[0].scale;
    await shot(page, '23-scale-before');
    await dragHandle(page, 'box-1-handle-corner-br', 100, 100);
    await shot(page, '24-scale-after');
    const after = (await readState(page)).boxes[0].scale;
    expect(after).toBeGreaterThan(before);
  });

  test('Rotate handle changes rotationDeg', async ({ page }) => {
    await gotoApp(page);
    const before = (await readState(page)).boxes[0].rotationDeg;
    await shot(page, '25-rotate-before');
    await dragHandle(page, 'box-1-handle-rotate', 100, 30);
    await shot(page, '26-rotate-after');
    const after = (await readState(page)).boxes[0].rotationDeg;
    expect(Math.abs(after - before)).toBeGreaterThan(5);
  });
});
