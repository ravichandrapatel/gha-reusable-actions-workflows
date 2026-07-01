<!--
FILE_NAME: github-actions-artifacts-and-caches.md
DESCRIPTION: Analysis & POC document for GitHub Actions artifacts and Actions caches — mechanics, storage limits, lifecycles, exhaustion/eviction behavior, retention configuration, and full costing model. Written for migrating CI from Tekton (PVC + Nexus) to GitHub Actions on GitHub Enterprise Cloud enterprise "thecaptainhub" (3-4 organizations).
VERSION: 2.0.0
EXIT_CODES/SIGNALS: N/A (documentation)
STATUS: Draft for review (analysis + POC)
LAST_VERIFIED: 2026-07-01 (GitHub Enterprise Cloud, github.com hosted runners)
AUTHORS: DevOps / Platform Engineering
SOURCES: GitHub Docs — Dependency caching reference; Managing caches; Workflow artifacts; Store & share data; Removing workflow artifacts; Actions limits; GitHub Actions billing (product-billing); Product usage included with each plan; Managing GitHub Actions settings for a repository; Enforcing policies for GitHub Actions in your enterprise; Setting up budgets; actions/upload-artifact; actions/cache.
-->

# GitHub Actions Artifacts & Caches — Analysis and POC

**Enterprise:** `thecaptainhub` (GitHub Enterprise Cloud) · **Scope:** 3–4 primary organizations · **Runners:** GitHub-hosted
**Migration context:** Tekton Pipelines (PVC workspaces + Sonatype Nexus) → GitHub Actions

---

## Document control

| Field | Value |
|---|---|
| Purpose | Decide how to use, configure, limit, and pay for GitHub Actions **artifacts** and **caches** as part of the Tekton→GHA migration |
| Audience | Platform/DevOps engineering, org owners, enterprise billing owner |
| Type | Analysis + Proof-of-Concept plan |
| Status | Draft for review |
| Assumptions | Private/internal repos on GHEC; GitHub-hosted runners; billing at list price; figures verified 2026-07-01 and subject to change |

> All prices and quotas below are GitHub list values verified on 2026-07-01. GitHub states these limits and prices are subject to change — reconfirm against the `thecaptainhub` billing page before financial sign-off.

---

## 1. Executive summary

1. **Artifacts** and **caches** are two different systems with different lifecycles and different billing SKUs. Do not treat them as one "storage" line item.
2. **Artifact storage is a single pooled allowance for the whole enterprise account** (50 GB included on GHEC, **shared with GitHub Packages**), billed at **$0.25/GB-month** above the pool. One noisy org consumes the shared pool for all orgs.
3. **Cache storage is per-repository** (10 GB free on **every** repo, not pooled), billed at **$0.07/GB-month** — **and only if you raise a repo's cache limit above 10 GB**. At the default 10 GB limit, **cache is effectively free**.
4. **Cache lifecycle:** entries **not accessed for 7 days are deleted** (default; retention now configurable up to 90/365 days). When a repo's cache **size limit is exceeded, GitHub evicts the least-recently-used caches** to make room — uploads do not fail, but you lose cache hits (slower, costlier runs).
5. **Costing driver in a migration is almost always Actions minutes, not storage.** Storage is cheap; effective caching *reduces* minute spend. The main storage risk is **artifact retention** (default 90 days) silently filling the shared 50 GB pool.
6. **Recommended posture:** keep cache limits at the free 10 GB/repo default (raise only for proven heavy repos), aggressively shorten artifact `retention-days`, and put **budgets with "stop usage" at org/cost-center scope** so no single org can run away with spend.

### Migration mapping (Tekton → GitHub Actions)

| Tekton concept | Purpose | GitHub Actions equivalent | Notes |
|---|---|---|---|
| PVC workspace shared **between tasks in a pipeline** | Pass build outputs step→step / task→task | **Artifacts** (`upload-artifact`/`download-artifact`) for job→job; same-job steps just share the runner workspace | Artifacts are the durable, cross-job hand-off. No manual PVC lifecycle to manage. |
| PVC used as a **dependency cache** (e.g., `.m2`, `.npm`, `.gradle`) | Avoid re-downloading deps each run | **Actions cache** (`actions/cache` or `setup-*` caching) | Replaces the "warm PVC" pattern; keyed + auto-evicted, no volume to provision. |
| **Nexus** hosted repos (published build artifacts, release binaries) | Store/serve produced artifacts long-term | **GitHub Packages** (long-lived) and/or **Artifacts** (short-lived run outputs) | Packages share the same 50 GB pool as artifacts. Keep long-term binaries in Packages/registry, not as 400-day artifacts. |
| **Nexus** proxy/mirror of public registries | Speed + resilience of dependency fetches | **Actions cache** + optionally a proxy/mirror you host | Cache covers per-repo speed-up; a proxy still helps for supply-chain control. |
| PVC capacity planning / storage class | Provision volume size | **Cache size eviction limit** (per repo) + **artifact retention** (pool) | No pre-provisioning; you set *ceilings* and lifecycles instead. |

