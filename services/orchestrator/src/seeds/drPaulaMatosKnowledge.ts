import { and, eq, inArray } from 'drizzle-orm'
import { db, pgClient } from '../db/client.js'
import {
  DR_PAULA_MATOS_CAMPAIGN,
  DR_PAULA_MATOS_KNOWLEDGE,
  DR_PAULA_MATOS_SCORE_MODEL,
  DR_PAULA_MATOS_SLUG,
} from '../agents/drPaulaMatos.js'
import { knowledgeArticles, knowledgeCollections, promptVersions } from '../db/schema.js'

const accountId = Number(process.env.ACCOUNT_ID ?? process.argv[2] ?? 1)

if (!Number.isInteger(accountId) || accountId <= 0) {
  throw new Error('ACCOUNT_ID must be a positive integer')
}

async function seedCollection() {
  const collectionName = 'Dra. Paula Matos - Planejamento Previdenciário'
  const legacyCollectionName = 'Dra. Paula Matos - Planejamento Previdenciario'

  const [existing] = await db
    .select()
    .from(knowledgeCollections)
    .where(
      and(
        eq(knowledgeCollections.accountId, accountId),
        inArray(knowledgeCollections.name, [collectionName, legacyCollectionName]),
      ),
    )
    .limit(1)

  const collection =
    existing ??
    (
      await db
        .insert(knowledgeCollections)
        .values({
          accountId,
          name: collectionName,
          description:
            'RAG inicial da Dra. Paula Matos para triagem de planejamento previdenciário.',
          scope: [DR_PAULA_MATOS_SLUG, DR_PAULA_MATOS_CAMPAIGN, 'previdenciario'],
        })
        .returning()
    )[0]

  if (existing && existing.name !== collectionName) {
    await db
      .update(knowledgeCollections)
      .set({
        name: collectionName,
        description: 'RAG inicial da Dra. Paula Matos para triagem de planejamento previdenciário.',
        updatedAt: new Date(),
      })
      .where(eq(knowledgeCollections.id, existing.id))
  }

  const legacyTitles: Record<string, string> = {
    'Planejamento previdenciário antes do protocolo': 'Planejamento previdenciario antes do protocolo',
    'Método de atendimento da campanha': 'Metodo de atendimento da campanha',
    'Conferir CNIS e simulação antes do pedido': 'Conferir CNIS e simulacao antes do pedido',
    'Simulação do Meu INSS não garante direito': 'Simulacao do Meu INSS nao garante direito',
    'Contribuições MEI, facultativo e individual': 'Contribuicoes MEI, facultativo e individual',
    'FAQ - O que é planejamento previdenciário?': 'FAQ - O que e planejamento previdenciario?',
  }

  for (const document of DR_PAULA_MATOS_KNOWLEDGE) {
    const titles = [document.title, legacyTitles[document.title]].filter((title): title is string =>
      Boolean(title),
    )
    const [existingArticle] = await db
      .select({ id: knowledgeArticles.id })
      .from(knowledgeArticles)
      .where(
        and(
          eq(knowledgeArticles.accountId, accountId),
          eq(knowledgeArticles.collectionId, collection.id),
          inArray(knowledgeArticles.title, titles),
        ),
      )
      .limit(1)

    const content = [
      `Fonte: ${document.source}`,
      `URL: ${document.sourceUrl}`,
      '',
      document.content,
    ].join('\n')

    if (existingArticle) {
      await db
        .update(knowledgeArticles)
        .set({
          title: document.title,
          content,
          tags: Array.from(
            new Set([
              ...document.tags,
              document.type,
              DR_PAULA_MATOS_SLUG,
              DR_PAULA_MATOS_CAMPAIGN,
              DR_PAULA_MATOS_SCORE_MODEL,
            ]),
          ),
          isPublished: true,
          updatedAt: new Date(),
        })
        .where(eq(knowledgeArticles.id, existingArticle.id))
      continue
    }

    await db.insert(knowledgeArticles).values({
      accountId,
      collectionId: collection.id,
      title: document.title,
      content,
      tags: Array.from(
        new Set([
          ...document.tags,
          document.type,
          DR_PAULA_MATOS_SLUG,
          DR_PAULA_MATOS_CAMPAIGN,
          DR_PAULA_MATOS_SCORE_MODEL,
        ]),
      ),
      isPublished: true,
    })
  }

  const promptSlug = 'dr-paula-matos-system'
  const [existingPrompt] = await db
    .select({ id: promptVersions.id })
    .from(promptVersions)
    .where(and(eq(promptVersions.accountId, accountId), eq(promptVersions.skillSlug, promptSlug)))
    .limit(1)

  const systemPrompt =
    'Dra. Paula Matos: triagem previdenciária humanizada, sem promessa de resultado, com coleta de objetivo, CNIS, forma de contribuição, situação no INSS, documentos e risco para handoff humano. Responder sempre em português brasileiro correto, com acentuação completa, concordância e ortografia revisadas.'

  if (!existingPrompt) {
    await db.insert(promptVersions).values({
      accountId,
      skillSlug: promptSlug,
      version: '1.0.0',
      systemPrompt,
      isActive: true,
    })
  } else {
    await db
      .update(promptVersions)
      .set({ systemPrompt, isActive: true, updatedAt: new Date() })
      .where(eq(promptVersions.id, existingPrompt.id))
  }

  return collection.id
}

seedCollection()
  .then(async (collectionId) => {
    console.log(`Seeded Dra. Paula Matos knowledge for account ${accountId}: ${collectionId}`)
  })
  .finally(async () => {
    await pgClient.end()
  })
