import { defineConfig, devices } from '@playwright/test';

const authFile = (persona: string) => `playwright/.auth/${persona}.json`;
const baseURL = process.env.QA_BASE_URL ?? 'http://127.0.0.1:8086';

export default defineConfig({
  testDir: './tests',
  outputDir: 'test-results',
  fullyParallel: true,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 2 : undefined,
  reporter: [
    ['line'],
    ['html', { outputFolder: 'playwright-report', open: 'never' }],
  ],
  use: {
    baseURL,
    locale: 'pt-BR',
    timezoneId: 'America/Sao_Paulo',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },
  projects: [
    {
      name: 'auth-setup',
      testMatch: /auth\.setup\.ts/,
    },
    {
      name: 'chromium-desktop',
      use: { ...devices['Desktop Chrome'], viewport: { width: 1366, height: 768 }, storageState: authFile('admin') },
      dependencies: ['auth-setup'],
      testIgnore: /auth\.setup\.ts/,
    },
    {
      name: 'firefox-desktop',
      use: { ...devices['Desktop Firefox'], viewport: { width: 1366, height: 768 }, storageState: authFile('admin') },
      dependencies: ['auth-setup'],
      testIgnore: /auth\.setup\.ts/,
    },
    {
      name: 'webkit-desktop',
      use: { ...devices['Desktop Safari'], viewport: { width: 1366, height: 768 }, storageState: authFile('admin') },
      dependencies: ['auth-setup'],
      testIgnore: /auth\.setup\.ts/,
    },
    ...[
      ['viewport-mobile-small', 360, 800],
      ['viewport-tablet', 768, 1024],
      ['viewport-notebook-small', 1024, 768],
      ['viewport-wide', 1920, 1080],
    ].map(([name, width, height]) => ({
      name: String(name),
      use: {
        ...devices['Desktop Chrome'],
        viewport: { width: Number(width), height: Number(height) },
        storageState: authFile('admin'),
      },
      dependencies: ['auth-setup'],
      testIgnore: /auth\.setup\.ts/,
    })),
  ],
});