Key implication: the Tekton "one big PVC" mental model splits into **two** GitHub systems with **different scopes** (per-repo cache vs. account-pooled artifacts) and **different auto-cleanup** (LRU/idle eviction vs. retention expiry).

---

## 2. Artifacts — mechanics, limits, lifecycle

### 2.1 What they are

An artifact is a file or collection of files produced by a run, used to (a) persist output after a run and (b) pass data between jobs in the same workflow. Typical contents: build outputs/binaries, test results and screenshots, coverage reports, logs/core dumps.

Actions: `actions/upload-artifact`, `actions/download-artifact`.

### 2.2 Behavior that matters for the migration

- **Immutability (v4+):** artifacts are immutable in `upload-artifact@v4`. A second upload with the **same name in the same run fails** unless you set `overwrite: true` or use distinct names. Tekton pipelines that overwrote a shared PVC file across tasks must instead emit **distinct-named** artifacts (e.g., `build_pre`, `build_final`).
- **Integrity:** `upload-artifact` emits a SHA-256 `digest`; `download-artifact` re-validates it and warns on mismatch.
- **Cross-run / cross-repo download:** in v4 requires a token + run identifier.
- **Logs & job summaries do NOT count** against artifact storage — only uploaded artifacts do.
- **Deletion is permanent** and reclaims *current* storage but not *accrued* cost (see §4).

### 2.3 Retention lifecycle

Artifacts and logs auto-delete at end of retention.

| Repo type | Default | Configurable range |
|---|---|---|
| Public | 90 days | 1–90 days |
| Private/internal | 90 days | 1–400 days |

- Set at **enterprise → org → repo → per-artifact** (`retention-days:`), each level capped by the one above.
- Custom retention is **not retroactive**; applies to new artifacts/logs only.
- `retention-days: 0` = inherit default.

```yaml
- uses: actions/upload-artifact@v4
  with:
    name: build-output
    path: dist/
    retention-days: 7      # capped by repo/org/enterprise maximum
```

### 2.4 Storage limits & scope (artifacts)

- **Pooled, account-wide, shared with GitHub Packages.** Included on GHEC: **50 GB** across the whole enterprise account (artifacts + Packages combined).
- No per-repo artifact quota — any repo/org draws from the same pool.
- With a valid payment method, exceeding the pool **bills** (does not block) unless a **budget with "stop usage"** is set. Without a payment method, usage is blocked once the quota is exhausted.

---

## 3. Caches — mechanics, limits, lifecycle, exhaustion behavior

### 3.1 What it is / how it works

Caches store rarely-changing inputs (dependencies, toolchains, build layers) in **GitHub-owned cloud storage** and restore them on later runs to cut network time, runtime, and minute cost. Use `actions/cache` or `setup-*` built-in caching.

> On GHEC, caches for **self-hosted** runners are still stored on **GitHub-owned** storage. Only **GHES** supports customer-owned object storage (S3/Azure Blob).

**Key/version/match model:**

```yaml
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: ${{ runner.os }}-npm-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-npm-
```

- `key` (required, ≤ **512 chars**): usually `os + hashFiles(lockfile)` so a new cache is created automatically when deps change.
- **Hit** = exact `key` match → files restored, `cache-hit=true`. **Miss** = no exact match → fall back through `restore-keys`, and if the job succeeds a **new cache is written** under `key`.
- Caches are **immutable** — you never edit one, you write a new key.

**Scope / isolation:** caches are shared by **branch/tag**, not by workflow identity. A run can restore from its own branch and the default branch; a PR run can also restore from the base branch. Runs cannot restore caches from child/sibling branches or different tags. PR-created caches are scoped to the **merge ref** (`refs/pull/.../merge`) and are only restorable by re-runs of that PR.

