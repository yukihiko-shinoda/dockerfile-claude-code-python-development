ARG DOCKER_IMAGE_TAG_UV=debian-slim
FROM ghcr.io/astral-sh/uv:${DOCKER_IMAGE_TAG_UV} AS uv
ARG VERSION_CLAUDE_CODE
# Reason: This is not secret but tool name includes the word:`secrets`
# hadolint ignore=DL3064
ARG VERSION_GIT_SECRETS
ARG VERSION_HOL_GUARD
ARG VERSION_GITLEAKS
ARG GCLOUD_VERSION
ARG GWS_VERSION
ARG BUILDARCH
WORKDIR /workspace
# - Using uv in Docker | uv
#   https://docs.astral.sh/uv/guides/integration/docker/#caching
ENV UV_LINK_MODE=copy
RUN apt-get update && apt-get install --no-install-recommends -y \
    #   For running Semgrep, otherwise following error occurs:
    #   Fatal error: exception Failure: ca-certs: no trust anchor file found, looked into
    #     /etc/ssl/certs/ca-certificates.crt,
    #     /etc/pki/ca-trust/extracted/pem/tls-ca-bundle.pem,
    #     /etc/ssl/ca-bundle.pem.
    ca-certificates/stable \
    # To install Claude Code
    curl/stable \
    # To enable Claude Code sandbox
    # - Configure the sandboxed Bash tool - Claude Code Docs
    #   https://code.claude.com/docs/en/sandboxing#set-up-linux-and-wsl2
    bubblewrap/stable \
    socat/stable \
    # To interact with GitHub repositories
    git/stable \
    # To install git-secrets
    make/stable \
    #   For `ps` command, otherwise following error occurs when running claude-code::
    # - [BUG] Node.js error when `ps` is unavailable · Issue #2276 · anthropics/claude-code
    #   https://github.com/anthropics/claude-code/issues/2276
    procps/stable \
    # To install GitHub CLI, git-secrets and Gitleaks
    wget/stable \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
# Force the Claude Code sandbox on for every session in this container:
# managed settings take precedence over user/project settings and cannot be
# overridden from inside a session.
# - Enterprise sandbox settings and managed policy settings - Claude Code Docs
#   https://code.claude.com/docs/en/sandboxing#enterprise-sandbox-settings
#   https://code.claude.com/docs/en/settings#managed-settings
# Source: https://github.com/yukihiko-shinoda/claude-code-settings-file/blob/main/managed-settings.json
# Pinned to a commit SHA so the policy cannot change under us; bump manually.
# ADD creates /etc/claude-code automatically; remote files default to mode 0600, so set 0644 explicitly.
ADD --chmod=0644 https://raw.githubusercontent.com/yukihiko-shinoda/claude-code-settings-file/05970207b46204d4c67988a8ec14fb77a9e5fb24/managed-settings.json /etc/claude-code/managed-settings.json
# git credential source for github.com HTTPS operations: reads the
# GIT_AUTH_TOKEN Docker secret, mounted at /run/secrets/GIT_AUTH_TOKEN,
# instead of relying solely on VS Code Dev Containers' own git config
# forwarding from the host -- see git-agent-credential-helper.sh for why
# this coexists with, rather than replaces, that forwarding.
# NOTE: only usable outside Claude Code's sandbox; authenticated git commands
# run by Claude Code itself are not supported yet:
# https://github.com/anthropics/claude-code/issues/95752
COPY ./distributions/git-agent-credential-helper.sh /usr/local/bin/git-agent-credential-helper
RUN chmod +x /usr/local/bin/git-agent-credential-helper \
 && git config --system credential.https://github.com.helper /usr/local/bin/git-agent-credential-helper
