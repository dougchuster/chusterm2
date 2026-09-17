import { chromium } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';

const BASE = process.env.QA_BASE_URL || 'http://127.0.0.1:8086';
const ACCT = process.env.QA_ACCOUNT_ID || '55';
const OUT = path.resolve('test-results/ui-audit');
fs.mkdirSync(OUT, { recursive: true });

const routes = [
  'settings',
  'settings/agents',
  'settings/teams',
  'settings/inboxes',
  'settings/inboxes/new',
  'settings/account',
  'settings/labels',
  'settings/automation',
  'settings/canned',
  'settings/macros',
  'settings/sla',
  'settings/security',
  'settings/integrations',
  'settings/profile',
  'settings/applications',
  'settings/audit',
  'settings/reports',
  'contacts',
  'notifications',
  'captain/assistants',
  'crm',
  'crm/metrics',
  'marketing',
];

const browser = await chromium.launch();
const results = [];
for (const theme of ['light', 'dark']) {
  for (const r of routes) {
    const ctx = await browser.newContext({
      viewport: { width: 1366, height: 768 },
      storageState: 'playwright/.auth/admin.json',
      colorScheme: theme,
    });
    const page = await ctx.newPage();
    const errors = [];
    page.on('pageerror', e => errors.push(`pageerror:${e.message}`));
    page.on('console', m => {
      if (m.type() === 'error') errors.push(`console:${m.text()}`);
    });
    const url = `${BASE}/app/accounts/${ACCT}/${r}`;
    try {
      const resp = await page.goto(url, {
        waitUntil: 'domcontentloaded',
        timeout: 30000,
      });
      await page.waitForTimeout(2500);
      const overflow = await page.evaluate(() => {
        const el = document.documentElement;
        return el.scrollWidth > el.clientWidth ? 'H-OVERFLOW' : 'ok';
      });
      const shot = path.join(OUT, `${theme}-${r.replace(/\//g, '_')}.png`);
      await page.screenshot({ path: shot, fullPage: false });
      results.push({
        theme,
        route: r,
        status: resp ? resp.status() : 'n/a',
        overflow,
        errors: errors.slice(0, 4),
      });
    } catch (e) {
      results.push({ theme, route: r, status: 'fail', error: String(e).slice(0, 160) });
    }
    await ctx.close();
  }
}
await browser.close();
fs.writeFileSync(path.join(OUT, 'report.json'), JSON.stringify(results, null, 2));
for (const r of results) {
  const errs = r.errors && r.errors.length ? ` errs=${r.errors.length}` : '';
  console.log(`${r.theme} ${r.status} ${r.overflow || ''} ${r.route}${errs}`);
}
