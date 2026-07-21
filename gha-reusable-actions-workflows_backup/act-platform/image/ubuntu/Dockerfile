# Local act runner image (Ubuntu / GHA-like).
# Build: from act-platform/: ./build-images.sh
# Tag:   gha-act-ubuntu:dev
#
# Base: catthehacker Ubuntu act image (GHA tool parity for local jobs).
# Pin digest in a follow-on if your org requires immutable FROM lines.
FROM catthehacker/ubuntu:act-latest

LABEL org.opencontainers.image.title="gha-act-ubuntu" \
      org.opencontainers.image.description="Portable local act runner (Ubuntu)" \
      org.opencontainers.image.source="act-platform"

# Thin layer only — no house-specific CLIs or Release Manager config.
WORKDIR /home/runner