**Security:** cache contents are unsigned and readable by anyone who can trigger a qualifying run/PR — **never cache secrets**. Low-trust triggers (`pull_request_target`, `issue_comment`, `workflow_run`, …) get **read-only** access to default-branch caches to limit cache poisoning; only `push`, `workflow_dispatch`, `repository_dispatch`, `delete`, `registry_package`, `page_build`, `schedule` may write the default-branch scope.

### 3.2 Lifecycle — "what happens if a cache is not used for X days"

- **Default idle expiry = 7 days.** GitHub **deletes any cache entry that has not been *accessed* (restored) for 7 days**. Every successful restore resets the 7-day clock, so an actively used cache effectively lives indefinitely (subject to the size limit below).
- **This 7-day default is now configurable** as a **"Cache retention"** setting (repo/org/enterprise): up to **90 days** (public repos) or **365 days** (private/internal), capped by the org/enterprise maximum. Raising retention keeps *idle* caches longer; it does **not** raise the size limit and does **not** guarantee survival if the size limit forces eviction.
- Net effect for X days: `X ≤ retention` and recently accessed → kept; `X > retention` with no access in that window → **automatically deleted**. A deleted cache is simply a future **cache miss** (the run rebuilds and re-uploads) — no job failure.

### 3.3 Exhaustion — "what happens if per-repo cache storage is exhausted"

- **Per-repo size limit default = 10 GB.** There is **no limit on the number** of caches, only total size per repository.
- When total cache size for a repo **exceeds its limit**, GitHub **evicts the least-recently-used (LRU) caches** until the repo is back under the limit. **Uploads keep succeeding** — GitHub makes room by deleting old entries.
- Consequence is **performance/cost, not failure**: evicted entries become future misses → slower runs → more minutes billed. Heavy branch-scoped churn (many PRs each writing caches) can cause **cache thrashing** (constant create/evict), which can even evict useful default-branch caches.
- **Read-only mode via budget:** separately from the size limit, if you raise a repo's limit above 10 GB *and* an Actions Cache Storage **budget** is exceeded, the cache goes **read-only** (restores work, new saves fail with a warning) until billing resolves or usage drops back under the free 10 GB.
- **Rate-limit exhaustion** (distinct from size): per repo **200 uploads/min, 1,500 downloads/min, 400 deletes/min**. Exceeding these makes the *operation* fail until reset (`Retry-After` header); not adjustable by support.

**Mitigations for exhaustion/thrashing:**
- Delete PR caches on `pull_request: closed`:

```yaml
name: cleanup-pr-caches
on:
  pull_request:
    types: [closed]
jobs:
  cleanup:
    runs-on: ubuntu-latest
    permissions:
      actions: write
    steps:
      - run: |
          gh cache list --ref "$BRANCH" --limit 100 --json id --jq '.[].id' \
            | xargs -r -n1 gh cache delete
        env:
          GH_TOKEN: ${{ github.token }}
          GH_REPO:  ${{ github.repository }}
          BRANCH:   refs/pull/${{ github.event.pull_request.number }}/merge
```

- Scope cache keys tightly (per-lockfile hash) so unrelated changes don't invalidate everything.
- Only raise the size limit for repos that *prove* they need it (see POC, §7).

### 3.4 Cache limits summary

| Property | Default | Max configurable |
|---|---|---|
| Idle expiry / **cache retention** | 7 days | 90 days (public) / 365 days (private-internal), ≤ org/enterprise cap |
| **Size eviction limit** per repo | 10 GB | 10,000 GB (10 TB) per repo, ≤ org/enterprise cap |
| Key length | — | 512 characters |
| Uploads / downloads / deletes | — | 200 / 1,500 / 400 per minute per repo |

---

## 4. Pricing & costing model

GitHub Actions has **three** metered dimensions relevant here. Storage measured in **binary GB (GiB)**; storage billed on an **hourly GB-Hours accrual** converted to GB-months (÷ 744).

### 4.1 Included with GitHub Enterprise Cloud (private repos)

| Dimension | GHEC included | Scope |
|---|---|---|
| Actions minutes | 50,000 / month | Account (resets monthly) |
| Artifact storage (shared with Packages) | 50 GB | Account **pool** |
| Cache storage | 10 GB **per repository** | Per repo (not pooled) |
| Custom image storage (larger runners) | 150 GB | Account |

### 4.2 Overage rates

| SKU | Rate |
|---|---|
| Shared storage (artifacts + Packages) | **$0.25 / GB-month** |
| Actions cache | **$0.07 / GB-month** |
| Custom image storage | $0.07 / GB-month |
| Linux 2-core (x64) minute | $0.006 |
| Linux 1-core "slim" minute | $0.002 |
| Linux 2-core (arm64) minute | $0.005 |
| Windows 2-core minute | $0.010 |
| macOS 3/4-core minute | $0.062 |

