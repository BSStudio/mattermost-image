# CLAUDE.md

Budavári Schönherz Stúdió's Mattermost image: Team Edition with the OIDC login patch from the `external/mattermost-oidc` submodule ([BSStudio/mattermost-oidc](https://github.com/BSStudio/mattermost-oidc)) and the user cap lifted, published as `ghcr.io/bsstudio/mattermost-team-edition`. [README.md](README.md) explains the build, the two build transforms, and how a Mattermost upgrade goes.

## Before calling something done

```bash
docker build -t mattermost .
node <BSStudio/.github clone>/scripts/check-workflows.mjs .github/workflows/*.yml   # after a workflow change
```

The first is the build `build.yml` runs on a pull request. The second is the convention checker from the Workflows job of the shared checks `checks.yml` calls; that job's actionlint and zizmor run only in CI.

`docker build` copies the submodule's working tree, not the commit this repo records. An empty `external/mattermost-oidc` means the submodule isn't initialised: run `git submodule update --init`. A leading `+` in `git submodule status` means the checkout differs from the recorded commit, so the local build differs from CI's; the checkout may hold the maintainer's work, so ask before updating it.

A green build doesn't prove the OIDC login works. Say so when reporting, and leave the OIDC login smoke test (the OpenID button renders and a login completes) to the maintainer.

## Commits and branches

Commit messages and PR titles are plain imperative sentences. PRs are squash-merged: the PR title becomes the commit on `main`, with an empty body.

## Rules

- The submodule's commit must contain `patches/mattermost-v<version>.patch` for the `MM_VERSION` in the `Dockerfile`. README's "Upgrading Mattermost" and "Verify when upgrading" sections describe the upgrade.
- Every push to `main` rebuilds the image and overwrites the `:<MM_VERSION>` and `:latest` tags, so a change that isn't an upgrade ships under the current version's tag.
