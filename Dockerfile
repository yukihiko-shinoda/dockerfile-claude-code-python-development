ARG DOCKER_IMAGE_TAG_UV=debian-slim
FROM ghcr.io/astral-sh/uv:${DOCKER_IMAGE_TAG_UV} AS uv
ARG VERSION_CLAUDE_CODE=latest
WORKDIR /workspace
# - Using uv in Docker | uv
#   https://docs.astral.sh/uv/guides/integration/docker/#caching
ENV UV_LINK_MODE=copy
RUN apt-get update && apt-get install --no-install-recommends -y \
    #   For `ps` command, otherwise following error occurs when running claude-code::
    # - [BUG] Node.js error when `ps` is unavailable · Issue #2276 · anthropics/claude-code
    #   https://github.com/anthropics/claude-code/issues/2276
    procps/stable \
    #   For running Semgrep, otherwise following error occurs:
    #   Fatal error: exception Failure: ca-certs: no trust anchor file found, looked into
    #     /etc/ssl/certs/ca-certificates.crt,
    #     /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem,
    #     /etc/ssl/ca-bundle.pem.
    ca-certificates/stable \
    # To install Claude Code
    curl/stable \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
# Claude Code
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# - Troubleshoot installation and login - Claude Code Docs
#   https://code.claude.com/docs/en/troubleshoot-install#verify-your-path
# This setting should be set before running the installation script, otherwise installation may fail with the following error:
#   56.76 ⚠ Setup notes:
#   56.76   ● Native installation exists but ~/.local/bin is not in your PATH. Run:
#   56.76 
#   56.76     echo 'export PATH="$HOME/.local/bin:$PATH"' >> your shell config file && source your shell config file
#   58.77 
#   58.77 ✔ Claude Code successfully installed!
#   58.77 
#   58.77   Version: 2.1.197
#   58.77 
#   58.77   Location: ~/.local/bin/claude
#   58.77 
#   58.77 
#   58.77   Next: Run claude --help to get started
#   58.77 
#   58.77 ⚠ Setup notes:
#   58.77   ● Native installation exists but ~/.local/bin is not in your PATH. Run:
#   58.77 
#   58.77     echo 'export PATH="$HOME/.local/bin:$PATH"' >> your shell config file && source your shell config file
#   60.79 
#   60.82 
#   60.82 ✅ Installation complete!
ENV PATH="/root/.local/bin:${PATH}"
RUN curl -fsSL https://claude.ai/install.sh | bash -s "${VERSION_CLAUDE_CODE}"
ENV DISABLE_AUTOUPDATER=1
ENTRYPOINT [ "uv", "run" ]
CMD ["pytest"]
