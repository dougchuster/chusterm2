import { Queue } from 'bullmq'
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

const connection = parseRedisConnection(redisUrl ?? 'redis://localhost:6382/2')

/**
 * BullMQ queue for async (fire-and-forget) skill execution.
 * Producers enqueue jobs here; a separate worker process (not in this service's
 * HTTP path) would consume them. The queue is exported so routes can enqueue.
 */
export const asyncSkillQueue = new Queue('async-skills', {
  connection,
  defaultJobOptions: {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 1000,
    },
    removeOnComplete: { count: 500 },
    removeOnFail: { count: 200 },
  },
})

// Without an 'error' listener, Redis connection errors are re-emitted as
// unhandled EventEmitter 'error' events and crash the process.
asyncSkillQueue.on('error', (err) => {
  console.error('[async-skills] queue error:', err.message)
})
