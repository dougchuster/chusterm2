import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest'
import type { FastifyInstance } from 'fastify'
import { PgDialect } from 'drizzle-orm/pg-core'

// ─── Env (must be set before buildApp runs) ──────────────────────────────────
const TEST_SECRET = 'test-secret-key-with-32-bytes-minimum!!'
process.env.SERVICE_JWT_SECRET = TEST_SECRET

// ─── Mocked db: chainable query builder with canned results + call capture ───
const state = {
  results: [] as unknown[],
  wheres: [] as unknown[],
  sets: [] as Record<string, unknown>[],
  values: [] as Record<string, unknown>[],
}

function chainable(): any {
  const thenable = {
    then(onFulfilled?: any, onRejected?: any) {
      const result = state.results.length > 0 ? state.results.shift() : []
      return Promise.resolve(result).then(onFulfilled, onRejected)
    },
  }
  return new Proxy(thenable, {
    get(target, prop) {
      if (prop === 'then') return target.then.bind(target)
      return (...args: any[]) => {
        if (prop === 'where') state.wheres.push(args[0])
        if (prop === 'set') state.sets.push(args[0])
        if (prop === 'values') state.values.push(args[0])
        return chainable()
      }
    },
  })
}

const dbMock = new Proxy({}, { get: () => () => chainable() })

vi.mock('../src/db/client.js', () => ({ db: dbMock, sql: {} }))
vi.mock('../src/queues/index.js', () => ({ leadScoringQueue: { add: vi.fn(async () => ({})) } }))
vi.mock('../src/lib/audit.js', () => ({ writeAuditEvent: vi.fn(async () => undefined) }))

const { buildApp } = await import('../src/app.js')

const dialect = new PgDialect()
const whereSql = (index: number) => dialect.sqlToQuery(state.wheres[index] as any)

let app: FastifyInstance

function tokenFor(accountId: number, withClaims = true): string {
  return app.jwt.sign(
    { userId: 10, accountId, role: 'agent' },
    withClaims
      ? { iss: 'chusterm:identity-bridge', aud: 'chusterm:internal' }
      : {},
  )
}

beforeAll(async () => {
  app = buildApp()
  await app.ready()
})

afterAll(async () => {
  await app.close()
})

beforeEach(() => {
  state.results = []
  state.wheres = []
  state.sets = []
  state.values = []
})

describe('auth guard (CRM-C1)', () => {
  it('allows /health without a token', async () => {
    const res = await app.inject({ method: 'GET', url: '/health' })
    expect(res.statusCode).toBe(200)
  })

  it('rejects requests without a token', async () => {
    const res = await app.inject({ method: 'GET', url: '/deals' })
    expect(res.statusCode).toBe(401)
  })

  it('rejects a malformed token', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/deals',
      headers: { authorization: 'Bearer not-a-token' },
    })
    expect(res.statusCode).toBe(401)
  })

  it('rejects a token without the expected issuer/audience', async () => {
    const res = await app.inject({
      method: 'GET',
      url: '/deals',
      headers: { authorization: `Bearer ${tokenFor(1, false)}` },
    })
    expect(res.statusCode).toBe(401)
  })

  it('accepts a valid token', async () => {
    state.results = [[], [{ count: 0 }]]
    const res = await app.inject({
      method: 'GET',
      url: '/deals',
      headers: { authorization: `Bearer ${tokenFor(1)}` },
    })
    expect(res.statusCode).toBe(200)
  })

  it('fails fast when SERVICE_JWT_SECRET is missing', () => {
    const saved = process.env.SERVICE_JWT_SECRET
    delete process.env.SERVICE_JWT_SECRET
    try {
      expect(() => buildApp()).toThrow(/SERVICE_JWT_SECRET/)
    } finally {
      process.env.SERVICE_JWT_SECRET = saved
    }
  })
})

