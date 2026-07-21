# Local act runner image (RHEL 9 / UBI9 class).
# Build: from act-platform/: ./build-images.sh
# Tag:   gha-act-ubi9:dev
#
# Not a full GitHub-hosted Ubuntu clone — RHEL9-class local job runtime for
# workflows that set runs-on: ubi9 (or act -P overrides).
FROM registry.access.redhat.com/ubi9/ubi:latest

LABEL org.opencontainers.image.title="gha-act-ubi9" \
      org.opencontainers.image.description="Portable local act runner (UBI9)" \
      org.opencontainers.image.source="act-platform"

# Act / Actions Toolkit prerequisites (git, Node for JS actions, basics).
RUN dnf -y update \
 && dnf -y install \
      git \
      tar \
      gzip \
      findutils \
      which \
      sudo \
      nodejs \
      npm \
      python3 \
      python3-pip \
 && dnf clean all \
 && rm -rf /var/cache/dnf

# Non-root-friendly defaults; act often runs as root inside the container.
WORKDIR /home/runner
RUN mkdir -p /home/runner \
 && chmod 755 /home/runner

# No house-specific CLIs or Release Manager config.
