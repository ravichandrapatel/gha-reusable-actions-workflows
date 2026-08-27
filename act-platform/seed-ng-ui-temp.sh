#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: seed-ng-ui-temp.sh
# DESCRIPTION: Build a throwaway ng-ui git repo + house overlay under temp/ for act.
# VERSION: 1.0.0
# EXIT_CODES/SIGNALS: 0 ok, 1 fail
# AUTHORS: Platform Team
# =============================================================================
# temp/ is gitignored. Inventory is patched only in the overlay copy
# (actions/common/check-inventory/inventory.json).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${ROOT}/temp/ng-ui-act-fixture"
MAP="${ROOT}/temp/gha-local-map"
REPO_NAME="ng-ui-act-fixture"

mkdir -p "${APP}/.github/workflows" "${APP}/src" "${MAP}"

bash "${ROOT}/act-platform/sync-workflows-for-act.sh" workflows/programming/ng-ui-build-pipeline

echo "[DBG] overlay ${MAP}"
rm -rf "${MAP}"
mkdir -p "${MAP}/.github/workflows"
rsync -a "${ROOT}/actions/" "${MAP}/actions/"
cp "${ROOT}/.github/workflows/ng-ui-build-pipeline.yml" "${MAP}/.github/workflows/ng-ui-build-pipeline.yml"
printf '%s\n' "[\"${REPO_NAME}\"]" > "${MAP}/actions/common/check-inventory/inventory.json"

cat > "${APP}/project.values" <<'EOF'
APPLICATION_NAME=ng-ui-act-fixture
ORGANIZATION=actorg
PRODUCT=actproduct
PROJECT_DESCRIPTION=throwaway ng-ui for local act
CMDBIDNPD=npd-0
CMDBIDPRD=prd-0
TEAMAADGROUPNPG=npg
TEAAADGROUPPRD=prd
EOF

cat > "${APP}/build.values" <<'EOF'
BUILDER_BASE_IMAGE=unused
CPGBUILD_APP_ORIGIN=
EOF

cat > "${APP}/package.json" <<'EOF'
{
  "name": "ng-ui-act-fixture",
  "version": "0.0.1",
  "private": true,
  "engines": { "node": "20" },
  "scripts": {
    "lint": "echo lint-ok",
    "test": "mkdir -p coverage && echo ok > coverage/lcov.info",
    "build": "mkdir -p dist && echo ok > dist/index.html"
  }
}
EOF

cat > "${APP}/package-lock.json" <<'EOF'
{
  "name": "ng-ui-act-fixture",
  "version": "0.0.1",
  "lockfileVersion": 3,
  "requires": true,
  "packages": {
    "": {
      "name": "ng-ui-act-fixture",
      "version": "0.0.1",
      "engines": { "node": "20" }
    }
  }
}
EOF

echo "export class App {}" > "${APP}/src/app.ts"

cat > "${APP}/.github/workflows/ci.yml" <<'EOF'
name: app-ci
on:
  push:
    branches: [main, develop]
  workflow_dispatch:
permissions:
  contents: read
jobs:
  pipeline:
    uses: ravichandrapatel/gha-reusable-actions-workflows/.github/workflows/ng-ui-build-pipeline.yml@ng-ui-build-pipeline/v1
    with:
      sonar_host_url: https://sonar.example.invalid
      runner: ubuntu-latest
    secrets: inherit
EOF

mkdir -p "${APP}/.act/events"
cat > "${APP}/.act/events/push.json" <<EOF
{
  "ref": "refs/heads/main",
  "before": "0000000000000000000000000000000000000000",
  "after": "1111111111111111111111111111111111111111",
  "repository": {
    "full_name": "ravichandrapatel/${REPO_NAME}",
    "name": "${REPO_NAME}",
    "owner": { "login": "ravichandrapatel" },
    "clone_url": "https://github.com/ravichandrapatel/${REPO_NAME}.git"
  },
  "head_commit": { "message": "DCDT-1 feat: fixture" }
}
EOF

if [[ ! -d "${APP}/.git" ]]; then
  git -C "${APP}" init -b main
  git -C "${APP}" config user.email "act@local"
  git -C "${APP}" config user.name "act-local"
  git -C "${APP}" remote add origin "https://github.com/ravichandrapatel/${REPO_NAME}.git" || true
fi
git -C "${APP}" add -A
if ! git -C "${APP}" diff --cached --quiet; then
  git -C "${APP}" commit -m "DCDT-1 feat: throwaway ng-ui fixture for act"
fi

echo "[OK] app=${APP}"
echo "[OK] map=${MAP}"
echo "[NEXT] ./act-platform/run-tagged-act.sh --component workflows/programming/ng-ui-build-pipeline --app-dir ${APP} --map-dir ${MAP} -e push -j pipeline"