# HOL Guard: runtime protection for AI agents, watching this container's claude-code
# harness for secret exposure, prompt injection, unsafe commands, and malicious packages.
# PyPI: https://pypi.org/project/hol-guard/
# NOTE: version bump is manual, same as csklint above -- not tracked by Dependabot
RUN uv tool install "hol-guard==${VERSION_HOL_GUARD}" \
 && hol-guard install claude-code \
 && hol-guard settings set protection watch
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
# GitHub CLI
# - cli/docs/install\_linux.md at trunk · cli/cli
#   https://github.com/cli/cli/blob/trunk/docs/install_linux.md#debian
RUN mkdir -p /etc/apt/keyrings \
 && chmod -R 0755 /etc/apt/keyrings \
 && out=$(mktemp) && wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
 && tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null < "$out" \
 && chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
 && mkdir -p /etc/apt/sources.list.d \
 && chmod -R 0755 /etc/apt/sources.list.d \
 && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
 && apt-get update && apt-get install --no-install-recommends -y \
    gh/stable \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
# git-secrets
# - awslabs/git-secrets: Prevents you from committing passwords and other sensitive information to a git repository.
#   https://github.com/awslabs/git-secrets
# GitHub publishes no checksum/signature for tag source tarballs; provenance relies on HTTPS plus the pinned tag.
RUN version="${VERSION_GIT_SECRETS}" \
 && workdir=$(mktemp -d) \
 && wget -nv -O"$workdir/git-secrets.tar.gz" "https://github.com/awslabs/git-secrets/archive/refs/tags/${version}.tar.gz" \
 && tar -xzf "$workdir/git-secrets.tar.gz" -C "$workdir" \
      "git-secrets-${version}/Makefile" "git-secrets-${version}/git-secrets" "git-secrets-${version}/git-secrets.1" \
 && make -C "$workdir/git-secrets-${version}" install \
 && rm -rf "$workdir"
# Gitleaks
# - gitleaks/gitleaks: Find secrets with Gitleaks
#   https://github.com/gitleaks/gitleaks
RUN version="${VERSION_GITLEAKS}" \
 && case "$(dpkg --print-architecture)" in \
      amd64) arch=x64 ;; \
      arm64) arch=arm64 ;; \
      *) echo "Unsupported architecture for gitleaks: $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac \
 && tarball="gitleaks_${version}_linux_${arch}.tar.gz" \
 && workdir=$(mktemp -d) \
 && wget -nv -O"$workdir/$tarball" "https://github.com/gitleaks/gitleaks/releases/download/v${version}/${tarball}" \
 && wget -nv -O"$workdir/checksums.txt" "https://github.com/gitleaks/gitleaks/releases/download/v${version}/gitleaks_${version}_checksums.txt" \
 && expected=$(awk -v f="$tarball" '$2 == f {print $1}' "$workdir/checksums.txt") \
 && actual=$(sha256sum "$workdir/$tarball" | awk '{print $1}') \
 && if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then \
      echo "gitleaks checksum verification failed: expected '$expected', actual '$actual'" >&2; exit 1; \
    fi \
 && tar -xzf "$workdir/$tarball" -C "$workdir" gitleaks \
 && install -m 0755 "$workdir/gitleaks" /usr/local/bin/gitleaks \
 && rm -rf "$workdir"
COPY --chmod=0755 distributions/git-hooks/ /usr/local/share/git-hooks/
# Global git secret-scanning hooks (git-secrets + gitleaks).
# core.hooksPath and the git-secrets AWS pattern registration go to the --system scope
# (/etc/gitconfig, plus an included side file for the AWS patterns, since git-secrets'
# --register-aws only supports writing --global) rather than --global (/root/.gitconfig):
# VS Code Dev Containers only copies the host's ~/.gitconfig into the container when the
# container doesn't already have one, so writing to /root/.gitconfig here would pre-empt that
# copy and silently drop the host's user.name/user.email. git-secrets reads patterns via merged
# config (no scope flag), so system-scoped patterns are still picked up during scans. This is
# static, deterministic config with no runtime dependency, so it's baked into the image here
# rather than reapplied by entrypoint.sh on every container start -- /etc/gitconfig isn't a
# volume and isn't touched by anything between starts, so a build-time write is sufficient.
# core.hooksPath makes Git ignore each repo's own .git/hooks/, so every global hook chains to
# a same-named repo-local hook via _local-hook-exec.
RUN git config --system core.hooksPath /usr/local/share/git-hooks \
 && git config --system include.path /etc/git-secrets-aws.gitconfig \
 && GIT_CONFIG_GLOBAL=/etc/git-secrets-aws.gitconfig git secrets --register-aws --global
