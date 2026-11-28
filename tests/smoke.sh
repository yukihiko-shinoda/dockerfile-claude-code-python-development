#!/usr/bin/env bash
# Smoke checks shared by every image variant built from the Dockerfile.
# Run from compose.test.yaml; the repository is bind-mounted, so no COPY into the image is needed.
# -x prints each command, so a CI failure log shows exactly which check failed.
set -euxo pipefail

# Claude Code and uv
claude --version
uv --version
uvx --version

# Packages Claude Code and its sandbox depend on
ps -p $$ > /dev/null
bwrap --version
socat -V > /dev/null

# Managed settings: present and readable by non-root users (ADD defaults remote files to 0600)
test "$(stat -c %a /etc/claude-code/managed-settings.json)" = 644

# Git, GitHub CLI and credential helper
git --version
gh --version
test -x /usr/local/bin/git-agent-credential-helper

# Global git secret-scanning hooks
test "$(git config --system core.hooksPath)" = /usr/local/share/git-hooks
# grep without -q: an early exit could SIGPIPE `git secrets` and fail under pipefail
git secrets --list | grep AKIA > /dev/null
gitleaks version

# Google Cloud CLI and gws
# gws-real rather than the gws wrapper, which needs a service account key secret to mint a token
gcloud --version
gws-real --version
