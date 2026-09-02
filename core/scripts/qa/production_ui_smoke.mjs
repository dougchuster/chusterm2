import fs from 'node:fs/promises';
import path from 'node:path';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const playwrightModule =
  process.env.PLAYWRIGHT_MODULE ||
  path.join(
    process.env.USERPROFILE,
    '.codex',
    'skills',
    'playwright-skill',
    'node_modules',
    'playwright'
  );
const { chromium } = require(playwrightModule);

const baseUrl = process.env.CRM_BASE_URL || 'https://crm.coimbraeruas.com.br';
const email = process.env.CRM_SMOKE_EMAIL;
const password = process.env.CRM_SMOKE_PASSWORD;
const chromePath =
  process.env.CHROME_PATH ||
  'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const outputDir = path.resolve(
  process.env.CRM_SMOKE_OUTPUT || '../tmp/production-ui-smoke'
);

if (!email || !password) {
  throw new Error('CRM_SMOKE_EMAIL and CRM_SMOKE_PASSWORD are required');
}

await fs.mkdir(outputDir, { recursive: true });

const browser = await chromium.launch({
  executablePath: chromePath,
  headless: true,
});
const context = await browser.newContext({
  locale: 'pt-BR',
  viewport: { width: 1440, height: 1000 },
});
const page = await context.newPage();
const consoleErrors = [];
const failedRequests = [];

page.on('console', message => {
  if (message.type() === 'error') {
    consoleErrors.push(message.text().slice(0, 240));
  }
});
page.on('pageerror', error => {
  consoleErrors.push(error.message.slice(0, 240));
});
page.on('requestfailed', request => {
  const failure = request.failure();
  const url = new URL(request.url());
  failedRequests.push({
    resource: url.pathname,
    reason: failure?.errorText || 'unknown',
  });
});

const result = {
  login: false,
  conversations: false,
  conversationSearch: false,
  crm: false,
  captain: false,
  horizontalOverflow: {},
};

const capture = async name => {
  await page.screenshot({
    path: path.join(outputDir, `${name}.png`),
    fullPage: false,
  });
};

const recordOverflow = async name => {
  result.horizontalOverflow[name] = await page.evaluate(
    () => document.documentElement.scrollWidth > window.innerWidth + 1
  );
};

try {
  await page.goto(baseUrl, {
    waitUntil: 'domcontentloaded',
    timeout: 45_000,
  });

  const passwordInput = page.locator('input[type="password"]').first();
  if (await passwordInput.isVisible({ timeout: 8_000 }).catch(() => false)) {
    await page.locator('input[type="email"]').first().fill(email);
    await passwordInput.fill(password);
    await page.locator('button[type="submit"]').first().click();
  }

  await page.waitForURL(url => url.pathname.startsWith('/app/accounts/'), {
    timeout: 45_000,
  });
  result.login = true;

  await page.goto(`${baseUrl}/app/accounts/1/dashboard`, {
    waitUntil: 'domcontentloaded',
    timeout: 45_000,
  });
  await page.locator('form[role="search"] input[type="search"]').waitFor({
    state: 'visible',
    timeout: 30_000,
  });
  await page.waitForFunction(
    () =>
      !/Carregando (conversas|caixas de entrada)/i.test(
        document.body.innerText
      ),
    undefined,
    { timeout: 30_000 }
  );
  result.conversations = true;
  await page.locator('form[role="search"] input[type="search"]').fill('Douglas');
  await page.waitForTimeout(500);
  await page.waitForFunction(
    () => {
      const form = document.querySelector('form[role="search"]');
      return (
        form?.getAttribute('aria-busy') !== 'true' &&
        !/Carregando (conversas|caixas de entrada)/i.test(
          document.body.innerText
        ) &&
        document.querySelectorAll('.conversation-card').length > 0
      );
    },
    undefined,
    { timeout: 30_000 }
  );
  result.conversationSearch =
    (await page.locator('form[role="search"] input[type="search"]').inputValue()) ===
    'Douglas';
  await recordOverflow('conversations');
  await capture('01-conversations-search');

  await page.goto(`${baseUrl}/app/accounts/1/crm`, {
    waitUntil: 'domcontentloaded',
    timeout: 45_000,
  });
  await page.getByText('Pipeline Comercial', { exact: true }).waitFor({
    state: 'visible',
    timeout: 30_000,
  });
  await page.locator('.crm-loading-state').waitFor({
    state: 'hidden',
    timeout: 30_000,
  });
  await page.locator('.crm-command-kpis').waitFor({
    state: 'visible',
    timeout: 30_000,
  });
  result.crm =
    (await page.getByText('Pipeline Comercial', { exact: true }).count()) > 0 &&
    !page.url().includes('/login');
  await recordOverflow('crm');
  await capture('02-crm');

  await page.goto(`${baseUrl}/app/accounts/1/captain/2/config`, {
    waitUntil: 'domcontentloaded',
    timeout: 45_000,
  });
  await page.waitForTimeout(2_500);
  result.captain =
    (await page.getByText(/Dra\.? Paula|Configura|Agente/i).count()) > 0 &&
    !page.url().includes('/login');
  await recordOverflow('captain');
  await capture('03-captain');
} finally {
  result.consoleErrorCount = consoleErrors.length;
  result.failedRequestCount = failedRequests.length;
  result.unexpectedFailedRequestCount = failedRequests.filter(
    request => !request.reason.includes('ERR_ABORTED')
  ).length;
  result.failedRequestResources = failedRequests.slice(0, 10);
  result.finalUrl = page.url();
  await browser.close();
}

console.log(JSON.stringify(result, null, 2));

if (
  !result.login ||
  !result.conversations ||
  !result.conversationSearch ||
  !result.crm ||
  !result.captain ||
  result.consoleErrorCount > 0 ||
  result.unexpectedFailedRequestCount > 0 ||
  Object.values(result.horizontalOverflow).some(Boolean)
) {
  process.exitCode = 1;
}