COPY --chmod=0755 distributions/entrypoint.sh /usr/local/bin/entrypoint
ENTRYPOINT [ "entrypoint" ]
CMD ["claude"]
# Google Cloud CLI (gcloud)
# - Install gcloud CLI | Google Cloud SDK Documentation
#   https://docs.cloud.google.com/sdk/docs/install#deb
RUN apt-get upgrade \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
        apt-transport-https/stable \
        ca-certificates/stable \
        gnupg/stable \
 && apt-get -y autoremove \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg \
 && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends google-cloud-cli=${GCLOUD_VERSION}-0 \
 && apt-get -y autoremove \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*
# gws (Google Workspace CLI): single Rust binary from GitHub Releases, no Node.js
# runtime needed.
# - Releases · googleworkspace/cli
#   https://github.com/googleworkspace/cli/releases
RUN case "${BUILDARCH}" in \
        amd64) GWS_TARGET=x86_64-unknown-linux-gnu ;; \
        arm64) GWS_TARGET=aarch64-unknown-linux-gnu ;; \
        *) echo "Unsupported BUILDARCH for gws: ${BUILDARCH}" >&2; exit 1 ;; \
    esac \
 && curl -O -L "https://github.com/googleworkspace/cli/releases/download/v${GWS_VERSION}/google-workspace-cli-${GWS_TARGET}.tar.gz" \
 && curl -O -L "https://github.com/googleworkspace/cli/releases/download/v${GWS_VERSION}/google-workspace-cli-${GWS_TARGET}.tar.gz.sha256" \
 && sha256sum -c "google-workspace-cli-${GWS_TARGET}.tar.gz.sha256" \
 && tar -xzf "google-workspace-cli-${GWS_TARGET}.tar.gz" -C /usr/local/bin ./gws \
 && mv /usr/local/bin/gws /usr/local/bin/gws-real \
 && chmod +x /usr/local/bin/gws-real \
 && rm -f "google-workspace-cli-${GWS_TARGET}.tar.gz" "google-workspace-cli-${GWS_TARGET}.tar.gz.sha256"
# GCP credential source for gws: activates the claude-code service account's
# static JSON key (Docker secret, minted by gcp-agent-key.sh, mounted at
# /opt/claude-agent-secrets/claude-code-key.json -- see compose.yml) with
# gcloud, mints a short-lived GCP OAuth token scoped to Drive/Docs from it,
# then execs into the real gws binary (renamed to gws-real above) with that
# token. Installed AT /usr/local/bin/gws itself (shadowing the real binary),
# not under a separate name like gws-agent, so Claude Code calls the bare
# `gws <service> <resource> <method> --params/--json ...` interface exactly
# as documented by `gws --help`/`gws schema`, with credential injection
# invisible to it. See terraform-google-personal's service_accounts.tf for
# the claude-code service account, and CLAUDE.md for the full chain. gcloud
# stays installed above for this token-minting step even though this wrapper
# no longer uses it for WIF impersonation (see the wrapper's own comments).
# A WIF credential-config JSON for the same fallback path may exist locally
# at ./google-wif-cred-config.json on a given host, but it's gitignored, not
# committed (it names this GCP project's number and the claude-code service
# account's email, which the account owner doesn't want in version control,
# even though the file holds no credential itself) -- regenerate it with
# `gcloud iam workload-identity-pools create-cred-config` (see
# terraform-google-personal/service_accounts.tf's comment above the
# claude_code WIF IAM policy binding) if that fallback path is ever revived.
COPY distributions/gws-agent.sh /usr/local/bin/gws
RUN chmod +x /usr/local/bin/gws
