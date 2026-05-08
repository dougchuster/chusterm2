#!/usr/bin/env node
/**
 * Seed Script — popula dados iniciais para desenvolvimento.
 *
 * Uso: npx tsx scripts/seed.ts
 *
 * Cria:
 * - 5 leads de exemplo no CRM
 * - 3 deals
 * - 2 activities
 * - 1 appointment
 * - 3 knowledge articles para FAQ
 */
import postgres from 'postgres'
import { drizzle } from 'drizzle-orm/postgres-js'

// ─── CRM Service Schema ──────────────────────────────────────────────────────
const crmUrl = process.env.CRM_DB_URL ?? 'postgresql://chusterm:chusterm_pass@localhost:5436/chusterm_crm'
const crmClient = postgres(crmUrl, { max: 1 })
const crm = drizzle(crmClient)

// ─── Orchestrator Schema ─────────────────────────────────────────────────────
const orchUrl = process.env.ORCHESTRATOR_DB_URL ?? 'postgresql://chusterm:chusterm_pass@localhost:5436/chusterm_ai'
const orchClient = postgres(orchUrl, { max: 1 })
const orch = drizzle(orchClient)

async function seedCRM() {
  console.log('🌱 Seed CRM Service...')

  const { leadProfiles, deals, activities, appointments, leadSources, lossReasons, courseInterests, campuses } =
    await import('../services/crm-service/src/db/schema.js')

  // Lead sources
  await crm.insert(leadSources).values([
    { id: 'a0000000-0000-0000-0000-000000000001', accountId: 1, name: 'Google Ads', channel: 'google', isPaid: true },
    { id: 'a0000000-0000-0000-0000-000000000002', accountId: 1, name: 'Instagram Orgânico', channel: 'instagram', isPaid: false },
    { id: 'a0000000-0000-0000-0000-000000000003', accountId: 1, name: 'Indicação', channel: 'referral', isPaid: false },
  ]).onConflictDoNothing()

  // Loss reasons
  await crm.insert(lossReasons).values([
    { id: 'b0000000-0000-0000-0000-000000000001', accountId: 1, label: 'Preço' },
    { id: 'b0000000-0000-0000-0000-000000000002', accountId: 1, label: 'Concorrente' },
    { id: 'b0000000-0000-0000-0000-000000000003', accountId: 1, label: 'Não respondeu' },
  ]).onConflictDoNothing()

  // Course interests
  await crm.insert(courseInterests).values([
    { id: 'c0000000-0000-0000-0000-000000000001', accountId: 1, name: 'Produto Alpha', modalities: ['presencial', 'online'] },
    { id: 'c0000000-0000-0000-0000-000000000002', accountId: 1, name: 'Produto Beta', modalities: ['presencial'] },
  ]).onConflictDoNothing()

  // Campuses
  await crm.insert(campuses).values([
    { id: 'd0000000-0000-0000-0000-000000000001', accountId: 1, name: 'Sede Central', city: 'São Paulo', state: 'SP' },
  ]).onConflictDoNothing()

  // Leads
  await crm.insert(leadProfiles).values([
    { id: 'e0000000-0000-0000-0000-000000000001', accountId: 1, chatwootContactId: 1, fullName: 'Maria Silva', phone: '+5511999990001', email: 'maria@email.com', courseInterest: 'Produto Alpha', campusInterest: 'Sede Central', preferredShift: 'evening', enrollmentUrgency: 'immediate', stage: 'qualified', score: 85, sourceChannel: 'whatsapp', utmSource: 'google', utmCampaign: 'campanha_abril' },
    { id: 'e0000000-0000-0000-0000-000000000002', accountId: 1, chatwootContactId: 2, fullName: 'João Santos', phone: '+5511999990002', email: 'joao@email.com', courseInterest: 'Produto Beta', campusInterest: 'Sede Central', preferredShift: 'morning', enrollmentUrgency: '1_month', stage: 'triage_started', score: 60, sourceChannel: 'instagram', utmSource: 'instagram' },
    { id: 'e0000000-0000-0000-0000-000000000003', accountId: 1, chatwootContactId: 3, fullName: 'Ana Costa', phone: '+5511999990003', email: 'ana@email.com', courseInterest: 'Produto Alpha', enrollmentUrgency: 'exploring', stage: 'new_lead', score: 25, sourceChannel: 'website' },
    { id: 'e0000000-0000-0000-0000-000000000004', accountId: 1, chatwootContactId: 4, fullName: 'Carlos Oliveira', phone: '+5511999990004', email: 'carlos@email.com', courseInterest: 'Produto Beta', enrollmentUrgency: '3_months', stage: 'pending_appointment', score: 72, sourceChannel: 'whatsapp', utmSource: 'referral' },
    { id: 'e0000000-0000-0000-0000-000000000005', accountId: 1, chatwootContactId: 5, fullName: 'Fernanda Lima', phone: '+5511999990005', email: 'fernanda@email.com', courseInterest: 'Produto Alpha', campusInterest: 'Sede Central', preferredShift: 'afternoon', enrollmentUrgency: 'immediate', stage: 'qualified', score: 91, sourceChannel: 'messenger', utmSource: 'google', utmCampaign: 'campanha_maio' },
  ]).onConflictDoNothing()

  // Deals
  await crm.insert(deals).values([
    { id: 'f0000000-0000-0000-0000-000000000001', accountId: 1, leadProfileId: 'e0000000-0000-0000-0000-000000000001', title: 'Maria Silva — Produto Alpha', stage: 'qualified', score: 85, courseId: 'c0000000-0000-0000-0000-000000000001', expectedRevenue: 5000 },
    { id: 'f0000000-0000-0000-0000-000000000002', accountId: 1, leadProfileId: 'e0000000-0000-0000-0000-000000000004', title: 'Carlos Oliveira — Produto Beta', stage: 'pending_appointment', score: 72, courseId: 'c0000000-0000-0000-0000-000000000002', expectedRevenue: 3500 },
    { id: 'f0000000-0000-0000-0000-000000000003', accountId: 1, leadProfileId: 'e0000000-0000-0000-0000-000000000005', title: 'Fernanda Lima — Produto Alpha', stage: 'qualified', score: 91, courseId: 'c0000000-0000-0000-0000-000000000001', expectedRevenue: 5000 },
  ]).onConflictDoNothing()

  // Activities
  await crm.insert(activities).values([
    { id: 'a1000000-0000-0000-0000-000000000001', accountId: 1, leadProfileId: 'e0000000-0000-0000-0000-000000000001', dealId: 'f0000000-0000-0000-0000-000000000001', activityType: 'task', title: 'Ligar para confirmar interesse', dueAt: new Date(Date.now() + 86400000) },
    { id: 'a1000000-0000-0000-0000-000000000002', accountId: 1, leadProfileId: 'e0000000-0000-0000-0000-000000000004', dealId: 'f0000000-0000-0000-0000-000000000002', activityType: 'note', title: 'Lead interessado mas precisa falar com responsável' },
  ]).onConflictDoNothing()

  // Appointments
  await crm.insert(appointments).values([
    { id: 'a2000000-0000-0000-0000-000000000001', accountId: 1, leadProfileId: 'e0000000-0000-0000-0000-000000000004', dealId: 'f0000000-0000-0000-0000-000000000002', appointmentType: 'consultant_call', scheduledAt: new Date(Date.now() + 172800000), status: 'pending' },
  ]).onConflictDoNothing()

  console.log('✅ CRM seed completo')
}

async function seedOrchestrator() {
  console.log('🌱 Seed Orchestrator...')

  const { knowledgeArticles, knowledgeCollections, promptVersions } =
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
    await seedCRM()
    await seedOrchestrator()
    console.log('\n🎉 Seed completo!')
  } catch (err) {
    console.error('❌ Seed falhou:', err)
    process.exit(1)
  } finally {
    await crmClient.end()
    await orchClient.end()
  }
}

main()
