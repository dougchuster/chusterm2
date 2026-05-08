import type { FastifyInstance } from 'fastify'
import healthRoute from './health.js'
import skillsRoute from './skills.js'
import knowledgeRoute from './knowledge.js'
import agentRoute from './agent.js'

export async function registerRoutes(fastify: FastifyInstance): Promise<void> {
  await fastify.register(healthRoute)
  await fastify.register(skillsRoute)
  await fastify.register(knowledgeRoute)
  await fastify.register(agentRoute)
}
