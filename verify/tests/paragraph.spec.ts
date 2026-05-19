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
    await clickTestId(page, 'tb-indent');
    await clickTestId(page, 'tb-outdent');
    await clickTestId(page, 'tb-outdent');
    await clickTestId(page, 'tb-outdent');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.indentLevel).toBe(0);
  });

  test('Bullet on', async ({ page }) => {
    await clickTestId(page, 'tb-bullet');
    const s = await readState(page);
    expect(s.boxes[0].selection.resolvedAttrs.list).toBe('bullet');
  });
});
