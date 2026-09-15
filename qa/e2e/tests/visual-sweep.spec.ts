import { expect, test } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

/**
 * CRM-025 — passagem visual das rotas autenticadas (VISUAL-F0).
 *
 * Duas varreduras:
 *
 *   sweep A (cobertura): todas as rotas `/app/accounts/:accountId/...` do
 *   manifesto, com parâmetros resolvidos pela fixture canônica, em
 *   1366×768 light + dark. Cada rota grava status HTTP, overflow
 *   horizontal e erros de console; falhas graves viram achados.
 *
 *   sweep B (matriz): as superfícies de maior tráfego × cinco viewports ×
 *   light/dark, com screenshot em `test-results/visual-sweep/`.
 *
 * Rotas que precisam de recurso não seedado (portalSlug, flowId etc.) são
 * registradas como `skipped` — não contaminam o resultado nem fingem
 * cobertura.
 *
 * Uso:
 *   QA_FIXTURE_PASSWORD=... pnpm exec playwright test \
 *     tests/visual-sweep.spec.ts --project=chromium-desktop
 */

const manifestPath = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../fixtures/route-manifest.json'
);
const evidenceDir = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  '../test-results/visual-sweep'
);

const VIEWPORTS = [
  { name: 'desktop-1920', width: 1920, height: 1080 },
  { name: 'desktop-1440', width: 1440, height: 900 },
  { name: 'laptop-1280', width: 1280, height: 800 },
  { name: 'tablet-768', width: 768, height: 1024 },
  { name: 'mobile-375', width: 375, height: 812 },
];

const THEMES = ['light', 'dark'] as const;

// Superfícies da matriz 5×2 — o que o operador realmente abre todo dia.
const MATRIX_ROUTES = [
  '/app/accounts/:accountId/crm',
  '/app/accounts/:accountId/crm/leads',
  '/app/accounts/:accountId/crm/metrics',
  '/app/accounts/:accountId/crm/reports',
  '/app/accounts/:accountId/crm/deals/:dealId',
  '/app/accounts/:accountId/inbox/:inbox_id/conversations/:conversation_id',
  '/app/accounts/:accountId/contacts',
  '/app/accounts/:accountId/contacts/:contactId',
  '/app/accounts/:accountId/dashboard',
  '/app/accounts/:accountId/reports',
  '/app/accounts/:accountId/captain',
  '/app/accounts/:accountId/notifications',
];

interface Manifest {
  routes: { route: string; family: string }[];
}

interface SweepResult {
  route: string;
  url?: string;
  status: 'ok' | 'skipped' | 'failed';
  httpStatus?: number;
  overflowPx?: number;
  consoleErrors?: string[];
  reason?: string;
}

const apiHeaders = async (page: any) => {
  const cookies = await page.context().cookies();
  const sessionCookie = cookies.find(c => c.name === 'cw_d_session_info');
  const session = JSON.parse(decodeURIComponent(sessionCookie!.value));
  return {
    'access-token': session['access-token'],
    'token-type': session['token-type'] ?? 'Bearer',
    client: session.client,
    expiry: session.expiry,
    uid: session.uid,
  };
};

const apiGet = async (page: any, urlPath: string) =>
  page.request.get(urlPath, { headers: await apiHeaders(page) });

const firstId = (body: any): number | null => {
  const rows = body?.data?.payload ?? body?.payload ?? body?.data ?? body;
  const first = Array.isArray(rows) ? rows[0] : rows?.[0];
  const id = first?.id;
  return Number.isFinite(Number(id)) ? Number(id) : null;
};

