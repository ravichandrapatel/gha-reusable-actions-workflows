# Custom OWASP Dependency-Check image for house Podman runners (UBI9 minimal).
# Installs the official CLI release selected by DC_VERSION and pre-populates NVD data.

ARG DC_VERSION=13.0.0

FROM registry.access.redhat.com/ubi9/ubi-minimal AS fetch
ARG DC_VERSION
RUN microdnf install -y --setopt=install_weak_deps=0 curl unzip \
    && microdnf clean all
RUN curl -fsSL \
      "https://github.com/dependency-check/DependencyCheck/releases/download/v${DC_VERSION}/dependency-check-${DC_VERSION}-release.zip" \
      -o /tmp/dependency-check.zip \
    && unzip -q /tmp/dependency-check.zip -d /opt \
    && rm -f /tmp/dependency-check.zip

FROM registry.access.redhat.com/ubi9/ubi-minimal
ARG DC_VERSION
ARG NVD_REFRESH_DATE=unknown

LABEL org.opencontainers.image.title="owasp-dependency-check" \
      org.opencontainers.image.description="House OWASP Dependency-Check CLI on UBI9 minimal with pre-warmed NVD data" \
      org.opencontainers.image.source="https://github.com/dependency-check/DependencyCheck" \
      org.opencontainers.image.version="${DC_VERSION}"

RUN microdnf install -y --setopt=install_weak_deps=0 \
      bash \
      java-21-openjdk-headless \
    && microdnf clean all

COPY --from=fetch /opt/dependency-check /usr/share/dependency-check

RUN mkdir -p /usr/share/dependency-check/data \
    && chmod -R g=u /usr/share/dependency-check

ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# Pre-populate NVD from the Dependency-Check builder cache (refreshed by the daily image workflow).
RUN echo "NVD refresh stamp: ${NVD_REFRESH_DATE}" \
    && /usr/share/dependency-check/bin/dependency-check.sh \
      --data /usr/share/dependency-check/data \
      --updateonly \
      --nvdDatafeed=https://dependency-check.github.io/DependencyCheck_Builder/nvd_cache/nvdcve-{0}.json.gz

WORKDIR /src
VOLUME ["/usr/share/dependency-check/data"]

ENTRYPOINT ["/usr/share/dependency-check/bin/dependency-check.sh"]
CMD ["--help"]