> Minutes are free on **public** repos and self-hosted runners; **larger runners are always billed**, even on public repos and even with plan quota remaining.

### 4.3 The two critical cost nuances

1. **Cache is only billed if you configure a repo's cache limit ABOVE 10 GB.** At the default 10 GB eviction limit, a repo *cannot* accrue billable cache — it evicts (LRU) before exceeding the free line. So caching aggressively at the default limit is **free** and *saves* minute spend. You only pay for cache when you deliberately raise the ceiling.
2. **Deleting artifacts stops future accrual but not past accrual.** Storage already accrued earlier in the billing cycle stays on the bill; accrued storage resets to zero only at the start of the next billing cycle.

### 4.4 Worked examples

**Artifact storage (shared pool):** 3 GB for 10 days + 12 GB for 21 days in a month
`3×10×24 = 720` + `12×21×24 = 6,048` = `6,768` GB-Hours `÷ 744 = 9.097` GB-months.
Billed at $0.25/GB-month **only for the portion above the 50 GB pool**.

**Cache storage (per repo, limit raised >10 GB):** 3 GB for 10 days + 12 GB for 21 days
- 3 GB ≤ 10 GB free → 0 billable GB-Hours.
- 12 GB → only 2 GB is above the free 10 GB → `2×21×24 = 1,008` billable GB-Hours. Billed portion ≈ `1,008 ÷ 744 ≈ 1.35` GB-months × $0.07.

**Minutes (illustrative):** 5,000 minutes over quota (3,000 Linux + 2,000 Windows) = `3,000×$0.006 + 2,000×$0.010` = `$18 + $20 = $38`.

### 4.5 Where the money actually goes (migration reality check)

- **Minutes dominate.** For most CI migrations, minute spend ≫ storage spend. Effective caching lowers minutes and often *pays for itself* many times over — and at the default cache limit it costs nothing.
- **Artifact pool is the sleeper risk.** 90-day default retention across many repos/orgs silently fills the shared 50 GB pool → $0.25/GB-month overage. This is the storage line to actively govern.
- **Right-size runners.** Linux slim/2-core is dramatically cheaper than Windows/macOS/larger runners; runner choice moves the bill far more than cache/artifact storage.

---

## 5. Configuration guide — limits & lifecycles

Precedence everywhere: **Enterprise sets the ceiling → Organization configures within it → Repository configures within the org's.** Lower levels can never exceed a higher level's maximum.

### 5.1 Repository level

**Cache settings** (opt-in; requires a payment method / GHEC):
`Repo → Settings → Actions → General → "Cache settings"`
- **Cache retention:** days before automatic deletion. Default **7**; up to **90** (public) / **365** (private-internal) or the org cap.
- **Cache size eviction limit:** total cache size for the repo. Default **10 GB**; up to **10,000 GB** or the org cap. Exceeding it triggers **LRU eviction**.

**Artifact & log retention:**
`Repo → Settings → Actions → General → "Artifact and log retention"` → enter days → Save. (1–90 public / 1–400 private-internal; not retroactive.)

Per-artifact override: `retention-days:` on `upload-artifact` (≤ repo max).

### 5.2 Organization level

`Org → Settings → Actions → General` → configure **cache retention / size** and **artifact & log retention** maximums for the org. These are **caps** for member repos and cannot exceed the enterprise maximums. Org owners (or users with "Manage organization Actions policies") opt in per org.

### 5.3 Enterprise level (`thecaptainhub`)

`Enterprise → Policies → Actions`:
- **Artifact and log retention:** enterprise-wide maximum (1–90 public / 1–400 private-internal). Applies to all orgs.
- **Cache settings:** enterprise-wide maximums — **Cache retention** (≤ 90/365 days) and **Cache size eviction limit** (≤ 10,000 GB/repo). Note: *"If you increase the cache size eviction limit beyond the 10 GB included in your plan, you will be charged for additional storage."* Orgs/repos can only opt into limits **≤** these.

### 5.4 Budgets & spend control

