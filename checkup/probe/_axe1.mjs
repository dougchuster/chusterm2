import { chromium } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
const b = await chromium.launch(); const ctx = await b.newContext({ viewport: { width: 1440, height: 900 }, storageState: process.argv[3] ? `../../qa/e2e/playwright/.auth/${process.argv[3]}.json` : undefined }); const p = await ctx.newPage();
await p.goto((process.env.QA_BASE_URL ?? 'http://127.0.0.1:8086') + process.argv[2], { waitUntil: 'networkidle' });
const r = await new AxeBuilder({ page: p }).withTags(['wcag2a','wcag2aa']).analyze();
for (const v of r.violations.filter(v => ['serious','critical'].includes(v.impact))) {
  console.log(v.id, v.impact, v.help);
  for (const n of v.nodes.slice(0, 5)) console.log('  ', n.target.join(' '), '|', n.html.slice(0, 160), '|', n.any[0]?.message?.slice(0, 160) ?? '');
}
await b.close();
