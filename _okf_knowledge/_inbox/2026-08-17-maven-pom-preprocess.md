# Change close-out write-back: maven-pom-preprocess

**Evidence grade:** verified
**Suggested destination:** MAINTAIN later

## What shipped / learned
- `preprocess.py` for `app_build_type=maven` reads caller-root `pom.xml` (Maven default namespace stripped via local tag).
- Version element = parent `<version>` if parent exists, else project `<version>`; `APPLICATION_VERSION` is that text stripped.
- `ARTIFACT_ID` from project `artifactId`; `NAME` from pom `<name>`; `APPLICATION_NAME` still from `project.values` (stripped).
- Missing `pom.xml`, version, or `artifactId` fails the step. ng-ui/dotnet leave the maven-only keys empty.
- `JAVA_VERSION` from `properties/java.version` (sample: `21`). Missing that property fails maven the same way missing `engines.node` fails ng-ui.
- `CPGBUILD_APP_ORIGIN` from `build.values`. Empty origin forces `CHECKS_TYPE_SKIP=false`; non-empty sets it `true`.
- `isLibrary` is maven-only (`n`/`y` from TEMPLATE). ng-ui/dotnet leave it empty.
- Maven `APPLICATION_VERSION`: `parent/version` text if that element exists, else project `<version>` (`version_snapshot`).
- Sonar CLI: if the built flag is not exactly `-Dsonar.inclusions=` / `-Dsonar.exclusions=`, emit `-Dsonar.inclusions=<list>` / `-Dsonar.exclusions=<list>`; otherwise leave those outputs empty. `SONAR_CLI_ARGS` joins only the non-empty flags.