/** Resolve `:param` de cada rota usando a fixture canônica. */
const buildResolver = async (page: any) => {
  const profile = await (await apiGet(page, '/api/v1/profile')).json();
  const accountId =
    Number(process.env.QA_ACCOUNT_ID) || profile.accounts[0].id;

  const convResponse = await apiGet(
    page,
    `/api/v1/accounts/${accountId}/conversations?status=all`
  );
  const convPayload = (await convResponse.json())?.data?.payload ?? [];
  const conversation = convPayload.find(
    (c: any) =>
      c.additional_attributes?.qa_fixture_conversation ===
      (process.env.QA_JOURNEY_SCENARIO ?? 'lead_active')
  );

  const [teams, labels, agents, portals] = await Promise.all([
    apiGet(page, `/api/v1/accounts/${accountId}/teams`).then(r => r.json()),
    apiGet(page, `/api/v1/accounts/${accountId}/labels`).then(r => r.json()),
    apiGet(page, `/api/v1/accounts/${accountId}/agents`).then(r => r.json()),
    apiGet(page, `/api/v1/accounts/${accountId}/portals`)
      .then(r => r.json())
      .catch(() => null),
  ]);

  const captainState = conversation
    ? await apiGet(
        page,
        `/api/v1/accounts/${accountId}/captain/conversation_states/${conversation.id}`
      )
        .then(r => (r.ok() ? r.json() : null))
        .catch(() => null)
    : null;

  const portalSlug = portals?.payload?.[0]?.slug ?? portals?.[0]?.slug;
  const values: Record<string, string | number | undefined> = {
    accountId,
    inbox_id: conversation?.inbox_id,
    conversation_id: conversation?.id,
    conversationId: conversation?.id,
    contactId: conversation?.meta?.sender?.id ?? conversation?.contact_id,
    dealId: captainState?.crm_deal_id,
    assistantId: captainState?.captain_assistant_id,
    teamId: firstId(teams),
    id: firstId(agents),
    label: labels?.[0]?.name ?? labels?.payload?.[0]?.name,
    segmentId: undefined,
    portalSlug,
    locale: 'pt_BR',
    categorySlug: undefined,
    articleSlug: undefined,
    categoryId: undefined,
    kind: 'person',
    type: 'inbox',
    navigationPath: 'home',
    tab: undefined,
    flowId: undefined,
  };

  // `:id` é ambíguo entre rotas (agente, inbox, conta, conversation...).
  // Onde a semântica é conhecida, sobrescrevemos por rota.
  const perRoute: Record<string, Record<string, string | number | undefined>> = {
    '/app/accounts/:accountId/inbox-view/:type/:id': {
      id: conversation?.id,
    },
  };

  return (route: string) => {
    const missing: string[] = [];
    const scoped = { ...values, ...(perRoute[route] ?? {}) };
    const url = route.replace(/:(\w+)\??/g, (_m, key) => {
      const value = scoped[key];
      if (value === undefined || value === null || value === '') {
        missing.push(key);
        return `:${key}`;
      }
      return encodeURIComponent(String(value));
    });
    return { url, missing };
  };
};

const visit = async (page: any, url: string) => {
  const consoleErrors: string[] = [];
  const onConsole = (msg: any) => {
    if (msg.type() === 'error') consoleErrors.push(msg.text().slice(0, 200));
  };
  page.on('console', onConsole);
  let httpStatus = 0;
  try {
    const response = await page.goto(url, { waitUntil: 'domcontentloaded' });
    httpStatus = response?.status() ?? 0;
    await page.waitForLoadState('networkidle', { timeout: 15_000 }).catch(() => {});
    await page.waitForTimeout(400);
    const overflowPx = await page.evaluate(
      () =>
        document.documentElement.scrollWidth -
        document.documentElement.clientWidth
    );
    return { httpStatus, overflowPx, consoleErrors };
  } finally {
    page.off('console', onConsole);
  }
};

const applyTheme = async (page: any, theme: (typeof THEMES)[number]) => {
  await page.addInitScript(
    t => window.localStorage.setItem('color_scheme', t),
    theme
  );
};

