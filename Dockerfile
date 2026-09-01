# syntax=docker/dockerfile:1

# Mattermost version (numeric, no leading v). Global ARG so the runtime FROM tag
# resolves; re-declared in the build stage for RUN. Bumped by Renovate.
# renovate: datasource=github-releases depName=mattermost/mattermost extractVersion=^v(?<version>.*)$
ARG MM_VERSION=11.10.1

# ---- build stage ----
# Go minor must match Mattermost's go.mod (v11.9.0 => 1.26); the patch version is
# read from go.mod at build time (see go.work below), the minor is pinned here.
FROM golang:1.26-alpine AS build
RUN apk add --no-cache git make bash build-base
ARG MM_VERSION

WORKDIR /build
RUN git clone --depth 1 --branch "v${MM_VERSION}" https://github.com/mattermost/mattermost.git
COPY external/mattermost-oidc /build/mattermost-oidc

WORKDIR /build/mattermost
# Apply the OIDC patch, then lift the user cap by identifier (not value).
# grep-before/sed/grep-after asserts the rewrite; set -e aborts the build if upstream
# renamed the constants or the sed missed. README explains why there's no limits .patch.
RUN set -eux; \
    git apply "/build/mattermost-oidc/patches/mattermost-v${MM_VERSION}.patch"; \
    f=server/channels/app/limits.go; \
    grep -qE 'maxUsersLimit[[:space:]]*=' "$f"; \
    grep -qE 'maxUsersHardLimit[[:space:]]*=' "$f"; \
    sed -i -E 's/(maxUsersLimit[[:space:]]*=[[:space:]]*)[0-9]+/\1200000000/' "$f"; \
    sed -i -E 's/(maxUsersHardLimit[[:space:]]*=[[:space:]]*)[0-9]+/\1250000000/' "$f"; \
    grep -qE 'maxUsersLimit[[:space:]]*=[[:space:]]*200000000' "$f"; \
    grep -qE 'maxUsersHardLimit[[:space:]]*=[[:space:]]*250000000' "$f"; \
    rm -rf server/enterprise; \
    sed -i '/Enterprise Imports/d; /github.com\/mattermost\/mattermost\/server\/v8\/enterprise/d' \
        server/cmd/mattermost/main.go

WORKDIR /build
# go.work's go directive must be >= every member module's, so derive it from the
# modules instead of pinning: an MM_VERSION bump that moves the go directive would
# otherwise strand a stale version here and fail the build below.
RUN set -eux; \
    gover="$(awk '/^go /{print $2}' \
        mattermost/server/go.mod \
        mattermost/server/public/go.mod \
        mattermost-oidc/go.mod | sort -V | tail -1)"; \
    printf 'go %s\n\nuse (\n    ./mattermost/server\n    ./mattermost/server/public\n    ./mattermost-oidc\n)\n' "$gover" > go.work; \
    cat go.work
WORKDIR /build/mattermost/server
# Build directly, not via `make build`: its setup-go-work target clobbers our go.work.
# CGO_ENABLED=0: static binary — built on alpine/musl, runs on the glibc base.
RUN CGO_ENABLED=0 GOPRIVATE='github.com/mattermost/*' \
    go build -ldflags "-X github.com/mattermost/mattermost/server/public/model.BuildNumber=${MM_VERSION}" \
        -o bin/mattermost ./cmd/mattermost    # -> /build/mattermost/server/bin/mattermost

# ---- runtime: swap our binary into the official Team-Edition image ----
# Base tag bound to MM_VERSION so webapp/assets match the patched binary.
FROM mattermost/mattermost-team-edition:${MM_VERSION} AS runtime
COPY --from=build /build/mattermost/server/bin/mattermost /mattermost/bin/mattermost