`Enterprise/Org → Billing & Licensing → Budgets and alerts → New budget`:
- **Type:** Product-level (e.g., "Actions") or SKU-level (e.g., "Actions Cache Storage").
- **Scope:** enterprise, a single organization, a single repository, or a **cost center**.
- **"Stop usage when budget limit is reached":** hard-stops metered usage at the cap (Actions runners blocked / cache goes read-only) instead of billing overage. Without it, you get email alerts only.
- **Alerts:** thresholds at 75/90/100%; plus opt-in included-usage alerts at 90/100%.
- **Caution:** avoid **overlapping** budgets (product + SKU, or org + repo) — an exhausted higher-scope budget can unexpectedly block users relying on a lower scope.

### 5.5 Programmatic management

- **Caches:** `gh cache list` / `gh cache delete`; REST `/repos/{owner}/{repo}/actions/cache/...` (list, delete by key/ID, usage). Web UI: `Repo → Actions → Caches`.
- **Artifacts:** REST `/repos/{owner}/{repo}/actions/artifacts` (list, `expires_at`, delete). Web UI: run page → Artifacts.

---

## 6. Multi-org strategy for `thecaptainhub`

Because artifacts pool at the account and caches are per-repo, the governance model differs per system.

### 6.1 The shared artifact/Packages pool (the contended resource)

- All 3–4 orgs draw from **one 50 GB** artifact+Packages allowance.
- **Set an enterprise-wide artifact/log retention ceiling** (e.g., 14–30 days) so no org can pin 400-day artifacts and drain the pool.
- **Keep long-lived binaries in GitHub Packages / a registry**, not as long-retention artifacts (they share the pool but Packages is the right home for release artifacts you kept in Nexus).
- **Monitor the pool centrally** — it is the only globally contended storage line.

### 6.2 Per-repo cache (mostly self-limiting)

- Leave repos at the **default 10 GB cache limit** → caching is free and self-evicting; no pooling contention.
- Only raise the limit for repos with **proven** high cache-hit value (big monorepos, heavy toolchains) — and only those repos can then accrue $0.07/GB-month.
- Standardize a **PR-close cache cleanup** workflow across orgs (org-level starter workflow / reusable workflow) to prevent thrashing.

### 6.3 Guardrails to set now

| Control | Level | Recommended setting |
|---|---|---|
| Artifact/log retention ceiling | Enterprise | 14–30 days (raise per-repo only when justified) |
| Cache retention | Enterprise | Leave 7 days unless a repo proves it needs longer |
| Cache size limit | Enterprise/Org | Keep 10 GB default; raise per-repo case-by-case |
| Actions budget ("stop usage") | Per org or cost-center | Set to expected monthly + buffer; enable hard stop |
| Cache Storage SKU budget | Enterprise/org | Only relevant once limits raised >10 GB |
| Included-usage alerts | Enterprise | Enabled (90% / 100%) |

---

## 7. POC plan

Goal: validate that GitHub Actions caching + artifacts meet the performance and cost targets of the current Tekton (PVC/Nexus) pipelines before full cutover.

### 7.1 Scope & candidates

- Pick **2–3 representative repos per org** (one heavy build with large dependency tree, one typical service, one library/package publisher that used Nexus).
- Cover the languages you actually run (map to `setup-*` caching: Node/npm, Python/pip, Java/Maven-Gradle, Go).

### 7.2 Test scenarios (happy path + edge/failure)

| # | Scenario | What it validates |
|---|---|---|
| 1 | Cold run (no cache) vs. warm run (cache hit) | Baseline speed-up + minute savings vs. Tekton warm-PVC |
| 2 | Dependency change → lockfile hash changes | New cache key created; old key still restorable via `restore-keys` |
| 3 | Cache idle > 7 days (no runs) | Confirm auto-deletion; next run is a clean miss (no failure) |
| 4 | Push repo cache beyond a **lowered** test size limit (e.g., 1 GB) | Confirm LRU eviction; uploads still succeed; hit-rate drops |
| 5 | PR from a feature branch / fork | Confirm branch/merge-ref scope isolation; low-trust read-only behavior |
| 6 | Job→job artifact hand-off (v4 immutability) | Confirm distinct-name pattern replaces PVC file overwrite |
| 7 | Artifact retention = 3 days | Confirm auto-expiry and that logs/summaries don't count |
| 8 | Rate-limit probe (optional) | Behavior when exceeding 200 uploads/min (expect `Retry-After`) |
| 9 | Budget hard-stop dry run (non-prod org) | Confirm "stop usage" blocks/goes read-only as expected |

### 7.3 Metrics to capture

