# CLAUDE.md

Budavári Schönherz Stúdió's Mattermost image: Team Edition with the OIDC login patch from the `external/mattermost-oidc` submodule ([BSStudio/mattermost-oidc](https://github.com/BSStudio/mattermost-oidc)) and the user cap lifted, published as `ghcr.io/bsstudio/mattermost-team-edition`. [README.md](README.md) explains the build, the two build transforms, and how a Mattermost upgrade goes.

## Before calling something done

```bash
docker build -t mattermost .
```

This is the build `build.yml` runs on a pull request; the shared workflow checks in `checks.yml` run only in CI. `docker build` copies the submodule's working tree, not the commit this repo records: when `git submodule status` shows a leading `+`, the local build differs from CI's.

A green build doesn't prove the OIDC login works. Say so when reporting, and leave the README's login smoke test to the maintainer.

## Commits and branches

Commit messages and PR titles are plain imperative sentences. PRs are squash-merged: the PR title becomes the commit on `main`, with an empty body.

## Rules

- A Mattermost upgrade moves `ARG MM_VERSION` in the `Dockerfile` and the submodule's commit together, and that commit must contain `patches/mattermost-v<version>.patch`; the runtime base image follows `MM_VERSION`. Renovate puts both in one PR. README's "Upgrading Mattermost" and "Verify when upgrading" sections cover the rest.
- Every push to `main` rebuilds the image and overwrites the `:<MM_VERSION>` and `:latest` tags, so a change that isn't an upgrade ships under the current version's tag.
