import { chromium } from '@playwright/test';
import fs from 'node:fs';

const OUT = 'C:/Users/dougc/AppData/Local/Temp/opencode/shots';
fs.mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1366, height: 768 } });
await page.goto('http://127.0.0.1:8086/app/login');
await page.waitForTimeout(5000);
await page.screenshot({ path: OUT + '/login-new.png' });
const lockup = await page.evaluate(() => {
  const el = document.querySelector('.custom-logo');
  if (!el) return null;
  const r = el.getBoundingClientRect();
  return { x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) };
});
console.log('LOCKUP:', JSON.stringify(lockup));
if (lockup) {
  await page.screenshot({
    path: OUT + '/login-logo-zoom.png',
    clip: { x: Math.max(0, lockup.x - 30), y: Math.max(0, lockup.y - 20), width: lockup.w + 120, height: lockup.h + 60 },
  });
}
await browser.close();
console.log('DONE');
