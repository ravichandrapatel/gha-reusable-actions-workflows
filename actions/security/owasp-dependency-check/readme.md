# OWASP Dependency Check

Run **OWASP Dependency-Check** in CI using a pre-built container image. The action uses **Podman** only (no Docker) and is intended for runners that have Podman installed—for example, ARC (Actions Runner Controller) runner pods. **Proxy-related options are not exposed.**

The container image is built and pushed by this repo’s **OWASP Dependency-Check (nightly)** workflow. [Dependency-Check CLI arguments](https://dependency-check.github.io/DependencyCheck/dependency-check-cli/arguments.html) are exposed as action inputs (except proxy).

---

## Overview & context

- **Purpose**: Run OWASP Dependency-Check scans in CI using a pre-built container image (Podman-only) and produce reports (HTML/SARIF/etc.).
- **Scope**: Composite action that runs dependency-check CLI inside a container; intended for ARC/self-hosted runners with Podman.
- **Primary users**: Platform/DevOps engineers and application teams integrating SCA into pipelines.
- **Success criteria**: Scan completes and reports are written under `out` (and optionally uploaded as artifacts/SARIF).

---

## Metadata dashboard

| Attribute | Value |
| --- | --- |
| **Owner / Lead** | @[Name] |
| **Service Status** | Alpha / Beta / Production |
| **Repository / Code** | `devtools-landingzone/actions/owasp-dependency-check` |
| **Dependencies** | Podman, GHCR image, OWASP Dependency-Check CLI |
| **Slack / Support** | #[Channel-Name] |

---

## Table of contents

- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Options reference](#options-reference)
- [Report formats](#report-formats)
- [Examples](#examples)
- [Outputs and artifacts](#outputs-and-artifacts)
- [Image and versioning](#image-and-versioning)
- [References](#references)

---

## Requirements

- **Podman** must be available on the runner. The action fails with a clear error if only Docker is present.
- Use a runner that provides Podman (e.g. self-hosted ARC runner with the owasp-dependency-check or gha-runner-scale-set-runner image).

---

## Quick start

### From this repo

```yaml
- uses: actions/checkout@v4

- name: OWASP Dependency-Check
  uses: ./devtools-landingzone/actions/owasp-dependency-check
  with:
    project: my-app
    path: .
    format: HTML
```

### From another repo

Pin to a tag and set the **image** input (default image is from this repo).

```yaml
- uses: actions/checkout@v4

- name: OWASP Dependency-Check
  uses: YOUR_ORG/IDP/devtools-landingzone/actions/owasp-dependency-check@v1.0.0
  with:
    project: my-app
    path: .
    format: HTML
    image: ghcr.io/YOUR_ORG/IDP/owasp-dependency-check:latest
```

**Required inputs:** `project`, `path`, `format`.  
**Common optional:** `out`, `image`, `failOnCVSS`, `suppression`, `exclude`, `noupdate`, `nvdApiKey`, `nvdApiDelay`.  
Full list: [Options reference](#options-reference).

---

## Options reference

Every input from `action.yml` is listed below. Paths are relative to the workspace unless noted.

### Required inputs

| Input     | Description |
|-----------|-------------|
| `project` | Project name (used in reports). |
| `path`    | Path to scan (relative to workspace). |
| `format`  | Report format: `HTML`, `XML`, `CSV`, `JSON`, `JUNIT`, `SARIF`, `JENKINS`, `GITLAB`, or `ALL`. |

### Main optional inputs

| Input   | Default              | Description |
|---------|----------------------|-------------|
| `out`   | `reports`            | Output folder for reports (relative to workspace). |
| `image` | (GHCR from this repo) | OWASP Dependency-Check image. Set when using the action from another repo. |

### Boolean options (default `false` unless noted)

| Input | Default | Description |
|-------|---------|-------------|
| `enableRetired` | `false` | Enable retired analyzers. |
| `enableExperimental` | `false` | Enable experimental analyzers. |
| `prettyPrint` | `false` | Pretty-print JSON/XML reports. |
| `noupdate` | **`true`** | Disable NVD/suppressions update (set `false` to allow update). |
| `updateonly` | `false` | Only run update phase, no scan. |
| `disableKnownExploited` | `false` | Disable Known Exploited Vulnerability analyzer. |
| `disableFileName` | `false` | Disable File Name Analyzer. |
| `disablePyDist` | `false` | Disable Python Distribution Analyzer. |
| `disablePyPkg` | `false` | Disable Python Package Analyzer. |
| `disableMSBuild` | `false` | Disable MS Build Project Analyzer. |
| `disableNodeJS` | `false` | Disable Node.js Package Analyzer. |
| `disableYarnAudit` | `false` | Disable Yarn Audit Analyzer. |
| `disablePnpmAudit` | `false` | Disable pnpm Audit Analyzer. |
| `disableNodeAudit` | `false` | Disable Node Audit Analyzer. |
| `disableNodeAuditCache` | `false` | Disable Node Audit Analyzer cache. |
| `nodeAuditSkipDevDependencies` | `false` | Node Audit: skip devDependencies. |
| `nodePackageSkipDevDependencies` | `false` | Node Package Analyzer: skip devDependencies. |
| `disableRetireJS` | `false` | Disable RetireJS Analyzer. |
| `retireJsForceUpdate` | `false` | RetireJS update regardless of noupdate. |
| `retirejsFilterNonVulnerable` | `false` | Filter out non-vulnerable JS files from report. |
| `disableRubygems` | `false` | Disable Ruby Gemspec Analyzer. |
| `disableBundleAudit` | `false` | Disable Ruby Bundler Audit Analyzer. |
| `disableCocoapodsAnalyzer` | `false` | Disable Cocoapods Analyzer. |
| `disableCarthageAnalyzer` | `false` | Disable Carthage Analyzer. |
| `disableSwiftPackageManagerAnalyzer` | `false` | Disable Swift Package Manager Analyzer. |
| `disableSwiftPackageResolvedAnalyzer` | `false` | Disable Swift Package Resolved Analyzer. |
| `disableAutoconf` | `false` | Disable Autoconf Analyzer. |
| `disableOpenSSL` | `false` | Disable OpenSSL Analyzer. |
| `disableCmake` | `false` | Disable Cmake Analyzer. |
| `disableArchive` | `false` | Disable Archive Analyzer. |
| `disableJar` | `false` | Disable Jar Analyzer. |
| `disableComposer` | `false` | Disable PHP Composer Analyzer. |
| `composerSkipDev` | `false` | Composer: skip packages-dev. |
| `disableCpan` | `false` | Disable Perl CPAN Analyzer. |
| `disableDart` | `false` | Disable Dart Analyzer. |
| `disableOssIndex` | `false` | Disable OSS Index Analyzer. |
| `disableOssIndexCache` | `false` | Disable OSS Index cache. |
| `disableCentral` | `false` | Disable Central Analyzer. |
| `disableCentralCache` | `false` | Disable Central Analyzer cache. |
| `enableNexus` | `false` | Enable Nexus Analyzer. |
| `enableArtifactory` | `false` | Enable Artifactory Analyzer. |
| `disableNuspec` | `false` | Disable .NET Nuget Nuspec Analyzer. |
| `disableNugetconf` | `false` | Disable .NET Nuget packages.config Analyzer. |
| `disableAssembly` | `false` | Disable .NET Assembly Analyzer. |
| `disableGolangDep` | `false` | Disable Go Dependency Analyzer. |
| `disableGolangMod` | `false` | Disable Go Mod Analyzer. |
| `disableMixAudit` | `false` | Disable Elixir mix audit Analyzer. |
| `disablePoetry` | `false` | Disable Poetry Analyzer. |
| `disableVersionCheck` | `false` | Disable dependency-check version check. |
| `purge` | `false` | Delete local NVD copy (force refresh). |
| `disableHostedSuppressions` | `false` | Disable hosted suppressions file. |
| `hostedSuppressionsForceUpdate` | `false` | Hosted suppressions update regardless of noupdate. |

### Value options (optional; pass only when non-empty)

| Input | Description |
|-------|-------------|
| `failOnCVSS` | Fail if CVSS ≥ this (0–10). |
| `junitFailOnCVSS` | JUNIT CVSS threshold for failure. |
| `log` | Log file path (relative to workspace). |
| `suppression` | Suppression XML path(s), comma-separated, or URL(s). |
| `exclude` | Path pattern(s) to exclude, comma-separated. |
| `symLink` | Depth to follow symbolic links (default 0). |
| `nvdApiKey` | NVD API key. |
| `nvdApiEndpoint` | NVD API endpoint URL. |
| `nvdMaxRetryCount` | NVD API max retry count. |
| `nvdApiDelay` | NVD API delay in ms. |
| `nvdApiResultsPerPage` | NVD API results per page. |
| `nvdDatafeed` | NVD data feed URL. |
| `nvdUser` | NVD basic auth user. |
| `nvdPassword` | NVD basic auth password. |
| `nvdBearerToken` | NVD bearer token. |
| `nvdValidForHours` | Hours before NVD update check. |
| `hints` | XML hints file path (relative to workspace). |
| `propertyfile` | Properties file path (relative to workspace). |
| `kevURL` | CISA Known Exploited Vulnerabilities feed URL. |
| `kevUser` | KEV basic auth user. |
| `kevPassword` | KEV basic auth password. |
| `kevBearerToken` | KEV bearer token. |
| `yarn` | Path to yarn. |
| `pnpm` | Path to pnpm. |
| `retireJsUrl` | RetireJS repository URL. |
| `retireJsUrlUser` | RetireJS basic auth user. |
| `retirejsUrlPassword` | RetireJS basic auth password. |
| `retirejsUrlBearerToken` | RetireJS bearer token. |
| `retirejsFilter` | RetireJS content filter regex (comma-separated for multiple). |
| `zipExtensions` | Comma-separated file extensions treated as ZIP. |
| `dotnet` | Path to dotnet. |
| `go` | Path to go. |
| `bundleAudit` | Path to bundle-audit. |
| `bundleAuditWorkingDirectory` | Working directory for bundle-audit. |
| `connectionString` | Database connection string. |
| `dbDriverName` | Database driver class name. |
| `dbDriverPath` | Database driver path. |
| `dbPassword` | Database password. |
| `dbUser` | Database user. |
| `data` | Data directory. |
| `hostedSuppressionsValidForHours` | Hours before hosted suppressions update. |
| `hostedSuppressionsUrl` | Hosted suppressions URL. |
| `hostedSuppressionsUser` | Hosted suppressions basic auth user. |
| `hostedSuppressionsPassword` | Hosted suppressions basic auth password. |
| `hostedSuppressionsBearerToken` | Hosted suppressions bearer token. |
| `suppressionUser` | Suppression file basic auth user. |
| `suppressionPassword` | Suppression file basic auth password. |
| `suppressionBearerToken` | Suppression file bearer token. |
| `centralUrl` | Maven Central URL. |
| `centralUsername` | Central basic auth username. |
| `centralPassword` | Central basic auth password. |
| `centralBearerToken` | Central bearer token. |
| `artifactoryUrl` | Artifactory server URL. |
| `artifactoryParallelAnalysis` | Artifactory parallel analysis (true/false). |
| `artifactoryUsername` | Artifactory username. |
| `artifactoryApiToken` | Artifactory API token. |
| `artifactoryBearerToken` | Artifactory bearer token. |
| `nexus` | Nexus server URL. |
| `nexusUser` | Nexus username. |
| `nexusPass` | Nexus password. |
| `ossIndexUsername` | OSS Index username. |
| `ossIndexPassword` | OSS Index password. |
| `ossIndexRemoteErrorWarnOnly` | OSS Index remote error warn only (true/false). |
| `ossIndexUrl` | OSS Index URL. |

See also the [Dependency-Check CLI arguments](https://dependency-check.github.io/DependencyCheck/dependency-check-cli/arguments.html).

---

## Report formats

| Format | Use |
|--------|-----|
| **HTML** | Human-readable report; good for artifacts and manual review. |
| **SARIF** | GitHub Code Scanning / Security tab; upload with `github/codeql-action/upload-sarif`. |
| **JUNIT** | Test-style integration (e.g. JUnit report aggregation). |
| **JSON / XML** | Parsing or custom tooling. |
| **ALL** | Generate all formats in the output directory. |

Reports are written to the path given by `out` (default `reports`). Use `actions/upload-artifact` to persist them.

---

## Examples

### Basic scan (HTML report)

```yaml
- uses: actions/checkout@v4
- name: Dependency-Check
  uses: ./devtools-landingzone/actions/owasp-dependency-check
  with:
    project: my-service
    path: .
    format: HTML
- uses: actions/upload-artifact@v4
  if: always()
  with:
    name: dependency-check-report
    path: reports/
```

### Fail on high/critical (CVSS ≥ 7)

```yaml
- uses: ./devtools-landingzone/actions/owasp-dependency-check
  with:
    project: my-app
    path: .
    format: HTML
    failOnCVSS: '7'
```

### With suppression file

```yaml
- uses: ./devtools-landingzone/actions/owasp-dependency-check
  with:
    project: my-app
    path: .
    format: HTML
    suppression: dependency-check-suppressions.xml
```

Multiple files or URLs: comma-separated, e.g. `suppression: suppressions.xml,https://example.com/suppressions.xml`.

### NVD API key (recommended for CI)

Reduces rate limiting when `noupdate: false`. Create an [NVD API key](https://nvd.nist.gov/developers/request-an-api-key) and store it in a repo or org secret.

```yaml
- uses: ./devtools-landingzone/actions/owasp-dependency-check
  with:
    project: my-app
    path: .
    format: HTML
    nvdApiKey: ${{ secrets.NVD_API_KEY }}
    nvdApiDelay: '3500'
    noupdate: false
```

### SARIF for GitHub Security tab

```yaml
- uses: actions/checkout@v4
- name: Dependency-Check
  id: dc
  uses: ./devtools-landingzone/actions/owasp-dependency-check
  with:
    project: my-app
    path: .
    format: SARIF
    out: sarif
- uses: github/codeql-action/upload-sarif@v3
  if: success() && always()
  with:
    sarif_file: sarif/dependency-check-report.sarif
```

Adjust `sarif_file` if your image writes a different filename.

### Scan a subdirectory

```yaml
- uses: ./devtools-landingzone/actions/owasp-dependency-check
  with:
    project: backend-api
    path: backend
    format: HTML
```

### Exclude paths

```yaml
- uses: ./devtools-landingzone/actions/owasp-dependency-check
  with:
    project: my-app
    path: .
    format: HTML
    exclude: '**/node_modules/**,**/vendor/**,**/dist/**'
```

---

## Outputs and artifacts

The action does not define outputs; it writes reports to the directory specified by `out`. To keep reports:

- Use `actions/upload-artifact` to upload the `out` directory (e.g. `reports/` or `sarif/`).
- For SARIF, use `github/codeql-action/upload-sarif` to feed the Security tab.

---

## Image and versioning

- **Default image:** `ghcr.io/<github.repository>/owasp-dependency-check:latest` when the action runs in this repo.
- **From other repos:** Set the `image` input (e.g. `ghcr.io/YOUR_ORG/IDP/owasp-dependency-check:latest`) and pin the action ref (e.g. `@v1.0.0`).
- The image is built by the **Dependency-Check UBI9 (nightly)** workflow in this repo and pushed to GHCR. Use the same image reference in `image` that your org publishes.

---

## References

- [OWASP Dependency-Check](https://owasp.org/www-project-dependency-check/)
- [Dependency-Check CLI arguments](https://dependency-check.github.io/DependencyCheck/dependency-check-cli/arguments.html)
- [NVD API key](https://nvd.nist.gov/developers/request-an-api-key)