describe('IDOR protection (CRM-C2/CRM-H1)', () => {
  it('scopes GET /deals/:id by the token accountId and 404s cross-account', async () => {
    state.results = [[]] // account predicate filters out account B's row
    const res = await app.inject({
      method: 'GET',
      url: '/deals/11111111-1111-1111-1111-111111111111',
      headers: { authorization: `Bearer ${tokenFor(1)}` },
    })
    expect(res.statusCode).toBe(404)
    const { sql, params } = whereSql(0)
    expect(sql).toContain('account_id')
    expect(params).toContain(1)
  })

  it('scopes GET /lead-profiles/:id by the token accountId', async () => {
    state.results = [[]]
    const res = await app.inject({
      method: 'GET',
      url: '/lead-profiles/22222222-2222-2222-2222-222222222222',
      headers: { authorization: `Bearer ${tokenFor(1)}` },
    })
    expect(res.statusCode).toBe(404)
    expect(whereSql(0).params).toContain(1)
  })

  it('ignores body accountId on PATCH and never writes score/leadProfileId (CRM-H3)', async () => {
    const existing = {
      id: 'd1',
      accountId: 1,
      leadProfileId: 'lp1',
      stage: 'new',
      closedAt: null,
      ownerId: null,
    }
    const updated = { ...existing, title: 'New title' }
    state.results = [[existing], [updated], [{ id: 'lp1', accountId: 1, ownerId: null }], []]

    const res = await app.inject({
      method: 'PATCH',
      url: '/deals/d1',
      headers: { authorization: `Bearer ${tokenFor(1)}` },
      payload: { accountId: 2, score: 999, leadProfileId: 'other', title: 'New title' },
    })

    expect(res.statusCode).toBe(200)
    expect(state.sets[0]).not.toHaveProperty('score')
    expect(state.sets[0]).not.toHaveProperty('leadProfileId')
    expect(state.sets[0]).not.toHaveProperty('accountId')
    expect(state.sets[0].title).toBe('New title')
    // both the read and the write are tenant-scoped
    expect(whereSql(0).params).toContain(1)
    expect(whereSql(1).params).toContain(1)
  })

  it('forces the token accountId on POST /deals', async () => {
    const created = { id: 'd1', accountId: 1, leadProfileId: 'lp1', ownerId: null }
    state.results = [[created], [{ id: 'lp1', accountId: 1, ownerId: null }], []]

    const res = await app.inject({
      method: 'POST',
      url: '/deals',
      headers: { authorization: `Bearer ${tokenFor(1)}` },
      payload: { accountId: 2, leadProfileId: '11111111-1111-1111-1111-111111111111', title: 'X' },
    })

    expect(res.statusCode).toBe(201)
    expect(state.values[0].accountId).toBe(1)
  })

  it('scopes pipeline-stage creation to the token account (CRM-H4)', async () => {
    state.results = [[{ id: 'pipe-1' }], [{ id: 'stage-1', accountId: 1, pipelineId: 'pipe-1' }]]

    const res = await app.inject({
      method: 'POST',
      url: '/pipelines/pipe-1/stages',
      headers: { authorization: `Bearer ${tokenFor(1)}` },
      payload: { accountId: 2, name: 'Stage' },
    })

    expect(res.statusCode).toBe(201)
    // pipeline was verified against the token's account
    expect(whereSql(0).sql).toContain('account_id')
    expect(whereSql(0).params).toContain(1)
    // stage stamped with the token's accountId, not the body's
    expect(state.values[0].accountId).toBe(1)
    expect(state.values[0].pipelineId).toBe('pipe-1')
  })

  it('never lets clients create system labels (CRM-H3)', async () => {
    state.results = [[{ id: 'l1', accountId: 1, isSystem: false }]]

    const res = await app.inject({
      method: 'POST',
      url: '/labels',
      headers: { authorization: `Bearer ${tokenFor(1)}` },
      payload: { accountId: 2, isSystem: true, category: 'rel', slug: 'x', displayName: 'X' },
    })

    expect(res.statusCode).toBe(201)
    expect(state.values[0].isSystem).toBe(false)
    expect(state.values[0].accountId).toBe(1)
  })
})
