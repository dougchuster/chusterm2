import { chromium } from '@playwright/test';
import fs from 'node:fs';

const OUT = 'C:/Users/dougc/AppData/Local/Temp/opencode/shots';
fs.mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch();
// Recreate the QA user session: fresh login each run
const ctx = await browser.newContext({
  viewport: { width: 1366, height: 768 },
  colorScheme: 'dark',
  locale: 'pt-BR',
});
const page = await ctx.newPage();
await page.goto('http://127.0.0.1:8086/app/login');
await page.getByLabel(/e-?mail/i).fill('qa-visual@chusterm.invalid');
await page.getByLabel(/^(senha|password)$/i).fill('QaVisual12345678!');
await page.getByRole('button', { name: /entrar|sign in|login/i }).click().catch(() => {});
await page.waitForTimeout(4000);
console.log('URL:', page.url());
await page.goto('http://127.0.0.1:8086/app/accounts/1/dashboard');
await page.waitForTimeout(7000);
await page.screenshot({ path: OUT + '/conv-dark.png' });
const info = await page.evaluate(() => {
  const dark = document.documentElement.classList.contains('dark');
  const spans = [...document.querySelectorAll('span[role="img"]')].slice(0, 2);
  return {
    dark,
    avatars: spans.map(s => ({
      cls: s.className.slice(0, 220),
      outline: getComputedStyle(s).outlineStyle + '/' + getComputedStyle(s).outlineWidth,
      boxShadow: getComputedStyle(s).boxShadow.slice(0, 100),
      radius: getComputedStyle(s).borderRadius,
      bg: getComputedStyle(s).backgroundColor,
    })),
  };
});
console.log(JSON.stringify(info, null, 1));
await browser.close();
console.log('DONE');
