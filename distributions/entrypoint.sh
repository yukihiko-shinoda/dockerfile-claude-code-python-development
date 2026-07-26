#!/bin/bash
set -e

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

exec "$@"
