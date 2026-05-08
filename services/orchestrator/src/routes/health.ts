import type { FastifyPluginAsync } from 'fastify'

const healthRoute: FastifyPluginAsync = async (fastify) => {
  fastify.get('/health', async (_request, reply) => {
    return reply.status(200).send({ status: 'ok', version: '1.0.0' })
  })
}

export default healthRoute
