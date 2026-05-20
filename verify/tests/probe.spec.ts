import { test, gotoApp, clickBoxBody, readState, readLayout, typeText, shot } from './_helpers';

test('full in/out/in cycle with selection', async ({ page }) => {
  await gotoApp(page);

  // Phase 1: focus + type + select text
  await clickBoxBody(page, '1');
  await typeText(page, 'hello world');
  await page.keyboard.press('Home');
  for (let i = 0; i < 5; i++) await page.keyboard.press('Shift+ArrowRight');
  await page.waitForTimeout(200);
  const s1 = await readState(page);
  console.log('Phase 1 (inside, selected text):', JSON.stringify({
    sel: `${s1.selection.offsetStart}-${s1.selection.offsetEnd}`,
  }));
  await shot(page, '1-after-select');

  // Phase 2: click outside
  await page.mouse.click(900, 500);
  await page.waitForTimeout(400);
  const s2 = await readState(page);
  const dom2 = await page.evaluate(() => ({
    active: document.activeElement?.tagName,
    hasTextarea: !!document.querySelector('flt-text-editing-host textarea'),
  }));
  console.log('Phase 2 (after outside):', JSON.stringify({
    sel: `${s2.selection.offsetStart}-${s2.selection.offsetEnd}`,
    ...dom2,
  }));
  await shot(page, '2-after-outside');

  // Phase 3: click inside again
  await clickBoxBody(page, '1', 50, 50);
  await page.waitForTimeout(400);
  const s3 = await readState(page);
  const dom3 = await page.evaluate(() => ({
    active: document.activeElement?.tagName,
    hasTextarea: !!document.querySelector('flt-text-editing-host textarea'),
  }));
  console.log('Phase 3 (back inside):', JSON.stringify({
    sel: `${s3.selection.offsetStart}-${s3.selection.offsetEnd}`,
    ...dom3,
  }));
  await shot(page, '3-back-inside');

  // Phase 4: type more text to confirm input still works after the cycle
  await typeText(page, ' AGAIN');
  await page.waitForTimeout(300);
  const s4 = await readState(page);
  console.log('Phase 4 (text after cycle):', JSON.stringify({
    text: s4.paragraphs[0].runs.map((r: any) => r.text).join(''),
  }));
  await shot(page, '4-typed-after-cycle');
});
