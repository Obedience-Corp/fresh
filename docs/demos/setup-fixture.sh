#!/usr/bin/env bash
# Run only inside the disposable recording container. No host repositories touched.
set -euo pipefail
if [ ! -f /.dockerenv ] || [ -e /demo ]; then
  echo 'Use a fresh Docker container for the recording fixture.' >&2
  exit 2
fi
export GIT_AUTHOR_NAME=Fresh-demo GIT_AUTHOR_EMAIL=demo@example.invalid
export GIT_COMMITTER_NAME=Fresh-demo GIT_COMMITTER_EMAIL=demo@example.invalid
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
mkdir -p /demo
camp init /demo/camp --name demo --description 'Fresh recording fixture' --mission 'Show the real Fresh TUI and cleanup' --no-skills --no-git >/dev/null
git init -q --bare --initial-branch=main /demo/origin.git
git clone -q /demo/origin.git /demo/site
cd /demo/site
cat > package.json <<'JSON'
{"name":"fresh-demo-site","version":"1.0.0","private":true,"scripts":{"build":"node build.js"}}
JSON
cat > build.js <<'JS'
const fs = require('node:fs');
fs.mkdirSync('dist', { recursive: true });
fs.copyFileSync('index.html', 'dist/index.html');
console.log('Built dist/index.html');
JS
printf '<h1>My project</h1>\n' > index.html
printf 'dist/\nnode_modules/\n' > .gitignore
npm install --package-lock-only --ignore-scripts --no-audit --no-fund >/dev/null
git add .
git commit -qm 'Create demo site'
git push -qu origin main
git switch -qc feat/homepage
printf '<h1>My project</h1><p>Ready to ship.</p>\n' > index.html
git commit -qam 'Finish homepage'
git switch -q main
git merge -q --no-ff feat/homepage -m 'Merge homepage'
git push -q origin main
camp project link /demo/site --campaign demo --yes --no-commit >/dev/null
