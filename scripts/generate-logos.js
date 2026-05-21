#!/usr/bin/env node
// Gera todos os logos e favicons a partir do SVG do logo animado da tela de login
'use strict';

const sharp = require(process.env.SHARP_MODULE || 'sharp');
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..', 'core', 'public');
const JS_ASSETS = path.join(__dirname, '..', 'core', 'app', 'javascript');
const BRAND = path.join(ROOT, 'brand-assets');

// SVG base do logo (estático — pose fixada em 45°/−30°)
const SVG = `<svg viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="node-grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#06b6d4"/>
      <stop offset="100%" stop-color="#3b82f6"/>
    </linearGradient>
    <linearGradient id="ring-grad" x1="100%" y1="100%" x2="0%" y2="0%">
      <stop offset="0%" stop-color="#ec4899"/>
      <stop offset="100%" stop-color="#a855f7"/>
    </linearGradient>
  </defs>
  <circle cx="32" cy="32" r="24" stroke="url(#ring-grad)" stroke-width="6" stroke-linecap="round" stroke-dasharray="80 30" transform="rotate(45 32 32)"/>
  <circle cx="32" cy="32" r="16" stroke="url(#node-grad)" stroke-width="5" stroke-linecap="round" stroke-dasharray="40 20" transform="rotate(-30 32 32)"/>
  <circle cx="32" cy="32" r="8" fill="url(#node-grad)"/>
  <circle cx="56" cy="32" r="4" fill="#ec4899"/>
  <circle cx="8" cy="32" r="4" fill="#06b6d4"/>
</svg>`;

// Variante com badge de notificação (bolinha vermelha canto superior direito)
const SVG_BADGE = `<svg viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="node-grad" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#06b6d4"/>
      <stop offset="100%" stop-color="#3b82f6"/>
    </linearGradient>
    <linearGradient id="ring-grad" x1="100%" y1="100%" x2="0%" y2="0%">
      <stop offset="0%" stop-color="#ec4899"/>
      <stop offset="100%" stop-color="#a855f7"/>
    </linearGradient>
  </defs>
  <circle cx="32" cy="32" r="24" stroke="url(#ring-grad)" stroke-width="6" stroke-linecap="round" stroke-dasharray="80 30" transform="rotate(45 32 32)"/>
  <circle cx="32" cy="32" r="16" stroke="url(#node-grad)" stroke-width="5" stroke-linecap="round" stroke-dasharray="40 20" transform="rotate(-30 32 32)"/>
  <circle cx="32" cy="32" r="8" fill="url(#node-grad)"/>
  <circle cx="56" cy="32" r="4" fill="#ec4899"/>
  <circle cx="8" cy="32" r="4" fill="#06b6d4"/>
  <circle cx="54" cy="10" r="10" fill="#ef4444"/>
</svg>`;

// Logo horizontal light (ícone + texto) para brand-assets
const SVG_LOGO_LIGHT = `<svg viewBox="0 0 200 64" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="ng" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#06b6d4"/>
      <stop offset="100%" stop-color="#3b82f6"/>
    </linearGradient>
    <linearGradient id="rg" x1="100%" y1="100%" x2="0%" y2="0%">
      <stop offset="0%" stop-color="#ec4899"/>
      <stop offset="100%" stop-color="#a855f7"/>
    </linearGradient>
  </defs>
  <circle cx="32" cy="32" r="24" stroke="url(#rg)" stroke-width="6" stroke-linecap="round" stroke-dasharray="80 30" transform="rotate(45 32 32)"/>
  <circle cx="32" cy="32" r="16" stroke="url(#ng)" stroke-width="5" stroke-linecap="round" stroke-dasharray="40 20" transform="rotate(-30 32 32)"/>
  <circle cx="32" cy="32" r="8" fill="url(#ng)"/>
  <circle cx="56" cy="32" r="4" fill="#ec4899"/>
  <circle cx="8" cy="32" r="4" fill="#06b6d4"/>
  <text x="76" y="26" font-family="Inter, system-ui, sans-serif" font-size="17" font-weight="700" fill="#1e1b4b">Chuste</text>
  <text x="76" y="44" font-family="Inter, system-ui, sans-serif" font-size="13" font-weight="500" fill="#6366f1">RM</text>
</svg>`;

