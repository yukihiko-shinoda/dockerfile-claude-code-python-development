#!/usr/bin/env sh
# NOTE: authenticated git commands run by Claude Code inside its sandbox
# (clone/fetch/push against private repos, etc.) are currently NOT supported.
# The sandbox `credentials` mask only substitutes its sentinel in plain
# headers/bodies, not inside git's HTTP Basic auth (Base64), so the sentinel
# reaches GitHub and fails with 401; the real token stays unreadable there
# because /run/secrets is denied. Tracked upstream:
# https://github.com/anthropics/claude-code/issues/95752
# Until that is fixed, this helper only serves git commands that run outside
# the sandbox (e.g. from a terminal in the dev container).
#
# git credential helper source for github.com HTTPS operations: reads the
# GIT_AUTH_TOKEN Docker secret mounted at /run/secrets/GIT_AUTH_TOKEN (the same
# file entrypoint.sh uses for `gh auth login`), instead of relying on VS Code
# Dev Containers' own git config forwarding from the host.
#
# Registered via `git config --system credential.https://github.com.helper`
# (see Dockerfile), so git only invokes this for github.com HTTPS remotes --
# scoped that way rather than checked inside this script. Being registered at
# the system scope also means it is tried before VS Code's own helper (which
# additionally sets itself at the global scope -- observed at both
# /etc/gitconfig and /root/.gitconfig): git queries configured helpers in
# config-file order and stops once one supplies both username and password,
# so this helper wins whenever the secret is present, with no need to
# disable VS Code's own forwarding.
#
# /run/secrets is denied to Claude Code's sandbox by managed-settings.json
# (see Dockerfile), so the secret is deliberately not readable from sandboxed
# commands; only processes outside the sandbox can use this helper.
#
# Only answers the `get` operation; `store`/`erase` are no-ops so git never
# tries to persist or clear this credential elsewhere. If the secret file is
# absent or empty -- e.g. the GIT_AUTH_TOKEN secret wasn't provided when the
# container was started -- this prints nothing, so git falls through to the next
# configured helper (VS Code's) or an interactive prompt instead of failing.
set -eu
[ "${1:-}" = "get" ] || exit 0
token_file=/run/secrets/GIT_AUTH_TOKEN
[ -s "$token_file" ] || exit 0
printf 'username=x-access-token\npassword=%s\n' "$(cat "$token_file")"
