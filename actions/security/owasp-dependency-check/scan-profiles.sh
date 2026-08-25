#!/usr/bin/env bash
# FILE_NAME: scan-profiles.sh
# DESCRIPTION: OWASP Dependency-Check scan presets aligned with app stacks.
# VERSION: 1.4.0
# AUTHORS: DevOps Team

# Canonical profiles (exactly three): maven | ng-ui | dotnet
# Legacy maven-ui / maven-svc / jsb|jcr|jsts -ui|-svc still normalize to maven.
normalize_scan_profile() {
  case "${1:-}" in
    jsb-ui|jcr-ui|jsts-ui|jsb-svc|jcr-svc|jsts-svc|maven-ui|maven-svc|maven)
      echo "maven"
      ;;
    ng-ui)
      echo "ng-ui"
      ;;
    dotnet)
      echo "dotnet"
      ;;
    *)
      echo "${1:-}"
      ;;
  esac
}

# Shared speed/safety flags and non-target experimental analyzers.
# Stack-specific analyzers (Jar, Node, MSBuild, Assembly, …) are set per profile.
_apply_common_fast_flags() {
  noupdate="${noupdate:-true}"
  disableVersionCheck=true
  disableHostedSuppressions=true
  disableKnownExploited=true
  disableRetireJS=true
  disablePyDist=true
  disablePyPkg=true
  disableGolangDep=true
  disableGolangMod=true
  disableRubygems=true
  disableBundleAudit=true
  disableComposer=true
  disableCpan=true
  disableDart=true
  disablePoetry=true
  disableMixAudit=true
  disableAutoconf=true
  disableCmake=true
  disableOpenSSL=true
  disableCocoapodsAnalyzer=true
  disableCarthageAnalyzer=true
  disableSwiftPackageManagerAnalyzer=true
  disableSwiftPackageResolvedAnalyzer=true
}

_disable_non_jvm_stacks() {
  disableMSBuild=true
  disableAssembly=true
  disableNuspec=true
  disableNugetconf=true
}

_disable_non_node_stacks() {
  disableNodeJS=true
  disableNodeAudit=true
  disableYarnAudit=true
  disablePnpmAudit=true
}

_disable_non_maven_stacks() {
  disableJar=true
  disableCentral=true
}

# Apply analyzer/exclude/format defaults for scan_profile.
# The profile owns disable* flags; callers override exclude, format, suppression,
# and other non-analyzer inputs only.
apply_scan_profile() {
  local profile
  profile="$(normalize_scan_profile "${1:-}")"

  case "${profile}" in
    ng-ui)
      format="${format:-JSON,HTML}"
      exclude="${exclude:-node_modules/**,dist/**,coverage/**,.git/**,.owasp-data/**,**/*.map,.angular/**,e2e/**,**/.cache/**}"
      _apply_common_fast_flags
      _disable_non_jvm_stacks
      _disable_non_maven_stacks
      disableFileName=true
      disableArchive=true
      nodePackageSkipDevDependencies=true
      echo "Using scan_profile=ng-ui (Node Package + Node Audit)"
      ;;
    maven)
      format="${format:-JSON,HTML}"
      exclude="${exclude:-target/**,node_modules/**,dist/**,coverage/**,.git/**,.owasp-data/**,**/*.map,.angular/**,e2e/**,**/.cache/**}"
      _apply_common_fast_flags
      _disable_non_jvm_stacks
      disableCentral=true
      disableFileName=true
      disableArchive=true
      disableYarnAudit=true
      disablePnpmAudit=true
      nodePackageSkipDevDependencies=true
      echo "Using scan_profile=maven (Jar + Node Package + Node Audit)"
      ;;
    dotnet)
      format="${format:-JSON,HTML}"
      exclude="${exclude:-bin/**,obj/**,.git/**,.owasp-data/**,**/node_modules/**}"
      _apply_common_fast_flags
      _disable_non_node_stacks
      _disable_non_maven_stacks
      disableArchive=true
      echo "Using scan_profile=dotnet (MSBuild + Assembly + NuGet; Nuspec/Nugetconf when present)"
      ;;
    *)
      echo "::error::scan_profile must be one of: maven, ng-ui, dotnet (got '${1:-}')" >&2
      return 1
      ;;
  esac
}
