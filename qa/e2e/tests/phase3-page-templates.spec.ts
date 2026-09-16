import path from 'node:path';
import { AxeBuilder } from '@axe-core/playwright';
import { expect, test, type Page } from '@playwright/test';

const archetypes = [
  ['Lista', 'list'],
  ['Quadro', 'board'],
  ['Registro', 'record'],
  ['Conversa', 'conversation'],
  ['Calendário', 'calendar'],
  ['Configuração', 'settings'],
] as const;

const viewports = [
  [320, 800],
  [375, 812],
  [768, 1024],
  [1024, 768],
  [1440, 900],
  [1920, 1080],
] as const;

const artifactDirectory = path.resolve(
  process.cwd(),
  '../../artifacts/ui-audit-phase3-20260723'
);

async function openGallery(page: Page) {
  await page.goto('/app');
  await expect(page).toHaveURL(/\/app\/accounts\/(\d+)\//);
  const accountId = new URL(page.url()).pathname.match(
    /accounts\/(\d+)/
  )?.[1];
  expect(accountId).toBeTruthy();

  await page.goto(
    `/app/accounts/${accountId}/crm/design-system/templates`
  );
  await expect(page.getByRole('heading', { name: 'Leads', level: 1 })).toBeVisible();
}

async function setTheme(page: Page, theme: 'light' | 'dark') {
  await page.evaluate(selectedTheme => {
    localStorage.setItem('color_scheme', selectedTheme);
  }, theme);
  await page.reload();
  await expect(page.locator('body')).toHaveAttribute('data-theme', theme);
}

test('seis arquétipos mantêm layout, tema e acessibilidade', async ({
  page,
}, testInfo) => {
  testInfo.setTimeout(180_000);
  await openGallery(page);

  for (const theme of ['light', 'dark'] as const) {
    await setTheme(page, theme);

    for (const [width, height] of viewports) {
      await page.setViewportSize({ width, height });

      for (const [label, template] of archetypes) {
        await page
          .getByRole('tab', { name: label, exact: true })
          .click();

        const root = page.locator(`[data-page-template="${template}"]`);
        await expect(root).toBeVisible();
        await expect(root.getByRole('heading', { level: 1 })).toBeVisible();

        const overflow = await root.evaluate(element => {
          const parentWidth = element.parentElement?.clientWidth ?? 0;
          return {
            clientWidth: element.clientWidth,
            scrollWidth: element.scrollWidth,
            parentWidth,
          };
        });
        expect(overflow.clientWidth).toBeGreaterThanOrEqual(
          overflow.parentWidth - 1
        );
        expect(overflow.scrollWidth).toBeLessThanOrEqual(
          overflow.clientWidth + 1
        );

        if (template === 'settings' && width === 1440) {
          const saveButton = page.getByRole('button', {
            name: 'Salvar alterações',
          });
          const isUnobscured = await saveButton.evaluate(element => {
            const rectangle = element.getBoundingClientRect();
            const topmost = document.elementFromPoint(
              rectangle.right - 4,
              rectangle.top + rectangle.height / 2
            );
            return Boolean(topmost && element.contains(topmost));
          });
          expect(isUnobscured).toBe(true);
        }

        if (width === 1440) {
          await page.screenshot({
            path: path.join(
              artifactDirectory,
              `${template}-${theme}-${width}.png`
            ),
            animations: 'disabled',
          });
        }
      }
    }
  }

  await page.setViewportSize({ width: 1440, height: 900 });
  await setTheme(page, 'light');

  for (const [label, template] of archetypes) {
    await page.getByRole('tab', { name: label, exact: true }).click();
    const accessibility = await new AxeBuilder({ page })
      .include(`[data-page-template="${template}"]`)
      .withTags(['wcag2a', 'wcag2aa'])
      .analyze();
    const blocking = accessibility.violations.filter(violation =>
      ['critical', 'serious'].includes(violation.impact || '')
    );
    expect(blocking).toEqual([]);
  }
});

test('tabs operam por teclado e os estados preservam o template', async ({
  page,
}) => {
  await openGallery(page);

  const listTab = page.getByRole('tab', { name: 'Lista', exact: true });
  await listTab.focus();
  await page.keyboard.press('ArrowRight');
  await expect(
    page.getByRole('tab', { name: 'Quadro', exact: true })
  ).toHaveAttribute('aria-selected', 'true');

  const loadingTab = page.getByRole('tab', {
    name: 'Carregando',
    exact: true,
  });
  await loadingTab.click();
  await expect(page.locator('[data-page-template="board"]')).toHaveAttribute(
    'aria-busy',
    'true'
  );

  await page.getByRole('tab', { name: 'Vazio', exact: true }).click();
  await expect(page.getByText('Nenhum negócio neste pipeline.')).toBeVisible();
});
