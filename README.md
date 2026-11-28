<!-- markdownlint-disable first-line-h1 -->
[![Test](https://github.com/yukihiko-shinoda/dockerfile-claude-code-python-development/actions/workflows/test.yml/badge.svg)](https://github.com/yukihiko-shinoda/dockerfile-claude-code-python-development/actions/workflows/test.yml)
[![Docker Image Size (latest semver)](https://img.shields.io/docker/image-size/futureys/claude-code-python-development)](https://hub.docker.com/r/futureys/claude-code-python-development/dockerfile)
[![Dependabot](https://flat.badgen.net/github/dependabot/yukihiko-shinoda/dockerfile-claude-code-python-development?icon=dependabot)](https://github.com/yukihiko-shinoda/dockerfile-claude-code-python-development/security/dependabot)

# Quick reference

- **Reference materials**:
  - [Claude Code overview - Anthropic](https://docs.anthropic.com/en/docs/claude-code/overview)

<!-- markdownlint-disable no-trailing-punctuation -->
# What is Claude Code for Python development?
<!-- markdownlint-enable no-trailing-punctuation -->

This is Claude Code for Python development.

This repository builds the following images from a single `Dockerfile`, switching only the base image:

| Image | Base image |
| --- | --- |
| [futureys/claude-code-python-development](https://hub.docker.com/r/futureys/claude-code-python-development) | [ghcr.io/astral-sh/uv](https://github.com/astral-sh/uv/pkgs/container/uv) (Debian) |
| [futureys/claude-code-playwright-python](https://hub.docker.com/r/futureys/claude-code-playwright-python) | [mcr.microsoft.com/playwright/python](https://mcr.microsoft.com/en-us/artifact/mar/playwright/python/tags) (Ubuntu) |

The Playwright image delegates installing browsers and their OS dependencies to the official Playwright image. Every other tool (Claude Code, uv, GitHub CLI, git-secrets, Betterleaks, gcloud, gws) and its version is shared by both images through `compose.yaml`.

# License

View license information for the software contained in this image.

As with all Docker images, these likely also contain other software which may be under other licenses (such as Bash, etc from the base distribution, along with any direct or indirect dependencies of the primary software being contained).

As for any pre-built image usage, it is the image user's responsibility to ensure that any use of this image complies with any relevant licenses for all software contained within.
