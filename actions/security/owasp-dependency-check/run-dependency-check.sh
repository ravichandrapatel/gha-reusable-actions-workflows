#!/usr/bin/env bash
# FILE_NAME: run-dependency-check.sh
# DESCRIPTION: Run OWASP Dependency-Check via Podman using env-mapped action inputs.
# VERSION: 1.0.0
# EXIT_CODES/SIGNALS: 0 success, 1 failure.
# AUTHORS: DevOps Team
set -euo pipefail

IMAGE="${IMAGE}"

if ! command -v podman &>/dev/null; then
  echo "::error::Podman is required. Use a runner with Podman (e.g. ARC runner pod). Docker is not used."
  exit 1
fi
RUNNER=podman
echo "Using $RUNNER"
$RUNNER pull --quiet "$IMAGE"

WS=/github/workspace
EXTRA=()

# Value options (paths under workspace mapped to container path)
[ -n "${failOnCVSS}" ]                 && EXTRA+=(--failOnCVSS "${failOnCVSS}")
[ -n "${junitFailOnCVSS}" ]            && EXTRA+=(--junitFailOnCVSS "${junitFailOnCVSS}")
[ -n "${log}" ]                       && EXTRA+=(--log "$WS/${log}")
[ -n "${symLink}" ]                    && EXTRA+=(--symLink "${symLink}")
[ -n "${nvdApiKey}" ]                  && EXTRA+=(--nvdApiKey "${nvdApiKey}")
[ -n "${nvdApiEndpoint}" ]             && EXTRA+=(--nvdApiEndpoint "${nvdApiEndpoint}")
[ -n "${nvdMaxRetryCount}" ]           && EXTRA+=(--nvdMaxRetryCount "${nvdMaxRetryCount}")
[ -n "${nvdApiDelay}" ]                && EXTRA+=(--nvdApiDelay "${nvdApiDelay}")
[ -n "${nvdApiResultsPerPage}" ]       && EXTRA+=(--nvdApiResultsPerPage "${nvdApiResultsPerPage}")
[ -n "${nvdDatafeed}" ]               && EXTRA+=(--nvdDatafeed "${nvdDatafeed}")
[ -n "${nvdUser}" ]                   && EXTRA+=(--nvdUser "${nvdUser}")
[ -n "${nvdPassword}" ]               && EXTRA+=(--nvdPassword "${nvdPassword}")
[ -n "${nvdBearerToken}" ]            && EXTRA+=(--nvdBearerToken "${nvdBearerToken}")
[ -n "${nvdValidForHours}" ]           && EXTRA+=(--nvdValidForHours "${nvdValidForHours}")
[ -n "${hints}" ]                      && EXTRA+=(--hints "$WS/${hints}")
[ -n "${propertyfile}" ]               && EXTRA+=(--propertyfile "$WS/${propertyfile}")
[ -n "${kevURL}" ]                     && EXTRA+=(--kevURL "${kevURL}")
[ -n "${kevUser}" ]                    && EXTRA+=(--kevUser "${kevUser}")
[ -n "${kevPassword}" ]                && EXTRA+=(--kevPassword "${kevPassword}")
[ -n "${kevBearerToken}" ]             && EXTRA+=(--kevBearerToken "${kevBearerToken}")
[ -n "${yarn}" ]                      && EXTRA+=(--yarn "${yarn}")
[ -n "${pnpm}" ]                       && EXTRA+=(--pnpm "${pnpm}")
[ -n "${retireJsUrl}" ]                && EXTRA+=(--retireJsUrl "${retireJsUrl}")
[ -n "${retireJsUrlUser}" ]            && EXTRA+=(--retireJsUrlUser "${retireJsUrlUser}")
[ -n "${retirejsUrlPassword}" ]       && EXTRA+=(--retirejsUrlPassword "${retirejsUrlPassword}")
[ -n "${retirejsUrlBearerToken}" ]     && EXTRA+=(--retirejsUrlBearerToken "${retirejsUrlBearerToken}")
[ -n "${zipExtensions}" ]             && EXTRA+=(--zipExtensions "${zipExtensions}")
[ -n "${dotnet}" ]                    && EXTRA+=(--dotnet "${dotnet}")
[ -n "${go}" ]                        && EXTRA+=(--go "${go}")
[ -n "${bundleAudit}" ]               && EXTRA+=(--bundleAudit "${bundleAudit}")
[ -n "${bundleAuditWorkingDirectory}" ] && EXTRA+=(--bundleAuditWorkingDirectory "$WS/${bundleAuditWorkingDirectory}")
[ -n "${connectionString}" ]          && EXTRA+=(--connectionString "${connectionString}")
[ -n "${dbDriverName}" ]               && EXTRA+=(--dbDriverName "${dbDriverName}")
[ -n "${dbDriverPath}" ]               && EXTRA+=(--dbDriverPath "${dbDriverPath}")
[ -n "${dbPassword}" ]                && EXTRA+=(--dbPassword "${dbPassword}")
[ -n "${dbUser}" ]                    && EXTRA+=(--dbUser "${dbUser}")
[ -n "${data}" ]                      && EXTRA+=(--data "${data}")
[ -n "${hostedSuppressionsValidForHours}" ] && EXTRA+=(--hostedSuppressionsValidForHours "${hostedSuppressionsValidForHours}")
[ -n "${hostedSuppressionsUrl}" ]     && EXTRA+=(--hostedSuppressionsUrl "${hostedSuppressionsUrl}")
[ -n "${hostedSuppressionsUser}" ]     && EXTRA+=(--hostedSuppressionsUser "${hostedSuppressionsUser}")
[ -n "${hostedSuppressionsPassword}" ] && EXTRA+=(--hostedSuppressionsPassword "${hostedSuppressionsPassword}")
[ -n "${hostedSuppressionsBearerToken}" ] && EXTRA+=(--hostedSuppressionsBearerToken "${hostedSuppressionsBearerToken}")
[ -n "${suppressionUser}" ]           && EXTRA+=(--suppressionUser "${suppressionUser}")
[ -n "${suppressionPassword}" ]       && EXTRA+=(--suppressionPassword "${suppressionPassword}")
[ -n "${suppressionBearerToken}" ]    && EXTRA+=(--suppressionBearerToken "${suppressionBearerToken}")
[ -n "${centralUrl}" ]                && EXTRA+=(--centralUrl "${centralUrl}")
[ -n "${centralUsername}" ]           && EXTRA+=(--centralUsername "${centralUsername}")
[ -n "${centralPassword}" ]           && EXTRA+=(--centralPassword "${centralPassword}")
[ -n "${centralBearerToken}" ]        && EXTRA+=(--centralBearerToken "${centralBearerToken}")
[ -n "${artifactoryUrl}" ]            && EXTRA+=(--artifactoryUrl "${artifactoryUrl}")
[ -n "${artifactoryParallelAnalysis}" ] && EXTRA+=(--artifactoryParallelAnalysis "${artifactoryParallelAnalysis}")
[ -n "${artifactoryUsername}" ]       && EXTRA+=(--artifactoryUsername "${artifactoryUsername}")
[ -n "${artifactoryApiToken}" ]       && EXTRA+=(--artifactoryApiToken "${artifactoryApiToken}")
[ -n "${artifactoryBearerToken}" ]     && EXTRA+=(--artifactoryBearerToken "${artifactoryBearerToken}")
[ -n "${nexus}" ]                     && EXTRA+=(--nexus "${nexus}")
[ -n "${nexusUser}" ]                 && EXTRA+=(--nexusUser "${nexusUser}")
[ -n "${nexusPass}" ]                 && EXTRA+=(--nexusPass "${nexusPass}")
[ -n "${ossIndexUsername}" ]          && EXTRA+=(--ossIndexUsername "${ossIndexUsername}")
[ -n "${ossIndexPassword}" ]          && EXTRA+=(--ossIndexPassword "${ossIndexPassword}")
[ -n "${ossIndexRemoteErrorWarnOnly}" ] && EXTRA+=(--ossIndexRemoteErrorWarnOnly "${ossIndexRemoteErrorWarnOnly}")
[ -n "${ossIndexUrl}" ]               && EXTRA+=(--ossIndexUrl "${ossIndexUrl}")

