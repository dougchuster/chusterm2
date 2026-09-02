import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const projectRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const inventoryPath = path.resolve(projectRoot, '../../docs/audit/INVENTARIO-ROTAS.md');
const surfacesPath = path.resolve(projectRoot, 'fixtures/non-route-surfaces.json');
const outputPath = path.resolve(projectRoot, 'fixtures/route-manifest.json');

const [inventory, surfacesSource] = await Promise.all([
  readFile(inventoryPath, 'utf8'),
  readFile(surfacesPath, 'utf8'),
]);

const routePattern = /`(\/(?:app|super_admin|manager|widget|hc|survey|installation|swagger)[^`\s]*)`/g;
const routes = [...inventory.matchAll(routePattern)]
  .map(match => match[1])
  .filter((route, index, all) => all.indexOf(route) === index)
  .sort();

const familyFor = route => {
  if (route.includes('/crm')) return 'crm';
  if (route.includes('/captain')) return 'captain';
  if (route.includes('/conversation') || route.includes('/inbox/')) return 'conversations';
  if (route.includes('/contact')) return 'contacts';
  if (route.includes('/report')) return 'reports';
  if (route.startsWith('/super_admin')) return 'super_admin';
  if (route.includes('/login') || route.includes('/auth')) return 'authentication';
  return 'other';
};

const manifest = {
  generated_from: path.relative(projectRoot, inventoryPath).replaceAll('\\', '/'),
  route_count: routes.length,
  routes: routes.map(route => ({ route, family: familyFor(route) })),
  non_route_surfaces: JSON.parse(surfacesSource),
};

await writeFile(outputPath, `${JSON.stringify(manifest, null, 2)}\n`, 'utf8');
console.log(`Manifesto gerado: ${routes.length} rotas + ${manifest.non_route_surfaces.length} superfícies internas.`);
