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

const redisUrl =
  process.env.ORCHESTRATOR_REDIS_URL ?? 'redis://:chusterm_redis_pass@localhost:6382/2'

const connection = parseRedisConnection(redisUrl)

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
