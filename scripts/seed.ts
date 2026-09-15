#!/usr/bin/env node
/**
 * Seed Script — popula dados iniciais para desenvolvimento.
 *
 * Uso: npx tsx scripts/seed.ts
 *
 * Cria:
 * - 1 knowledge collection
 * - 3 knowledge articles para FAQ
 *
 * O CRM vive no Core Rails (tabelas crm_*) — dados de exemplo de CRM são
 * criados via console Rails ou pela UI, não por este script.
 */
import postgres from 'postgres'
import { drizzle } from 'drizzle-orm/postgres-js'

// ─── Orchestrator Schema ─────────────────────────────────────────────────────
const orchUrl = process.env.ORCHESTRATOR_DB_URL ?? 'postgresql://chusterm:chusterm_pass@localhost:5436/chusterm_ai'
const orchClient = postgres(orchUrl, { max: 1 })
const orch = drizzle(orchClient)

async function seedOrchestrator() {
  console.log('🌱 Seed Orchestrator...')

  const { knowledgeArticles, knowledgeCollections } =
    await import('../services/orchestrator/src/db/schema.js')

  // Knowledge collections
  await orch.insert(knowledgeCollections).values([
    { id: 'k0000000-0000-0000-0000-000000000001', accountId: 1, name: 'FAQ Geral', description: 'Perguntas frequentes gerais', scope: ['faq.institutional.v1'] },
  ]).onConflictDoNothing()

  // Knowledge articles
  await orch.insert(knowledgeArticles).values([
    { id: 'l0000000-0000-0000-0000-000000000001', accountId: 1, collectionId: 'k0000000-0000-0000-0000-000000000001', title: 'Horário de Funcionamento', content: 'Nosso horário de atendimento é de segunda a sexta, das 8h às 18h, e sábado das 8h às 12h.', tags: ['horário', 'funcionamento', 'atendimento'], isPublished: true },
    { id: 'l0000000-0000-0000-0000-000000000002', accountId: 1, collectionId: 'k0000000-0000-0000-0000-000000000001', title: 'Documentos Necessários', content: 'Para iniciar o processo, você precisará de: RG, CPF, comprovante de residência e foto 3x4.', tags: ['documentos', 'matrícula', 'necessários'], isPublished: true },
    { id: 'l0000000-0000-0000-0000-000000000003', accountId: 1, collectionId: 'k0000000-0000-0000-0000-000000000001', title: 'Formas de Pagamento', content: 'Aceitamos pagamento via boleto bancário, cartão de crédito (até 12x), PIX e financiamento estudantil.', tags: ['pagamento', 'boleto', 'cartão', 'pix'], isPublished: true },
  ]).onConflictDoNothing()

  console.log('✅ Orchestrator seed completo')
}

async function main() {
  try {
    await seedOrchestrator()
    console.log('\n🎉 Seed completo!')
  } catch (err) {
    console.error('❌ Seed falhou:', err)
    process.exit(1)
  } finally {
    await orchClient.end()
  }
}

main()