- Cache **hit rate** (%), restore time, cache size per repo (`gh cache list`, cache usage API).
- Wall-clock and **billable minutes** per pipeline: cold vs. warm; compare to Tekton baseline.
- Artifact **pool consumption** trend across POC orgs (billing usage report).
- Estimated monthly $ = minutes + artifact overage + (cache overage only if limits raised).

### 7.4 Exit criteria

- Warm-run time and minute cost ≤ agreed target vs. Tekton.
- Cache hit rate ≥ target (e.g., ≥ 80%) on steady-state branches.
- No unexpected artifact-pool growth after retention ceiling applied.
- Documented per-repo decision: keep 10 GB default vs. raise limit (with cost).

---

## 8. Recommendations

1. **Default everything to free-tier posture:** cache limit 10 GB/repo, cache retention 7 days. Caching is then free and reduces minute spend.
2. **Govern the artifact pool at the enterprise:** set a short artifact/log retention ceiling (14–30 days); use `retention-days` per workflow; move Nexus-style long-term binaries to **GitHub Packages**.
3. **Adopt org-wide PR-close cache cleanup** to prevent thrashing.
4. **Set org/cost-center Actions budgets with "stop usage"**; enable 90/100% alerts; avoid overlapping product+SKU budgets.
5. **Right-size runners** (Linux slim/2-core default) — the largest cost lever by far.
6. **Only raise cache limits** for repos the POC proves benefit; those become the only cache-billable repos ($0.07/GB-month).
7. **Do not store secrets** in caches or artifacts; treat restored caches as untrusted input; keep low-trust triggers restore-only.

### Decision matrix — artifact vs. cache vs. package

| Need | Use |
|---|---|
| Pass build output between jobs in a run | **Artifact** |
| Keep test/coverage/logs to inspect for N days | **Artifact** (short `retention-days`) |
| Speed up dependency/toolchain install | **Cache** (default 10 GB, free) |
| Long-lived release binaries / what Nexus hosted | **GitHub Packages** / registry |
| Authoritative, must-exist output | **Artifact/Package** (never cache — caches evict) |

---

## 9. Quick reference (hard numbers)

| Item | Value |
|---|---|
| Artifact default retention | 90 days (1–90 public / 1–400 private-internal) |
| Artifact/shared storage included (GHEC) | 50 GB (shared with Packages, account pool) |
| Shared storage overage | $0.25 / GB-month (GB-Hours ÷ 744) |
| Cache idle expiry (default) | 7 days without access |
| Cache retention (configurable) | up to 90 (public) / 365 (private-internal) days |
| Cache size limit (default) | 10 GB per repo |
| Cache size limit (max) | 10,000 GB per repo (org/enterprise-gated) |
| Cache included | 10 GB per repo (not pooled, all plans) |
| Cache overage | $0.07 / GB-month (only if limit raised > 10 GB) |
| Cache key max length | 512 chars |
| Cache rate limits | 200 up / 1,500 down / 400 delete — per minute per repo |
| Actions minutes included (GHEC) | 50,000 / month |
| Minute rates | Linux $0.006 · Linux slim $0.002 · Win $0.010 · macOS $0.062 |

---

## 10. Sources (GitHub Docs, verified 2026-07-01)

- [Dependency caching reference](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching)
- [Managing caches](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manage-caches)
- [Workflow artifacts](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflow-artifacts)
- [Store and share data with workflow artifacts](https://docs.github.com/en/actions/tutorials/store-and-share-data)
- [Removing workflow artifacts](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/remove-workflow-artifacts)
- [Actions limits](https://docs.github.com/en/actions/reference/limits)
- [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions)
- [Product usage included with each plan](https://docs.github.com/en/billing/reference/product-usage-included)
- [Managing GitHub Actions settings for a repository](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository)
- [Disabling or limiting GitHub Actions for your organization](https://docs.github.com/en/organizations/managing-organization-settings/disabling-or-limiting-github-actions-for-your-organization)
- [Enforcing policies for GitHub Actions in your enterprise](https://docs.github.com/en/enterprise-cloud@latest/admin/enforcing-policies/enforcing-policies-for-your-enterprise/enforcing-policies-for-github-actions-in-your-enterprise)
- [Setting up budgets to control spending on metered products](https://docs.github.com/en/billing/how-tos/set-up-budgets)
- [actions/upload-artifact](https://github.com/actions/upload-artifact) · [actions/download-artifact](https://github.com/actions/download-artifact) · [actions/cache](https://github.com/actions/cache)

> Reconfirm all quotas/prices on the `thecaptainhub` enterprise billing page before financial planning; GitHub states these are subject to change.
