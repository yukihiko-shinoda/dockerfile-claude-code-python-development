#!/usr/bin/env sh
set -eu
# Sets up Python virtual environments for each project in the workspace
for pyproject in /workspace/*/pyproject.toml; do
    [ -f "$pyproject" ] || continue
    dir=$(dirname "$pyproject")
    project=$(basename "$dir")
    venv_path="$dir/.venv"
    target="/workspace/venvs/$project"
    # Use a relative link target instead of the absolute $target.
    # When a path under .venv is denied (Claude Code permissions.deny), bwrap has to create
    # a mount point for it. If .venv is an absolute symlink, bwrap can't resolve it inside
    # the new root and fails with "Can't create file at ...: No such file or directory",
    # which breaks every Bash call. A relative link resolves within the new root.
    # $dir is /workspace/<project>, so the venv is always at ../venvs/<project>.
    link_target="../venvs/$project"

    mkdir -p "$target"

    if [ ! -L "$venv_path" ] || [ "$(readlink "$venv_path")" != "$link_target" ]; then
        rm -rf "$venv_path"
        ln -s "$link_target" "$venv_path"
    fi
done

# Authenticates with GitHub using a personal access token stored in a secret file
token_file=/run/secrets/GIT_AUTH_TOKEN
[ -s "$token_file" ] || exit 0
gh auth login --hostname github.com --with-token --insecure-storage < "$token_file"

exec "$@"
