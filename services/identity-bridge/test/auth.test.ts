import { afterAll, beforeAll, describe, expect, it } from 'vitest'
import type { FastifyInstance } from 'fastify'
import jwt from 'jsonwebtoken'

// ─── Env (must be set before buildApp runs) ──────────────────────────────────
const TEST_SECRET = 'test-secret-key-with-32-bytes-minimum!!'
const TEST_SERVICE_TOKEN = 'test-service-token'
process.env.SERVICE_JWT_SECRET = TEST_SECRET
process.env.SERVICE_AUTH_TOKEN = TEST_SERVICE_TOKEN

const { buildApp } = await import('../src/app.js')

let app: FastifyInstance

beforeAll(async () => {
  app = await buildApp()
  await app.ready()
})

afterAll(async () => {
  await app.close()
})

const VALID_BODY = { userId: 10, accountId: 7, role: 'agent' }

function signToken(payload: object, options: jwt.SignOptions = {}): string {
  return jwt.sign(payload, TEST_SECRET, {
    algorithm: 'HS256',
    issuer: 'chusterm:identity-bridge',
    audience: 'chusterm:internal',
    ...options,
  })
}

describe('POST /auth/token (IB-C1)', () => {
  it('rejects requests without the service token', async () => {
    const res = await app.inject({ method: 'POST', url: '/auth/token', payload: VALID_BODY })
    expect(res.statusCode).toBe(401)
  })

  it('rejects a wrong service token', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/auth/token',
      headers: { 'x-service-token': 'wrong-token' },
      payload: VALID_BODY,
    })
    expect(res.statusCode).toBe(401)
  })

  it('fails closed (503) when SERVICE_AUTH_TOKEN is not configured', async () => {
    const saved = process.env.SERVICE_AUTH_TOKEN
    delete process.env.SERVICE_AUTH_TOKEN
    try {
      const res = await app.inject({
        method: 'POST',
        url: '/auth/token',
        headers: { 'x-service-token': TEST_SERVICE_TOKEN },
        payload: VALID_BODY,
      })
      expect(res.statusCode).toBe(503)
    } finally {
      process.env.SERVICE_AUTH_TOKEN = saved
    }
  })

  it('rejects roles outside the allowlist (IB-M1)', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/auth/token',
      headers: { 'x-service-token': TEST_SERVICE_TOKEN },
      payload: { ...VALID_BODY, role: 'superadmin' },
    })
    expect(res.statusCode).toBe(400)
  })

  it('issues a properly-claimed HS256 token with the service token', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/auth/token',
      headers: { 'x-service-token': TEST_SERVICE_TOKEN },
      payload: VALID_BODY,
    })
    expect(res.statusCode).toBe(200)
    const { token } = res.json() as { token: string }

    const decoded = jwt.decode(token, { complete: true })
    expect(decoded?.header.alg).toBe('HS256')

    const payload = jwt.verify(token, TEST_SECRET, {
      algorithms: ['HS256'],
      issuer: 'chusterm:identity-bridge',
      audience: 'chusterm:internal',
    }) as jwt.JwtPayload
    expect(payload.userId).toBe(10)
    expect(payload.accountId).toBe(7)
    expect(payload.role).toBe('agent')
  })
})

describe('verify options (IB-H1)', () => {
  it('/auth/validate rejects tokens without issuer/audience', async () => {
    const foreign = jwt.sign({ userId: 1, accountId: 1, role: 'agent' }, TEST_SECRET)
    const res = await app.inject({
      method: 'POST',
      url: '/auth/validate',
      payload: { token: foreign },
    })
    expect(res.statusCode).toBe(200)
    expect((res.json() as { valid: boolean }).valid).toBe(false)
  })

  it('/auth/validate accepts a properly-claimed token', async () => {
    const res = await app.inject({
      method: 'POST',
      url: '/auth/validate',
      payload: { token: signToken(VALID_BODY) },
    })
    expect(res.statusCode).toBe(200)
    expect((res.json() as { valid: boolean }).valid).toBe(true)
  })

  it('/auth/me rejects a missing header and accepts a valid token', async () => {
    const noAuth = await app.inject({ method: 'GET', url: '/auth/me' })
    expect(noAuth.statusCode).toBe(401)

    const ok = await app.inject({
      method: 'GET',
      url: '/auth/me',
      headers: { authorization: `Bearer ${signToken(VALID_BODY)}` },
    })
    expect(ok.statusCode).toBe(200)
    expect((ok.json() as { accountId: number }).accountId).toBe(7)
  })
})

describe('rate limiting (IB-H2)', () => {
  it('returns 429 after 30 requests/minute per IP', async () => {
    let saw429 = false
    for (let i = 0; i < 45; i += 1) {
      const res = await app.inject({
        method: 'POST',
        url: '/auth/token',
        headers: { 'x-service-token': TEST_SERVICE_TOKEN },
        payload: VALID_BODY,
      })
      if (res.statusCode === 429) {
        saw429 = true
        break
      }
    }
    expect(saw429).toBe(true)
  })
})
