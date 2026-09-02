const fs = require('node:fs');
const path = require('node:path');
const husky = require('husky');

if (process.env.HUSKY === '0') {
  process.exit(0);
}

const packageRoot = path.resolve(__dirname, '..');
const gitRootCandidates = [packageRoot, path.resolve(packageRoot, '..')];
const gitRoot = gitRootCandidates.find(candidate =>
  fs.existsSync(path.join(candidate, '.git'))
);

if (!gitRoot) {
  process.exit(0);
}

const hooksDirectory = path.relative(
  gitRoot,
  path.join(packageRoot, '.husky')
);

process.chdir(gitRoot);
husky.install(hooksDirectory.replaceAll(path.sep, '/'));
