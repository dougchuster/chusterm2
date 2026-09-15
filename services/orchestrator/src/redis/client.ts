import { Redis } from 'ioredis'
import { URL } from 'url'

function parseRedisConnection(redisUrl: string) {
  const parsed = new URL(redisUrl)
  return {
    host: parsed.hostname,
    port: Number(parsed.port) || 6379,
    password: parsed.password || undefined,
    db: Number(parsed.pathname.replace('/', '')) || 0,
  }
}

// SEC-04: nunca senha default em código. Em produção a URL é obrigatória;
// em dev cai num Redis local sem senha.
const redisUrl = process.env.ORCHESTRATOR_REDIS_URL
if (!redisUrl && process.env.NODE_ENV === 'production') {
  throw new Error('ORCHESTRATOR_REDIS_URL must be set in production')
}

/**
 * Cliente Redis compartilhado para estado transversal do processo (dedup de
 * webhook etc.). Estado que precisa sobreviver a restart ou coexistir entre
 * réplicas NÃO pode ficar em Map em memória — CRM-047.
 *
 * lazyConnect: conecta no primeiro comando — importar o módulo (ex.: em
 * testes) não pode deixar uma conexão ociosa segurando o event loop.
 */
export const redis = new Redis({
  ...parseRedisConnection(redisUrl ?? 'redis://localhost:6382/2'),
  lazyConnect: true,
})

redis.on('error', (err) => {
  console.error('[redis] connection error:', err.message)
})
