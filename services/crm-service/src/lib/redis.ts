import { ConnectionOptions } from 'bullmq'

function parseRedisUrl(url: string): ConnectionOptions {
  const parsed = new URL(url)
  const connection: ConnectionOptions = {
    host: parsed.hostname,
    port: parseInt(parsed.port || '6379', 10),
    db: parseInt(parsed.pathname.replace('/', '') || '0', 10),
  }
  if (parsed.password) {
    connection.password = parsed.password
  }
  return connection
}

export const redisConnection: ConnectionOptions = parseRedisUrl(
  process.env.CRM_REDIS_URL ?? 'redis://localhost:6379/1'
)
