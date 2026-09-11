import { chromium } from '@playwright/test';
import fs from 'node:fs';

const OUT = 'C:/Users/dougc/AppData/Local/Temp/opencode/shots';
fs.mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1366, height: 768 } });
page.on('console', m => { if (m.type() === 'error') console.log('[console.error]', m.text().slice(0, 200)); });

await page.goto('http://127.0.0.1:8086/app/login');
await page.getByLabel(/e-?mail/i).fill('qa-visual@chusterm.invalid');
await page.getByLabel(/^(senha|password)$/i).fill('QaVisual12345678!');
await page.getByRole('button', { name: /entrar|sign in|login/i }).click();
await page.waitForURL(u => !u.pathname.startsWith('/app/login'), { timeout: 30000 });
console.log('LOGIN OK ->', page.url());

// 1. Conversation list (dashboard landing)
await page.goto('http://127.0.0.1:8086/app/accounts/1/dashboard');
await page.waitForTimeout(6000);
await page.screenshot({ path: OUT + '/conv-list.png' });
const avatarInfo = await page.evaluate(() => {
  const spans = [...document.querySelectorAll('span[role="img"]')].slice(0, 3);
  return spans.map(s => ({
    cls: s.className,
    outline: getComputedStyle(s).outlineStyle + ' ' + getComputedStyle(s).outlineWidth + ' ' + getComputedStyle(s).outlineColor,
    boxShadow: getComputedStyle(s).boxShadow.slice(0, 120),
    borderRadius: getComputedStyle(s).borderRadius,
  }));
});
console.log('AVATARS:', JSON.stringify(avatarInfo, null, 1));

// 2. Kanban toolbar
await page.goto('http://127.0.0.1:8086/app/accounts/1/crm?pipeline_id=1');
await page.waitForTimeout(8000);
await page.screenshot({ path: OUT + '/kanban.png', fullPage: false });
const selectInfo = await page.evaluate(() => {
  const sels = [...document.querySelectorAll('[data-template-region="toolbar"] select')];
  return sels.map(s => {
    const wrap = s.parentElement;
    const icons = wrap ? wrap.querySelectorAll('span absolute, span[class*="pointer-events-none"]') : [];
    const cs = getComputedStyle(s);
    return {
      bgImage: cs.backgroundImage.slice(0, 80),
      appearance: cs.getPropertyValue('appearance') || cs.getPropertyValue('-webkit-appearance'),
      chevronIcons: wrap ? wrap.innerHTML.slice(-400).match(/i-lucide-chevron-down/g)?.length ?? 0 : -1,
      cls: s.className.slice(0, 160),
    };
  });
});
console.log('SELECTS:', JSON.stringify(selectInfo, null, 1));

// 3. Command palette height
await page.keyboard.press('Control+k');
await page.waitForTimeout(2500);
await page.screenshot({ path: OUT + '/palette.png' });
const palInfo = await page.evaluate(() => {
  const nk = document.querySelector('ninja-keys');
  if (!nk || !nk.shadowRoot) return { found: !!nk, shadow: false };
  const list = nk.shadowRoot.querySelector('.actions-list');
  const modal = nk.shadowRoot.querySelector('.modal-content');
  const cs = list ? getComputedStyle(list) : null;
  return {
    found: true, shadow: true,
    maxHeight: cs?.maxHeight, minHeight: cs?.minHeight,
    items: nk.shadowRoot.querySelectorAll('.actions-list > *').length,
    modalH: modal ? Math.round(modal.getBoundingClientRect().height) : 0,
  };
});
console.log('PALETTE:', JSON.stringify(palInfo));
await browser.close();
console.log('DONE', OUT);
