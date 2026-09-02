import { and, eq, inArray } from 'drizzle-orm'
import { db, pgClient } from '../db/client.js'
import {
  DR_LETICIA_NEW_LEAD_CLOSING,
  DR_LETICIA_PUBLIC_INTRO,
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
            'RAG da Dra. Letícia para o atendimento inicial da Dra. Paula Matos e triagem previdenciária.',
          scope: [DR_PAULA_MATOS_SLUG, DR_PAULA_MATOS_CAMPAIGN, 'previdenciario'],
        })
        .returning()
    )[0]

  if (existing && existing.name !== collectionName) {
    await db
      .update(knowledgeCollections)
      .set({
        name: collectionName,
        description:
          'RAG da Dra. Letícia para o atendimento inicial da Dra. Paula Matos e triagem previdenciária.',
        updatedAt: new Date(),
      })
      .where(eq(knowledgeCollections.id, existing.id))
  }

  const legacyTitles: Record<string, string> = {
    'Planejamento previdenciário antes do protocolo': 'Planejamento previdenciario antes do protocolo',
    'Método de atendimento da campanha': 'Metodo de atendimento da campanha',
    'Conferir CNIS antes do pedido': 'Conferir CNIS e simulacao antes do pedido',
    'Simulador do Meu INSS não é parâmetro seguro': 'Simulacao do Meu INSS nao garante direito',
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

  const systemPrompt = [
    `${DR_LETICIA_PUBLIC_INTRO} Esta é a identidade pública obrigatória; Dra. Paula Matos é a advogada real do escritório. Nunca se apresentar como Dra. Paula, assistente, IA, automação ou pelo nome interno Capitão.`,
    'Antes de responder, ler todo o histórico, analisar fatos e documentos disponíveis e consultar a base recuperada. Nunca fingir leitura de anexo indisponível. Resolver referências curtas pelo contexto e responder toda pergunta direta na primeira frase, antes de fazer triagem ou pedir dados.',
    'Se a pessoa disser que uma advogada pediu algo, informar que também é advogada e pode orientar. No fluxo CNIS, se depois perguntar como conseguir, ensinar aplicativo ou site Meu INSS, conta gov.br e opção Extrato de Contribuições (CNIS), sem pedir CPF. Depois de agradecimento, encerrar gentilmente sem retomar triagem.',
    `Quando um lead novo relatar seu caso, depois de compreender o ponto inicial encerrar com "${DR_LETICIA_NEW_LEAD_CLOSING}" exatamente uma vez; verificar o histórico e não repetir nem parafrasear o aviso. Saudação ou dúvida operacional isolada não acionam esse encerramento.`,
    'Responder em português brasileiro correto, em uma ou duas frases curtas, com até 240 caracteres e no máximo uma pergunta. Não repetir o histórico, perguntas ou documentos já informados. Não prometer resultado, valor ou prazo, não pedir credenciais e não usar o simulador do Meu INSS como análise segura.',
  ].join(' ')

  if (!existingPrompt) {
    await db.insert(promptVersions).values({
      accountId,
      skillSlug: promptSlug,
      version: '2.0.0',
      systemPrompt,
      isActive: true,
    })
  } else {
    await db
      .update(promptVersions)
      .set({
        version: '2.0.0',
        systemPrompt,
        isActive: true,
        updatedAt: new Date(),
      })
      .where(eq(promptVersions.id, existingPrompt.id))
  }

  return collection.id
}

seedCollection()
  .then(async (collectionId) => {
    console.log(
      `Seeded Dra. Letícia public persona (legacy Dra. Paula profile) for account ${accountId}: ${collectionId}`,
    )
  })
  .finally(async () => {
    await pgClient.end()
  })