test.describe('VISUAL-F0 — passagem visual', () => {
  test.describe.configure({ timeout: 0 });

  test('sweep A: todas as rotas resolvíveis em light e dark', async ({
    page,
  }, testInfo) => {
    test.setTimeout(10 * 60 * 1000);
    const manifest: Manifest = JSON.parse(
      await import('node:fs/promises').then(fs =>
        fs.readFile(manifestPath, 'utf8')
      )
    );
    const resolver = await buildResolver(page);
    const targets = manifest.routes
      .filter(r => r.route.startsWith('/app/accounts/'))
      .filter(r => !r.route.includes('*'));

    const results: SweepResult[] = [];
    await mkdir(evidenceDir, { recursive: true });

    for (const theme of THEMES) {
      await applyTheme(page, theme);
      for (const { route } of targets) {
        const { url, missing } = resolver(route);
        if (missing.length) {
          results.push({
            route,
            status: 'skipped',
            reason: `parâmetros sem seed: ${missing.join(', ')}`,
          });
          continue;
        }
        const { httpStatus, overflowPx, consoleErrors } = await visit(
          page,
          url
        );
        const failed = httpStatus >= 500;
        results.push({
          route,
          url,
          status: failed ? 'failed' : 'ok',
          httpStatus,
          overflowPx,
          consoleErrors: consoleErrors.slice(0, 3),
          ...(failed ? {} : {}),
        });
        if (theme === 'light' || failed || (overflowPx ?? 0) > 1) {
          const shot = `${theme}-${route.replaceAll('/', '_')}.png`;
          await page
            .screenshot({ path: path.join(evidenceDir, shot) })
            .catch(() => {});
        }
      }
    }

    const report = {
      generated_at: new Date().toISOString(),
      viewports: [{ name: 'coverage', width: 1366, height: 768 }],
      themes: THEMES,
      totals: {
        routes: results.length,
        ok: results.filter(r => r.status === 'ok').length,
        failed: results.filter(r => r.status === 'failed').length,
        skipped: results.filter(r => r.status === 'skipped').length,
        with_overflow: results.filter(r => (r.overflowPx ?? 0) > 1).length,
      },
      results,
    };
    const reportPath = path.join(evidenceDir, 'sweep-a.json');
    await writeFile(reportPath, JSON.stringify(report, null, 2));
    await testInfo.attach('sweep-a.json', {
      body: Buffer.from(JSON.stringify(report, null, 2)),
      contentType: 'application/json',
    });
    expect(report.totals.failed, JSON.stringify(
      results.filter(r => r.status === 'failed'), null, 2
    )).toBe(0);
  });

  test('sweep B: matriz 5 viewports × light/dark nas superfícies-chave', async ({
    page,
  }, testInfo) => {
    test.setTimeout(10 * 60 * 1000);
    const resolver = await buildResolver(page);
    const results: SweepResult[] = [];
    await mkdir(evidenceDir, { recursive: true });

    for (const viewport of VIEWPORTS) {
      await page.setViewportSize({
        width: viewport.width,
        height: viewport.height,
      });
      for (const theme of THEMES) {
        await applyTheme(page, theme);
        for (const route of MATRIX_ROUTES) {
          const { url, missing } = resolver(route);
          if (missing.length) {
            results.push({
              route,
              status: 'skipped',
              reason: `parâmetros sem seed: ${missing.join(', ')}`,
            });
            continue;
          }
          const { httpStatus, overflowPx, consoleErrors } = await visit(
            page,
            url
          );
          const shot = path.join(
            evidenceDir,
            `${viewport.name}-${theme}-${route
              .replaceAll('/', '_')
              .replace(/_+$/, '')}.png`
          );
          await page.screenshot({ path: shot }).catch(() => {});
          results.push({
            route: `${viewport.name}/${theme}${route}`,
            url,
            status: httpStatus >= 500 || (overflowPx ?? 0) > 1 ? 'failed' : 'ok',
            httpStatus,
            overflowPx,
            consoleErrors: consoleErrors.slice(0, 3),
          });
        }
      }
    }

    const reportPath = path.join(evidenceDir, 'sweep-b.json');
    await writeFile(reportPath, JSON.stringify(results, null, 2));
    await testInfo.attach('sweep-b.json', {
      body: Buffer.from(JSON.stringify(results, null, 2)),
      contentType: 'application/json',
    });
    const failed = results.filter(r => r.status === 'failed');
    expect(failed, JSON.stringify(failed, null, 2)).toEqual([]);
  });
});
