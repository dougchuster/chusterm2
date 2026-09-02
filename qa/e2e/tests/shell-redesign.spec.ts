import { expect, test, type Page } from '@playwright/test';

async function openCrm(page: Page) {
  await page.goto('/app');
  await expect(page).toHaveURL(/\/app\/accounts\/(\d+)\//);

  const accountId = new URL(page.url()).pathname.match(/accounts\/(\d+)/)?.[1];
  expect(accountId).toBeTruthy();

  await page.goto(`/app/accounts/${accountId}/crm`);
  await expect(
    page.getByRole('heading', { name: 'Pipeline Comercial', level: 1 })
  ).toBeVisible();
  await expect(page.getByText('Carregando CRM...')).toBeHidden({
    timeout: 30_000,
  });
}

test('shell global aplica a identidade visual do CRM', async ({
  page,
}, testInfo) => {
  await openCrm(page);

  const sidebar = page.locator('aside.sidebar-shell');
  await expect(page.getByText('ChusteRM', { exact: true })).toBeVisible();
  await expect(page.getByText('CRM + IA', { exact: true })).toBeVisible();
  await expect(sidebar).toHaveCSS('background-color', 'rgb(7, 13, 32)');

  const viewportWidth = testInfo.project.use.viewport?.width ?? 1366;
  const workspace = page.locator('main > div').first();

  if (viewportWidth >= 768) {
    const radius = await workspace.evaluate(element =>
      Number.parseFloat(getComputedStyle(element).borderRadius)
    );
    expect(radius).toBeGreaterThan(0);
  } else {
    await page
      .getByRole('button', { name: /Abrir barra lateral/i })
      .click();
    await expect
      .poll(() => sidebar.evaluate(element => element.getBoundingClientRect().left))
      .toBeGreaterThanOrEqual(0);

    const closeButton = page.getByRole('button', {
      name: /Fechar barra lateral/i,
    });
    await expect(closeButton).toBeVisible();
    await closeButton.click({ position: { x: viewportWidth - 20, y: 400 } });
    await expect
      .poll(() => sidebar.evaluate(element => element.getBoundingClientRect().right))
      .toBeLessThanOrEqual(1);
  }

  const overflow = await page.evaluate(
    () => document.documentElement.scrollWidth - document.documentElement.clientWidth
  );
  expect(overflow).toBeLessThanOrEqual(1);
});
