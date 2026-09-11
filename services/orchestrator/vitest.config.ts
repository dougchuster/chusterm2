import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    include: ['test/**/*.test.ts'],
    // Legacy suite runs on node:test via `npm test` (tsx --test).
    exclude: ['test/orchestrator.test.ts', 'node_modules/**'],
  },
})
