# ─── Stage: development ──────────────────────────────────────────────────────
FROM node:20-alpine AS development

WORKDIR /app

COPY package.json ./

RUN npm install

COPY . .

EXPOSE 4001

CMD ["npm", "run", "dev"]

# ─── Stage: builder ───────────────────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

COPY package.json ./

RUN npm install

COPY . .

RUN npm run build

# ─── Stage: production ────────────────────────────────────────────────────────
FROM node:20-alpine AS production

WORKDIR /app

ENV NODE_ENV=production

COPY package.json ./

RUN npm install --omit=dev

COPY --from=builder /app/dist ./dist

EXPOSE 4001

CMD ["node", "dist/server.js"]
