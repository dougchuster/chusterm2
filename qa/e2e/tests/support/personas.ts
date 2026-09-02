export const fixtureNamespace = process.env.QA_FIXTURE_NAMESPACE ?? 'f0';

export const personas = {
  admin: `qa+${fixtureNamespace}-admin@chusterm.invalid`,
  operator: `qa+${fixtureNamespace}-operator@chusterm.invalid`,
  seller: `qa+${fixtureNamespace}-seller@chusterm.invalid`,
  manager: `qa+${fixtureNamespace}-manager@chusterm.invalid`,
  knowledge_manager: `qa+${fixtureNamespace}-knowledge-manager@chusterm.invalid`,
  admin_b: `qa+${fixtureNamespace}-admin-b@chusterm.invalid`,
  suspended_admin: `qa+${fixtureNamespace}-suspended-admin@chusterm.invalid`,
  no_account: `qa+${fixtureNamespace}-no-account@chusterm.invalid`,
} as const;

export type Persona = keyof typeof personas;

export function fixturePassword(): string {
  const password = process.env.QA_FIXTURE_PASSWORD;
  if (!password || password.length < 12) {
    throw new Error('Defina QA_FIXTURE_PASSWORD com ao menos 12 caracteres antes do Playwright.');
  }

  return password;
}