const SVG_LOGO_DARK = `<svg viewBox="0 0 200 64" fill="none" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="ng" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" stop-color="#06b6d4"/>
      <stop offset="100%" stop-color="#3b82f6"/>
    </linearGradient>
    <linearGradient id="rg" x1="100%" y1="100%" x2="0%" y2="0%">
      <stop offset="0%" stop-color="#ec4899"/>
      <stop offset="100%" stop-color="#a855f7"/>
    </linearGradient>
  </defs>
  <circle cx="32" cy="32" r="24" stroke="url(#rg)" stroke-width="6" stroke-linecap="round" stroke-dasharray="80 30" transform="rotate(45 32 32)"/>
  <circle cx="32" cy="32" r="16" stroke="url(#ng)" stroke-width="5" stroke-linecap="round" stroke-dasharray="40 20" transform="rotate(-30 32 32)"/>
  <circle cx="32" cy="32" r="8" fill="url(#ng)"/>
  <circle cx="56" cy="32" r="4" fill="#ec4899"/>
  <circle cx="8" cy="32" r="4" fill="#06b6d4"/>
  <text x="76" y="26" font-family="Inter, system-ui, sans-serif" font-size="17" font-weight="700" fill="#ffffff">Chuste</text>
  <text x="76" y="44" font-family="Inter, system-ui, sans-serif" font-size="13" font-weight="500" fill="#818cf8">RM</text>
</svg>`;

async function toBuffer(svgStr, size) {
  return sharp(Buffer.from(svgStr), { density: Math.ceil(size * 3) })
    .resize(size, size)
    .png({ compressionLevel: 9 })
    .toBuffer();
}

async function savePng(svgStr, dest, size) {
  const buf = await toBuffer(svgStr, size);
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.writeFileSync(dest, buf);
  console.log(`  ✓ ${path.relative(path.join(__dirname, '..'), dest)} [${size}x${size}]`);
}

async function saveSvg(svgStr, dest) {
  fs.mkdirSync(path.dirname(dest), { recursive: true });
  fs.writeFileSync(dest, svgStr, 'utf8');
  console.log(`  ✓ ${path.relative(path.join(__dirname, '..'), dest)} [SVG]`);
}

async function main() {
  console.log('\n🎨 Gerando logos e favicons...\n');

  console.log('── Favicons ───────────────────────────────────────');
  for (const size of [16, 32, 96, 512]) {
    await savePng(SVG, path.join(ROOT, `favicon-${size}x${size}.png`), size);
  }

  console.log('\n── Favicons com badge ─────────────────────────────');
  for (const size of [16, 32, 96]) {
    await savePng(SVG_BADGE, path.join(ROOT, `favicon-badge-${size}x${size}.png`), size);
  }

  console.log('\n── Apple icons ────────────────────────────────────');
  for (const size of [57, 60, 72, 76, 114, 120, 144, 152, 180]) {
    await savePng(SVG, path.join(ROOT, `apple-icon-${size}x${size}.png`), size);
  }
  await savePng(SVG, path.join(ROOT, 'apple-icon.png'), 180);
  await savePng(SVG, path.join(ROOT, 'apple-icon-precomposed.png'), 180);
  await savePng(SVG, path.join(ROOT, 'apple-touch-icon.png'), 180);
  await savePng(SVG, path.join(ROOT, 'apple-touch-icon-precomposed.png'), 180);

  console.log('\n── Android icons ──────────────────────────────────');
  for (const size of [36, 48, 72, 96, 144, 192]) {
    await savePng(SVG, path.join(ROOT, `android-icon-${size}x${size}.png`), size);
  }

  console.log('\n── Microsoft icons ────────────────────────────────');
  for (const size of [70, 144, 150, 310]) {
    await savePng(SVG, path.join(ROOT, `ms-icon-${size}x${size}.png`), size);
  }

  console.log('\n── Brand assets SVG ───────────────────────────────');
  await saveSvg(SVG_LOGO_LIGHT, path.join(BRAND, 'logo.svg'));
  await saveSvg(SVG_LOGO_DARK,  path.join(BRAND, 'logo_dark.svg'));
  await saveSvg(SVG,            path.join(BRAND, 'logo_thumbnail.svg'));

  console.log('\n── Design system ──────────────────────────────────');
  await saveSvg(SVG, path.join(JS_ASSETS, 'design-system', 'images', 'logo-thumbnail.svg'));
  await savePng(SVG_LOGO_LIGHT, path.join(JS_ASSETS, 'design-system', 'images', 'logo.png'), 400);
  await savePng(SVG_LOGO_DARK,  path.join(JS_ASSETS, 'design-system', 'images', 'logo-dark.png'), 400);

  console.log('\n── Widget e Dashboard bubble ──────────────────────');
  await saveSvg(SVG, path.join(JS_ASSETS, 'widget', 'assets', 'images', 'logo.svg'));
  await saveSvg(SVG, path.join(JS_ASSETS, 'dashboard', 'assets', 'images', 'bubble-logo.svg'));

  console.log('\n✅ Concluído! Todos os logos e favicons foram gerados.\n');
}

main().catch(err => { console.error('\n❌ Erro:', err.message); process.exit(1); });
