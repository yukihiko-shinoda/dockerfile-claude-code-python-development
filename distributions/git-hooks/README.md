# Global Git Hooks

These scripts become every repository's git hooks inside the container. The
[Dockerfile](../../Dockerfile) copies this directory to `/usr/local/share/git-hooks/`
(`COPY --chmod=0755 distribution/git-hooks/ /usr/local/share/git-hooks/`) and points
`core.hooksPath` at it, so Git uses these instead of any repo's own `.git/hooks/`. See the
"Global Git Secret-Scanning Hooks" section of the root [CLAUDE.md](../../CLAUDE.md) for the
full rationale (system vs. global config scope, why this lives in the Dockerfile).

## Files

- **`pre-commit`** — runs `git secrets --pre_commit_hook` and a `gitleaks` scan of staged
  changes, then chains to a repo-local hook (see `_local-hook-exec` below).
- **`commit-msg`** — runs `git secrets --commit_msg_hook` on the commit message, then chains
  to a repo-local hook.
- **`prepare-commit-msg`** — runs `git secrets --prepare_commit_msg_hook`, then chains to a
  repo-local hook.
- **`_local-hook-exec`** — shared helper, not a hook itself (the leading `_` keeps it out of
  Git's hook-name matching so it's never invoked directly by Git). Sourced at the end of each
  hook above. Resolves the current repository's root — preferring the superproject's working
  tree when the working directory is a submodule's toplevel — and, if that root has a
  `.git/hooks/<hook-name>` file, sources it. This is what lets an individual project still
  supply its own hook logic even though `core.hooksPath` overrides Git's default
  `.git/hooks/` lookup globally.

## Adding a new hook type

1. Add `distribution/git-hooks/<hook-name>`, following the existing pattern: run the
   corresponding `git secrets --<hook-name>_hook -- "$@"` (if git-secrets supports that hook),
   then `source "$(dirname "$0")/_local-hook-exec"`.
2. Rebuild the image. No `entrypoint.sh` or `Dockerfile` change is needed — the `COPY` and
   `git config --system core.hooksPath` steps already apply to the whole directory.
