import { test, expect, gotoApp, readState, clickTestId,
         dragBy } from './_helpers';

test.describe('Text box transforms', () => {
  test.beforeEach(async ({ page }) => {
    await gotoApp(page);
    await clickTestId(page, 'box-1');
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
