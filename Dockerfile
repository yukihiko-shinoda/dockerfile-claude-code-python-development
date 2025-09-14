ARG DOCKER_IMAGE_TAG_NODE=latest \
    VERSION_UV=latest
FROM ghcr.io/astral-sh/uv:${VERSION_UV} AS uv
FROM node:${DOCKER_IMAGE_TAG_NODE}
ARG VERSION_CLAUDE_CODE=latest
WORKDIR /workspace
# - Using uv in Docker | uv
#   https://docs.astral.sh/uv/guides/integration/docker/#installing-uv
COPY --from=uv /uv /uvx /bin/
# - Using uv in Docker | uv
#   https://docs.astral.sh/uv/guides/integration/docker/#caching
ENV UV_LINK_MODE=copy
# procps:
#   For `ps` command, otherwise following error occurs when running claude-code::
# - [BUG] Node.js error when `ps` is unavailable · Issue #2276 · anthropics/claude-code
#   https://github.com/anthropics/claude-code/issues/2276
# ca-certificates:
#   For running Semgrep, otherwise following error occurs:
#   Fatal error: exception Failure: ca-certs: no trust anchor file found, looked into
#     /etc/ssl/certs/ca-certificates.crt,
#     /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem,
#     /etc/ssl/ca-bundle.pem.
RUN apt-get update && apt-get install --no-install-recommends -y \
    procps/stable \
    ca-certificates/stable \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
RUN npm install -g @anthropic-ai/claude-code@${VERSION_CLAUDE_CODE}
ENV DISABLE_AUTOUPDATER=1
# The uv command also errors out when installing semgrep:
# - Getting semgrep-core in pipenv · Issue #2929 · semgrep/semgrep
#   https://github.com/semgrep/semgrep/issues/2929#issuecomment-818994969
ENV SEMGREP_SKIP_BIN=true
ENTRYPOINT [ "uv", "run" ]
CMD ["pytest"]