if [ -n "${suppression}" ]; then
  IFS=',' read -ra S <<< "${suppression}"
  for s in "${S[@]}"; do
    v=$(echo "$s" | xargs)
    if [[ "$v" =~ ^https?:// ]]; then EXTRA+=(--suppression "$v"); else EXTRA+=(--suppression "$WS/$v"); fi
  done
fi
if [ -n "${exclude}" ]; then
  IFS=',' read -ra E <<< "${exclude}"
  for e in "${E[@]}"; do EXTRA+=(--exclude "$(echo "$e" | xargs)"); done
fi
if [ -n "${retirejsFilter}" ]; then
  IFS=',' read -ra R <<< "${retirejsFilter}"
  for r in "${R[@]}"; do EXTRA+=(--retirejsFilter "$(echo "$r" | xargs)"); done
fi

# Boolean options
[ "${enableRetired}" = 'true' ]                    && EXTRA+=(--enableRetired)
[ "${enableExperimental}" = 'true' ]                && EXTRA+=(--enableExperimental)
[ "${prettyPrint}" = 'true' ]                       && EXTRA+=(--prettyPrint)
[ "${noupdate}" = 'true' ]                          && EXTRA+=(--noupdate)
[ "${updateonly}" = 'true' ]                        && EXTRA+=(--updateonly)
[ "${disableKnownExploited}" = 'true' ]             && EXTRA+=(--disableKnownExploited)
[ "${disableFileName}" = 'true' ]                   && EXTRA+=(--disableFileName)
[ "${disablePyDist}" = 'true' ]                     && EXTRA+=(--disablePyDist)
[ "${disablePyPkg}" = 'true' ]                      && EXTRA+=(--disablePyPkg)
[ "${disableMSBuild}" = 'true' ]                    && EXTRA+=(--disableMSBuild)
[ "${disableNodeJS}" = 'true' ]                     && EXTRA+=(--disableNodeJS)
[ "${disableYarnAudit}" = 'true' ]                  && EXTRA+=(--disableYarnAudit)
[ "${disablePnpmAudit}" = 'true' ]                   && EXTRA+=(--disablePnpmAudit)
[ "${disableNodeAudit}" = 'true' ]                  && EXTRA+=(--disableNodeAudit)
[ "${disableNodeAuditCache}" = 'true' ]             && EXTRA+=(--disableNodeAuditCache)
[ "${nodeAuditSkipDevDependencies}" = 'true' ]     && EXTRA+=(--nodeAuditSkipDevDependencies)
[ "${nodePackageSkipDevDependencies}" = 'true' ]   && EXTRA+=(--nodePackageSkipDevDependencies)
[ "${disableRetireJS}" = 'true' ]                   && EXTRA+=(--disableRetireJS)
[ "${retireJsForceUpdate}" = 'true' ]               && EXTRA+=(--retireJsForceUpdate)
[ "${retirejsFilterNonVulnerable}" = 'true' ]        && EXTRA+=(--retirejsFilterNonVulnerable)
[ "${disableRubygems}" = 'true' ]                   && EXTRA+=(--disableRubygems)
[ "${disableBundleAudit}" = 'true' ]                && EXTRA+=(--disableBundleAudit)
[ "${disableCocoapodsAnalyzer}" = 'true' ]          && EXTRA+=(--disableCocoapodsAnalyzer)
[ "${disableCarthageAnalyzer}" = 'true' ]            && EXTRA+=(--disableCarthageAnalyzer)
[ "${disableSwiftPackageManagerAnalyzer}" = 'true' ] && EXTRA+=(--disableSwiftPackageManagerAnalyzer)
[ "${disableSwiftPackageResolvedAnalyzer}" = 'true' ] && EXTRA+=(--disableSwiftPackageResolvedAnalyzer)
[ "${disableAutoconf}" = 'true' ]                   && EXTRA+=(--disableAutoconf)
[ "${disableOpenSSL}" = 'true' ]                    && EXTRA+=(--disableOpenSSL)
[ "${disableCmake}" = 'true' ]                      && EXTRA+=(--disableCmake)
[ "${disableArchive}" = 'true' ]                    && EXTRA+=(--disableArchive)
[ "${disableJar}" = 'true' ]                        && EXTRA+=(--disableJar)
[ "${disableComposer}" = 'true' ]                    && EXTRA+=(--disableComposer)
[ "${composerSkipDev}" = 'true' ]                   && EXTRA+=(--composerSkipDev)
[ "${disableCpan}" = 'true' ]                       && EXTRA+=(--disableCpan)
[ "${disableDart}" = 'true' ]                       && EXTRA+=(--disableDart)
[ "${disableOssIndex}" = 'true' ]                   && EXTRA+=(--disableOssIndex)
[ "${disableOssIndexCache}" = 'true' ]              && EXTRA+=(--disableOssIndexCache)
[ "${disableCentral}" = 'true' ]                    && EXTRA+=(--disableCentral)
[ "${disableCentralCache}" = 'true' ]                && EXTRA+=(--disableCentralCache)
[ "${enableNexus}" = 'true' ]                        && EXTRA+=(--enableNexus)
[ "${enableArtifactory}" = 'true' ]                  && EXTRA+=(--enableArtifactory)
[ "${disableNuspec}" = 'true' ]                     && EXTRA+=(--disableNuspec)
[ "${disableNugetconf}" = 'true' ]                  && EXTRA+=(--disableNugetconf)
[ "${disableAssembly}" = 'true' ]                   && EXTRA+=(--disableAssembly)
[ "${disableGolangDep}" = 'true' ]                  && EXTRA+=(--disableGolangDep)
[ "${disableGolangMod}" = 'true' ]                   && EXTRA+=(--disableGolangMod)
[ "${disableMixAudit}" = 'true' ]                    && EXTRA+=(--disableMixAudit)
[ "${disablePoetry}" = 'true' ]                      && EXTRA+=(--disablePoetry)
[ "${disableVersionCheck}" = 'true' ]                && EXTRA+=(--disableVersionCheck)
[ "${purge}" = 'true' ]                              && EXTRA+=(--purge)
[ "${disableHostedSuppressions}" = 'true' ]        && EXTRA+=(--disableHostedSuppressions)
[ "${hostedSuppressionsForceUpdate}" = 'true' ]     && EXTRA+=(--hostedSuppressionsForceUpdate)

# Bind-mount runner's /proc, /sys, /sys/fs/cgroup, /dev/pts so crun does not create new mounts (avoids "mount ... permission denied" OCI errors in nested rootless).
# --cgroups=disabled plus bind-mount cgroup so runtime does not mount cgroup2 at /sys/fs/cgroup.
$RUNNER run --rm \
  --cgroups=disabled \
  --security-opt unmask=/proc \
  --security-opt unmask=/proc/* \
  --security-opt unmask=/sys \
  --security-opt unmask=/dev/pts \
  -v /proc:/proc \
  -v /sys:/sys \
  -v /sys/fs/cgroup:/sys/fs/cgroup \
  -v /dev/pts:/dev/pts \
  -v /dev/ptmx:/dev/ptmx \
  -v "$GITHUB_WORKSPACE:$WS:z" \
  -w $WS \
  "$IMAGE" \
  --project "${project}" \
  --scan "$WS/${path}" \
  --format "${format}" \
  --out "$WS/${out}" \
  "${EXTRA[@]}"

# Clean up image and storage to avoid runner disk space issues (ARC/ephemeral pods).
# Run cleanup; capture exit codes and log on failure so we don't hide real errors (no blind || true).
# Step still succeeds (we don't exit 1) so the job passes even if cleanup fails.
if [ -n "$RUNNER" ] && [ -n "$IMAGE" ]; then
  echo "Removing owasp-dependency-check image and pruning storage..."
  if ! $RUNNER rmi "$IMAGE" 2>/dev/null; then
    echo "::notice::rmi $IMAGE failed (image may already be removed or in use)"
  fi
  if ! $RUNNER image prune -f 2>/dev/null; then
    echo "::notice::image prune failed"
  fi
  if ! $RUNNER container prune -f 2>/dev/null; then
    echo "::notice::container prune failed"
  fi
fi
