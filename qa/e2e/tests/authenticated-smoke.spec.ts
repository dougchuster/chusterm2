import { expect, test } from '@playwright/test';

test('abre a aplicação autenticada sem resposta 5xx', async ({ page }) => {
  const serverErrors: string[] = [];
  page.on('response', response => {
    if (response.status() >= 500) serverErrors.push(`${response.status()} ${response.url()}`);
  });

  await page.goto('/app');
  await expect(page).not.toHaveURL(/\/app\/login/);
  await expect(page.locator('body')).toBeVisible();
  expect(serverErrors).toEqual([]);
});
