import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  timeout: 60_000,
  reporter: [['list'], ['html', { open: 'never', outputFolder: 'playwright-report' }]],
  workers: 1, // serialize so user can watch one browser
  use: {
    baseURL: 'http://localhost:8765',
    headless: false,
    launchOptions: { slowMo: 250 },
    viewport: { width: 1400, height: 900 },
    video: 'on',
    screenshot: 'on',
    trace: 'retain-on-failure',
  },
});
