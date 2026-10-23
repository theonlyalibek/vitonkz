#!/usr/bin/env bash
# Builds the hosting-ready site from v2/ (no /v2/ prefix, indexable) and commits it to the "production" branch.
# Plesk (ps.kz) deploys that branch into httpdocs. Usage: tools/build_production.sh [--push]
set -euo pipefail
ROOT=$(git rev-parse --show-toplevel)
OUT=$(mktemp -d)
cp -r "$ROOT"/v2/. "$OUT"/
find "$OUT" -name '*.html' -exec sed -i -e 's#/v2/#/#g' -e 's#<meta name="robots" content="noindex, nofollow">##g' {} +
cp "$ROOT"/404.html "$ROOT"/llms.txt "$OUT"/
sed -i 's#/v2/#/#g' "$OUT"/404.html
cp "$ROOT"/tools/production/htaccess "$OUT"/.htaccess
cp "$ROOT"/tools/production/robots.txt "$OUT"/robots.txt
{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
  (cd "$OUT" && find ru kk -name index.html | sort | sed 's#index.html$##') | while read -r p; do echo "  <url><loc>https://viton.kz/$p</loc></url>"; done
  echo '</urlset>'
} > "$OUT"/sitemap.xml
printf '# VITON.KZ — production\n\nГотовый сайт для хостинга ps.kz (Plesk разворачивает эту ветку в httpdocs).\nНе править вручную: собирается из v2/ скриптом tools/build_production.sh.\n' > "$OUT"/README.md

SRC=$(git rev-parse --short HEAD)
WT=$(mktemp -d)
if git ls-remote --exit-code --heads origin production >/dev/null 2>&1; then
  git fetch -q origin production
  git worktree add -q "$WT" -B production origin/production
else
  git worktree add -q --detach "$WT"
  (cd "$WT" && git checkout -q --orphan production)
fi
(cd "$WT" && git rm -rqf . 2>/dev/null || true; cp -r "$OUT"/. "$WT"/ && git add -A && git commit -qm "production: сборка из $SRC" || echo "nothing to commit")
[ "${1:-}" = "--push" ] && (cd "$WT" && git push -u origin production)
git worktree remove --force "$WT"
rm -rf "$OUT"
