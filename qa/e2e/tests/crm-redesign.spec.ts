import { expect, test, type Page } from "@playwright/test";

async function openCrm(page: Page) {
  await page.goto("/app");
  await expect(page).toHaveURL(/\/app\/accounts\/(\d+)\//);

  const accountId = new URL(page.url()).pathname.match(/accounts\/(\d+)/)?.[1];
  expect(accountId).toBeTruthy();

  await page.goto(`/app/accounts/${accountId}/crm`);
  await expect(
    page.getByRole("heading", { name: "Pipeline", level: 1 }),
  ).toBeVisible({ timeout: 15_000 });
  await expect(page.getByText("Carregando CRM...")).toBeHidden({
    timeout: 30_000,
  });
}

test("CRM prioriza ações e indicadores essenciais", async ({ page }) => {
  await openCrm(page);

  await expect(page.getByLabel("Pipeline", { exact: true })).toBeVisible();
  await expect(page.getByLabel("Buscar no pipeline")).toBeVisible();
  await expect(
    page.getByRole("button", { name: "Novo negócio" }),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: "Atualizar pipeline" }),
  ).toBeVisible();
  await expect(page.getByTestId("crm-view-kanban")).toBeVisible();
  await expect(page.getByTestId("crm-view-table")).toBeVisible();
  await expect(page.getByText(/\d+ negócio\(s\)/)).toBeVisible();
});

test("CRM mantém navegação por teclado e layout responsivo", async ({
  page,
}, testInfo) => {
  await openCrm(page);

  await page.keyboard.press("/");
  const search = page.getByLabel("Buscar no pipeline");
  await expect(search).toBeFocused();
  await search.fill("busca de validação responsiva");
  await page.keyboard.press("Escape");
  await expect(search).toHaveValue("");

  const pageOverflow = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }));
  expect(pageOverflow.scrollWidth).toBeLessThanOrEqual(
    pageOverflow.clientWidth + 1,
  );

  if ((testInfo.project.use.viewport?.width ?? 1366) < 768) {
    await expect(
      page.getByTestId("crm-mobile-column-selector"),
    ).toBeVisible();
  } else {
    await expect(page.getByTestId("crm-column-count").first()).toBeVisible();
  }

  await testInfo.attach("crm-redesign.png", {
    body: await page.screenshot({ animations: "disabled" }),
    contentType: "image/png",
  });
});
