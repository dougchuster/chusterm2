import { and, eq } from 'drizzle-orm'
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
  const collectionName = 'Dra. Paula Matos - Planejamento Previdenciario'

  const [existing] = await db
    .select()
    .from(knowledgeCollections)
    .where(and(eq(knowledgeCollections.accountId, accountId), eq(knowledgeCollections.name, collectionName)))
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
            'RAG inicial da Dra. Paula Matos para triagem de planejamento previdenciario.',
          scope: [DR_PAULA_MATOS_SLUG, DR_PAULA_MATOS_CAMPAIGN, 'previdenciario'],
        })
        .returning()
    )[0]

  for (const document of DR_PAULA_MATOS_KNOWLEDGE) {
    const [existingArticle] = await db
      .select({ id: knowledgeArticles.id })
      .from(knowledgeArticles)
      .where(
        and(
          eq(knowledgeArticles.accountId, accountId),
          eq(knowledgeArticles.collectionId, collection.id),
          eq(knowledgeArticles.title, document.title),
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

  if (!existingPrompt) {
    await db.insert(promptVersions).values({
      accountId,
      skillSlug: promptSlug,
      version: '1.0.0',
      systemPrompt:
        'Dra. Paula Matos: triagem previdenciaria humanizada, sem promessa de resultado, com coleta de objetivo, CNIS, forma de contribuicao, situacao no INSS, documentos e risco para handoff humano.',
      isActive: true,
    })
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
