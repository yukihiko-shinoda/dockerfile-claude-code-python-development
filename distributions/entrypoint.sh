#!/usr/bin/env sh
set -eu
# Sets up Python virtual environments for each project in the workspace
for pyproject in /workspace/*/pyproject.toml; do
    [ -f "$pyproject" ] || continue
    dir=$(dirname "$pyproject")
    project=$(basename "$dir")
    venv_path="$dir/.venv"
    target="/workspace/venvs/$project"

    mkdir -p "$target"

    if [ ! -L "$venv_path" ] || [ "$(readlink "$venv_path")" != "$target" ]; then
        rm -rf "$venv_path"
        ln -s "$target" "$venv_path"
    fi
done

# Authenticates with GitHub using a personal access token stored in a secret file
token_file=/run/secrets/GIT_AUTH_TOKEN
[ -s "$token_file" ] || exit 0
gh auth login --hostname github.com --with-token --insecure-storage < "$token_file"

exec "$@"
