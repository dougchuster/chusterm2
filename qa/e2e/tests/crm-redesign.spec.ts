import { expect, test, type Page } from "@playwright/test";

async function openCrm(page: Page) {
  await page.goto("/app");
  await expect(page).toHaveURL(/\/app\/accounts\/(\d+)\//);

  const accountId = new URL(page.url()).pathname.match(/accounts\/(\d+)/)?.[1];
  expect(accountId).toBeTruthy();

  await page.goto(`/app/accounts/${accountId}/crm`);
  await expect(
    page.getByRole("heading", { name: "Pipeline Comercial", level: 1 }),
  ).toBeVisible();
  await expect(page.getByText("Carregando CRM...")).toBeHidden({
    timeout: 30_000,
  });
}

test("CRM prioriza ações e indicadores essenciais", async ({ page }) => {
  await openCrm(page);

  await expect(page.getByLabel("Selecionar pipeline")).toBeVisible();
  await expect(
    page.getByRole("button", { name: "Central de IA" }),
  ).toBeVisible();
  await expect(page.getByRole("button", { name: "Métricas" })).toBeVisible();
  await expect(page.getByLabel("Buscar oportunidade ou contato")).toBeVisible();
  await expect(
    page.getByRole("heading", { name: "Visão operacional" }),
  ).toBeVisible();
  await expect(page.getByText("Fluxo de oportunidades")).toBeVisible();

  const healthToggle = page.getByRole("button", {
    name: /alertas operacionais|Operação saudável/,
  });
  await healthToggle.click();
  await expect(healthToggle).toHaveAttribute("aria-expanded", "true");
  await expect(page.locator("#crm-operational-details")).toBeVisible();

  const backdropFilter = await page
    .locator(".crm-command-header")
    .evaluate((element) => getComputedStyle(element).backdropFilter);
  expect(backdropFilter).toBe("none");
});

test("CRM mantém navegação por teclado e layout responsivo", async ({
  page,
}, testInfo) => {
  await openCrm(page);

  await page.keyboard.press("/");
  const search = page.getByLabel("Buscar oportunidade ou contato");
  await expect(search).toBeFocused();
  await search.fill("busca de validação responsiva");
  await expect(page.getByRole("button", { name: "Limpar" })).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(search).toHaveValue("");

  const pageOverflow = await page.locator(".crm-page").evaluate((element) => ({
    clientWidth: element.clientWidth,
    scrollWidth: element.scrollWidth,
  }));
  expect(pageOverflow.scrollWidth).toBeLessThanOrEqual(
    pageOverflow.clientWidth + 1,
  );

  if ((testInfo.project.use.viewport?.width ?? 1366) < 768) {
    await expect(page.locator(".crm-kanban-board")).toHaveCount(0);
    await expect(
      page.locator(".crm-command-board button[aria-expanded]").first(),
    ).toBeVisible();
  } else {
    await expect(page.locator(".crm-kanban-board")).toBeVisible();
  }

  await testInfo.attach("crm-redesign.png", {
    body: await page.screenshot({ animations: "disabled" }),
    contentType: "image/png",
  });
});
