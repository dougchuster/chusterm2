import { Queue } from 'bullmq'
import { redisConnection } from '../lib/redis.js'

export const leadScoringQueue = new Queue('lead-scoring', {
  connection: redisConnection,
  defaultJobOptions: {
    attempts: 3,
    backoff: {
      type: 'exponential',
      delay: 5000,
    },
    removeOnComplete: { count: 100 },
    removeOnFail: { count: 500 },
  },
})
