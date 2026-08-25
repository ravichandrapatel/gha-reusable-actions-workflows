# OWASP Dependency Check

Run **OWASP Dependency-Check** in CI using a pre-built container image. The action uses **Podman** only (no Docker) and is intended for runners that have Podman installed—for example, ARC (Actions Runner Controller) runner pods. **Proxy-related options are not exposed.**

The container image is built and pushed by this repo’s **OWASP Dependency-Check (nightly)** workflow. [Dependency-Check CLI arguments](https://dependency-check.github.io/DependencyCheck/dependency-check-cli/arguments.html) are exposed as action inputs (except proxy).

---

## Overview & context

- **Purpose**: Run OWASP Dependency-Check scans in CI using a pre-built container image (Podman-only) and produce reports (HTML/JSON/SARIF/etc.).
- **Scope**: Composite action that runs dependency-check CLI inside a container; intended for ARC/self-hosted runners with Podman.
- **Primary users**: Platform/DevOps engineers and application teams integrating SCA into pipelines (`ng-ui`, Maven, .NET).
- **Success criteria**: Scan completes and reports are written under `out` (and optionally uploaded as artifacts or imported by Sonar).

---

## Metadata dashboard

| Attribute | Value |
| --- | --- |
| **Owner / Lead** | DevOps Team |
| **Service Status** | Production |
| **Repository / Code** | `actions/security/owasp-dependency-check` |
| **Dependencies** | Podman, GHCR image, OWASP Dependency-Check CLI |
| **Profiles** | `scan-profiles.sh` — exactly three: `maven`, `ng-ui`, `dotnet` |

---

## Table of contents

- [Requirements](#requirements)
- [Quick start](#quick-start)
- [Scan profiles](#scan-profiles)
- [Performance (NVD cache)](#performance-nvd-cache)
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
- **.NET scans**: the Assembly analyzer requires **.NET 8 runtime** inside the scanner environment when scanning `*.dll` / `*.exe` (see [Assembly analyzer](https://dependency-check.github.io/DependencyCheck/analyzers/assembly-analyzer.html)).

---

## Quick start

### Recommended — use a scan profile

```yaml
- uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1

- name: Restore OWASP NVD cache
  uses: actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0
  with:
    path: .owasp-data
    key: owasp-${{ hashFiles('package-lock.json', 'pom.xml', '**/*.csproj') }}
    restore-keys: owasp-

- name: OWASP Dependency-Check
  uses: ./actions/security/owasp-dependency-check
  with:
    scan_profile: ng-ui
    project: my-app
    path: .
    data_dir: ${{ github.workspace }}/.owasp-data
    nvdApiKey: ${{ secrets.NVD_API_KEY }}
```

**Required inputs:** `project`, `path`.  
**Recommended:** `scan_profile` (sets analyzers, excludes, and `JSON,HTML` format).  
**Common optional:** `out`, `data_dir`, `exclude`, `suppression`, `nvdApiKey`, `failOnCVSS`.

### From another repo

Pin the action ref and set the **image** input when the default GHCR image is not from your org.

```yaml
- uses: YOUR_ORG/gha-reusable-actions-workflows/actions/security/owasp-dependency-check@<sha>
  with:
    scan_profile: maven
    project: my-service
    path: .
    image: ghcr.io/YOUR_ORG/gha-reusable-actions-workflows/owasp-dependency-check:latest
```

---

## Scan profiles

Set `scan_profile` to apply stack-specific analyzer defaults from `scan-profiles.sh`. Profiles follow [official OWASP analyzer guidance](https://dependency-check.github.io/DependencyCheck/analyzers/index.html): enable only what each stack needs, disable RetireJS for npm/Angular (not recommended for Node projects), and disable Central for Maven (matches Maven plugin default).

The chosen profile owns the `disable*` analyzer matrix. You can still override **`exclude`**, **`format`**, **`suppression`**, and other non-analyzer inputs.

| Profile | Analyzers enabled | Typical use |
| --- | --- | --- |
| **`maven`** | Jar, Node Package, Node Audit | Maven apps (UI + services) |
| **`ng-ui`** | Node Package, Node Audit | Pure Angular/npm |
| **`dotnet`** | MSBuild, Assembly, Nuspec, Nugetconf | SDK-style `.csproj` / .NET |

Legacy aliases `maven-ui`, `maven-svc`, and `jsb`/`jcr`/`jsts` `-ui`/`-svc` still normalize to **`maven`**.

### Default excludes (per profile)

| Profile | Excludes |
| --- | --- |
| `ng-ui` | `node_modules/**`, `dist/**`, `coverage/**`, `.angular/**`, `e2e/**`, … |
| `maven` | `target/**`, `node_modules/**`, `dist/**`, `coverage/**`, `.git/**`, `.owasp-data/**`, … |
| `dotnet` | `bin/**`, `obj/**`, `node_modules/**`, `.owasp-data/**` |

### Analyzers disabled by all profiles

RetireJS, hosted suppressions, KEV feed, version check, and non-target experimental analyzers (Python, Go, Ruby, PHP, …) are disabled for CI speed. RetireJS scans every `*.js` file and is [not recommended for Node/Angular projects](https://github.com/dependency-check/DependencyCheck/issues/2842).

### Maven note

For JVM projects, OWASP recommends the [Maven plugin](https://dependency-check.github.io/DependencyCheck/dependency-check-maven/) (`dependency-check-maven:check`) when possible—it uses Maven’s resolved dependency tree. This action’s CLI + Podman path is for unified pipelines; **`maven`** scans best after `mvn package` when `target/*.jar` exists.

---

## Performance (NVD cache)

Cold NVD data is the main CI time sink. Recommended pattern:

1. **`actions/cache`** on a workspace directory (e.g. `.owasp-data`).
2. **`data_dir`** — mount that directory into the container at `/usr/share/dependency-check/data`.
3. **`noupdate: true`** (default via profiles) — skip NVD download when cache is warm.
4. **`nvdApiKey`** — speeds NVD API when cache is cold ([NVD API key](https://nvd.nist.gov/developers/request-an-api-key)).
5. **Skip image re-pull** — the action reuses a local Podman image when present; **`cleanup_image`** defaults to `false`.

```yaml
- uses: actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0
  with:
    path: .owasp-data
    key: owasp-${{ hashFiles('package-lock.json') }}
    restore-keys: owasp-

- uses: ./actions/security/owasp-dependency-check
  with:
    scan_profile: ng-ui
    project: ${{ github.event.repository.name }}
    path: .
    data_dir: ${{ github.workspace }}/.owasp-data
    nvdApiKey: ${{ secrets.NVD_API_KEY }}
```

---

## Options reference

Every input from `action.yml` is listed below. Paths are relative to the workspace unless noted.

### Required inputs

| Input | Description |
| --- | --- |
| `project` | Project name (used in reports). |
| `path` | Path to scan (relative to workspace). |

### Main optional inputs

| Input | Default | Description |
| --- | --- | --- |
| `scan_profile` | (required) | Stack preset — **`maven`** \| **`ng-ui`** \| **`dotnet`**. |
| `format` | `JSON,HTML` | Comma-separated report types. Profile default applies when `scan_profile` is set. |
| `out` | `reports` | Output folder for reports (relative to workspace). |
| `data_dir` | `""` | Host path for NVD/data cache; mounted at `/usr/share/dependency-check/data`. |
| `cleanup_image` | `false` | Remove the container image after scan (slower on next run). |
| `image` | (GHCR from this repo) | OWASP Dependency-Check image. Set when using the action from another repo. |

### Boolean options (default `false` unless noted)

Profile presets set the analyzer `disable*` matrix. Override individual analyzer inputs only when you need to deviate from the profile.

| Input | Default | Description |
| --- | --- | --- |
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
| --- | --- |
| `failOnCVSS` | Fail if CVSS ≥ this (0–10). |
| `junitFailOnCVSS` | JUNIT CVSS threshold for failure. |
| `log` | Log file path (relative to workspace). |
| `suppression` | Suppression XML path(s), comma-separated, or URL(s). |
| `exclude` | Path pattern(s) to exclude, comma-separated. Merged with profile defaults when using `scan_profile`. |
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
| `dotnet` | Path to dotnet executable (required for Assembly analyzer if not on PATH). |
| `go` | Path to go. |
| `bundleAudit` | Path to bundle-audit. |
| `bundleAuditWorkingDirectory` | Working directory for bundle-audit. |
| `connectionString` | Database connection string. |
| `dbDriverName` | Database driver class name. |
| `dbDriverPath` | Database driver path. |
| `dbPassword` | Database password. |
| `dbUser` | Database user. |
| `data` | Data directory (alternative to `data_dir` mount; passed as CLI `--data`). |
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
| --- | --- |
| **JSON** | Sonar import (`dependency-check-report.json`); custom tooling. |
| **HTML** | Human-readable report; Sonar import; manual review. |
| **SARIF** | GitHub Code Scanning / Security tab. |
| **JUNIT** | Test-style integration. |
| **XML / CSV** | Legacy tooling. |
| **ALL** | All formats (slow; avoid in CI when profiles already set `JSON,HTML`). |

Profiles default to **`JSON,HTML`** — the combination expected by house `sonar-scan` for ng-ui. Reports are written to `out` (default `reports`). Use `actions/upload-artifact` to persist them.

---

## Examples

### ng-ui pipeline (house pattern)

```yaml
- uses: actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0
  with:
    path: .owasp-data
    key: ng-ui-owasp-${{ hashFiles('package-lock.json') }}
    restore-keys: ng-ui-owasp-

- uses: ./actions/security/owasp-dependency-check
  with:
    scan_profile: ng-ui
    project: ${{ needs.build-preprocess.outputs.application_name }}
    path: .
    data_dir: ${{ github.workspace }}/.owasp-data
    nvdApiKey: ${{ secrets.NVD_API_KEY }}

- uses: actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1
  with:
    name: owasp-report
    path: reports
    if-no-files-found: error
```

### Maven (`jsb`/`jcr`/`jsts` UI or SVC)

```yaml
- uses: ./actions/security/owasp-dependency-check
  with:
    scan_profile: maven
    project: snapshipadmin-jsb-ui
    path: .
    data_dir: ${{ github.workspace }}/.owasp-data
    nvdApiKey: ${{ secrets.NVD_API_KEY }}
```

Aliases `maven-ui`, `maven-svc`, `jsb-ui`, `jsb-svc`, … all normalize to **`maven`**.

### .NET

```yaml
- uses: ./actions/security/owasp-dependency-check
  with:
    scan_profile: dotnet
    project: ams2-dnc-svc
    path: .
    data_dir: ${{ github.workspace }}/.owasp-data
    nvdApiKey: ${{ secrets.NVD_API_KEY }}
```

### Fail on high/critical (CVSS ≥ 7)

```yaml
- uses: ./actions/security/owasp-dependency-check
  with:
    scan_profile: ng-ui
    project: my-app
    path: .
    failOnCVSS: '7'
```

### With suppression file

```yaml
- uses: ./actions/security/owasp-dependency-check
  with:
    scan_profile: maven
    project: my-app
    path: .
    suppression: dependency-check-suppressions.xml
```

### SARIF for GitHub Security tab

```yaml
- uses: ./actions/security/owasp-dependency-check
  with:
    scan_profile: ng-ui
    project: my-app
    path: .
    format: SARIF
    out: sarif
- uses: github/codeql-action/upload-sarif@v3
  with:
    sarif_file: sarif/dependency-check-report.sarif
```

---

## Outputs and artifacts

The action does not define GitHub outputs; it writes reports to the directory specified by `out`.

| Report file | Typical consumer |
| --- | --- |
| `reports/dependency-check-report.html` | Sonar (`sonar.dependencyCheck.htmlReportPath`) |
| `reports/dependency-check-report.json` | Sonar (`sonar.dependencyCheck.jsonReportPath`) |

Upload with `actions/upload-artifact` or import via house `actions/security/sonar-scan`.

---

## Image and versioning

- **Default image:** `ghcr.io/<github.repository>/owasp-dependency-check:latest` when the action runs in this repo.
- **From other repos:** Set the `image` input and pin the action ref to a commit SHA.
- **Build workflow:** `.github/workflows/owasp-dependency-check-image.yml` runs **daily** (05:00 UTC). Each build runs `dependency-check --updateonly` against the [Dependency-Check builder NVD cache](https://dependency-check.github.io/DependencyCheck_Builder/nvd_cache/) (`nvdcve-{0}.json.gz`), then publishes `:latest` and `:X.Y.Z` to GHCR.
- **NVD cache sync workflow:** `.github/workflows/owasp-nvd-cache-sync.yml` runs **daily** (04:00 UTC). Downloads NVD data via **`NVD_API_KEY`** (NVD API), publishes `owasp-nvd-cache-*.tar.gz` to **GitHub Actions artifacts** (90-day retention), and optionally uploads to **Nexus raw** when `vars.NEXUS_NVD_CACHE_URL` is set (uses `NEXUS_USERNAME` / `NEXUS_PASSWORD`).
- **Base image:** `registry.access.redhat.com/ubi9/ubi-minimal` with the official Dependency-Check CLI release zip.
- **Pinned upstream version:** `container/dc-version.env` (`DC_VERSION=…`) selects the CLI version; a PR opens only when upstream `current.txt` advances.
- **Empty `data_dir`:** When the host cache directory is empty, the action seeds it from the image’s baked NVD data before the scan.
- **`cleanup_image`:** leave `false` (default) so Podman reuses the image on warm runners.

---

## References

- [OWASP Dependency-Check](https://owasp.org/www-project-dependency-check/)
- [File type analyzers](https://dependency-check.github.io/DependencyCheck/analyzers/index.html)
- [Node.js analyzer](https://dependency-check.github.io/DependencyCheck/analyzers/nodejs.html)
- [Jar analyzer](https://dependency-check.github.io/DependencyCheck/analyzers/jar-analyzer.html)
- [MSBuild analyzer](https://dependency-check.github.io/DependencyCheck/analyzers/msbuild.html)
- [Assembly analyzer](https://dependency-check.github.io/DependencyCheck/analyzers/assembly-analyzer.html)
- [Central analyzer](https://dependency-check.github.io/DependencyCheck/analyzers/central-analyzer.html)
- [Dependency-Check CLI arguments](https://dependency-check.github.io/DependencyCheck/dependency-check-cli/arguments.html)
- [Maven plugin configuration](https://dependency-check.github.io/DependencyCheck/dependency-check-maven/configuration.html)
- [NVD API key](https://nvd.nist.gov/developers/request-an-api-key)
