# Mattermost (BSStudio build)

Mattermost Team Edition with OIDC login and the user cap lifted.

OIDC support is patched in from the
[`BSStudio/mattermost-oidc`](https://github.com/BSStudio/mattermost-oidc) fork. The patched
binary is swapped into the official image, so the stock webapp and assets are reused — no
webapp rebuild.

## Build

```bash
git clone --recurse-submodules https://github.com/BSStudio/mattermost-image
cd mattermost-image
docker build -t mattermost .
```

The Mattermost version is the single `ARG MM_VERSION` in the [Dockerfile](Dockerfile); the
runtime base image is pinned to it so webapp and binary always match.

## The two build transforms

- **OIDC patch** — `git apply`ed from the submodule (`patches/mattermost-v<version>.patch`).
- **User-cap lift** — `maxUsersLimit` / `maxUsersHardLimit` in `server/channels/app/limits.go`
  are rewritten **by identifier, not value**, with grep assertions before and after. A stored
  patch would embed the old constants and break when upstream changes them (it already went
  `5000/11000` → `200/250`); this needs no per-release maintenance. If upstream renames the
  constants, the assertions fail the build loudly.

`server/enterprise` is stripped so we ship pure Team Edition (see Licensing).

## CI

[build.yml](.github/workflows/build.yml): pull requests build only; push to `main` builds and
pushes `:<version>` and `:latest`. First push to `main` is manual after a green build and an
OIDC login smoke test.

## Upgrading Mattermost

Renovate groups `MM_VERSION` and the OIDC submodule into one PR. When that PR fails, the OIDC
patch for the new version doesn't exist yet:

1. In the fork: regenerate the patch, bump `go.mod`, merge to its `main`.
2. Point the PR's submodule SHA at that commit.
3. Bump `FROM golang:<minor>` only if Mattermost's go directive crossed a minor.
4. Green build + OIDC smoke test → merge → image publishes.

Go minor is not auto-bumped — it follows Mattermost's `go.mod`.

## Verify when upgrading

- The `mattermost/mattermost-team-edition:<version>` base image exists and keeps the binary at
  `/mattermost/bin/mattermost`. If not, build the runtime from the release tarball.
- The OpenID button renders after boot. If not, that's the only thing forcing a webapp build —
  flag it, don't ship broken login.

## Licensing

Team Edition code and the OIDC patch are AGPL-3.0 (see [LICENSE](LICENSE)). We strip
`server/enterprise`
(source-available, not AGPL), so we ship pure Team Edition; the lifted cap is the Team-Edition
freemium limit, not an enterprise feature. Keeping this repo and the fork public satisfies the
AGPL network-use source offer. Not legal advice.
