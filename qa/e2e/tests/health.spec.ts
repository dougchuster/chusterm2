import { expect, test } from '@playwright/test';

test.use({ storageState: { cookies: [], origins: [] } });

test('health do Core responde sem autenticação', async ({ request }) => {
  const response = await request.get('/health');

  expect(response.ok()).toBeTruthy();
  await expect(response.json()).resolves.toEqual({ status: 'woot' });
});
