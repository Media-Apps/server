# ownCloud: Server

[![Build Status](https://drone.owncloud.com/api/badges/owncloud-docker/server/status.svg)](https://drone.owncloud.com/owncloud-docker/server)
[![Docker Hub](https://img.shields.io/docker/v/owncloud/server?logo=docker&label=dockerhub&sort=semver&logoColor=white)](https://hub.docker.com/r/owncloud/server)
[![GitHub contributors](https://img.shields.io/github/contributors/owncloud-docker/server)](https://github.com/owncloud-docker/server/graphs/contributors)
[![Source: GitHub](https://img.shields.io/badge/source-github-blue.svg?logo=github&logoColor=white)](https://github.com/owncloud-docker/server)
[![License: MIT](https://img.shields.io/github/license/owncloud-docker/server)](https://github.com/owncloud-docker/server/blob/master/LICENSE)

Official [ownCloud](https://owncloud.com) Docker image. Designed for a host-mounted data volume and external database and cache. Full admin guide: [documentation](https://doc.owncloud.com/server/latest/admin_manual/installation/docker/).

## Purpose and scope

This repository builds the **ownCloud Server** image on top of **owncloud/base** and ships application overlay and entrypoints.

- **Image build:** `v22.04` / `v24.04` Dockerfiles add `owncloud.tar.bz2`, permissions, and runtime overlay.
- **Local stack:** `docker-compose.yml` is for **validation** (ownCloud app **built** from `v24.04/` on `owncloud/base:24.04` + DHI MySQL + DHI Valkey). It is not a substitute for production hardening review.
- **Deploy stack:** `docker-compose.oc.yml` is for **target-host deployment** (prebuilt `owncloud/server:24.04-dhi` with runtime env and external networks).
- **DHI-related pieces:** database and cache images come from `dhi.io`; the app image is **`owncloud/server:${OWNCLOUD_IMAGE_TAG}`** after `docker compose build` (default tag in `.env`: `24.04-dhi`).

## Quick start (new team members)

### Prerequisites

- Docker with Compose v2
- Local **`owncloud/base:24.04`** (build from **owncloud-docker/base** DHI path: `owncloud/php:8.3-dhi` then `owncloud/base:24.04`)
- **`v24.04/owncloud.tar.bz2`** and **`v24.04/overlay/`** — use `scripts/prepare-v24.04-context.sh` (official bundle from download.owncloud.com, SHA-checked; overlay synced from upstream)
- Pull access to **`dhi.io`** images used by compose

### Run the bundled stack

```bash
# First time (or after changing base / Dockerfile): rebuild app image
docker compose build --no-cache
docker compose up -d
```

Defaults (see `.env`):

- UI: `http://localhost:18081` (port from `HTTP_PORT`)
- Admin: `admin` / `admin` unless overridden

### Smoke check

```bash
curl -fsS http://127.0.0.1:18081/status.php
```

Expect JSON including `"installed":true`.

## Team contract (must hold true)

### Build order (full pipeline)

1. Build custom PHP and base images (**owncloud-docker/base**, DHI path): `owncloud/php:8.3-dhi` → `owncloud/base:24.04`
2. Build server image from this repo with the correct **owncloud tarball** for the target version
3. Run compose or integration tests and verify HTTP + logs

Server `v24.04` expects **`FROM owncloud/base:24.04`** (see `v24.04/Dockerfile.multiarch`).

### Compose stack roles

| Role | Image | Service name |
|------|--------|----------------|
| App | `owncloud/server:${OWNCLOUD_IMAGE_TAG}` (built from `./v24.04`) | `owncloud` |
| DB | `dhi.io/mysql:8.4` | `mysql_dhi` |
| DB bootstrap | `dhi.io/mysql:8.4` (one-shot SQL) | `mysql_bootstrap` |
| Cache | `dhi.io/valkey:8` | `redis` (name kept for ownCloud env compatibility) |

- App uses `OWNCLOUD_DB_HOST=mysql_dhi` and `OWNCLOUD_REDIS_HOST=redis`.
- `mysql_bootstrap` runs after DB healthcheck and creates `owncloud` database/user/grants.

### PHP runtime note

The application container inherits PHP from **owncloud/base**. For DHI-based `24.04`, PHP lives under `/opt/php-8.3` and extensions are defined in **base** (`php-dhi.Dockerfile`). Do not assume Debian `php8.3-*` packages extend that runtime.

## Resolved issues and current watch list

### Resolved / documented

- **DB/cache on DHI:** compose uses `dhi.io/mysql:8.4` and `dhi.io/valkey:8` with healthchecks.
- **Valkey volume permissions:** if `dump.rdb` permission errors appear after switching from legacy Redis, recreate only the Redis volume (see below).
- **MySQL DHI initialization behavior:** documented in repo root `../CHANGELOG.md` (iteration 2026-04-01 14:00 UTC) and implemented via one-shot `mysql_bootstrap`.
- **Apache health path on DHI app image:** base overlay now sets missing Apache defaults (`APACHE_SERVER_ADMIN`, `APACHE_LOG_FORMAT`) and renders ownCloud config into `000-default.conf`; compose explicitly sets `APACHE_LISTEN=80` so healthcheck and mapped port stay aligned.

### Current watch list

- **DHI app stack:** after base or tarball bumps, re-run `docker compose build` and smoke checks (`status.php`, login, file ops).
- **MySQL tags:** use a tag that actually pulls in your environment (e.g. `8.4` vs `8`).
- **MySQL image behavior changes:** re-check entrypoint semantics when upgrading `dhi.io/mysql` (root init, `MYSQL_OPTIONS`, SQL bootstrap assumptions).
- **Version alignment:** ownCloud tarball major/minor must match the selected PHP in base.

## Compatibility and tags

- [`10.16.0`](https://github.com/owncloud-docker/server/blob/master/v22.04/Dockerfile.multiarch) → `owncloud/server:10.16.0`, `owncloud/server:10.16`, `owncloud/server:10`, `owncloud/server:latest`
- [`10.15.3`](https://github.com/owncloud-docker/server/blob/master/v22.04/Dockerfile.multiarch) → `owncloud/server:10.15.3`, `owncloud/server:10.15`
- **`v24.04`** Dockerfile in this repo tracks the DHI base path (`owncloud/base:24.04`); published tags follow upstream release naming when merged.

## Prepare `v24.04` build context (official tarball)

The tarball is **not** committed (see `.gitignore`). Refresh it and the upstream overlay directory with:

```bash
./scripts/prepare-v24.04-context.sh
```

Default download is the stable ownCloud bundle (`owncloud-10.16.1.tar.bz2`). Override with `OWNCLOUD_TAR_URL` / `OWNCLOUD_TAR_SHA256` if you want a different or pinned artifact.

## Building the server image

Parent image is set in each `Dockerfile.multiarch` (e.g. `FROM docker.io/owncloud/base:24.04` for `v24.04`). If your branch supports **`ARG BASE_IMAGE`**, you can override at build time:

```bash
docker build \
  --build-arg BASE_IMAGE=your-registry/owncloud-base-hardened:24.04 \
  -f v24.04/Dockerfile.multiarch \
  v24.04
```

## Local Docker Compose (details)

Files: `docker-compose.yml`, `.env`.
MySQL DHI operational details and validation notes: `../CHANGELOG.md` (see iteration 2026-04-01 14:00 UTC).

**Valkey / Redis volume:** if you migrated an existing setup and see errors around `dump.rdb`, recreate only the Redis data volume:

```bash
docker compose down
docker volume rm server-master_redis
docker compose up -d
```

Adjust volume name if your project directory name differs (Compose prefixes volumes with the project name).

## About ownCloud

ownCloud is open-source file sync, share, and collaboration software: web UI, sync clients, WebDAV, under your control. See [owncloud.com](https://owncloud.com).

![Secure content collaboration and filesharing with ownCloud](https://raw.githubusercontent.com/owncloud-docker/server/master/images/Home-UI.png)

## Quick reference

- **Where to file issues (product):** [owncloud/core](https://github.com/owncloud/core/issues)
- **Supported architectures:** `amd64`, `arm64v8`
- **Inherited environments:** [owncloud/ubuntu](https://github.com/owncloud-docker/ubuntu#environment-variables), [owncloud/php](https://github.com/owncloud-docker/php#environment-variables), [owncloud/base](https://github.com/owncloud-docker/base#environment-variables)

## Default volumes

- `/mnt/data`

## Exposed ports

- 8080 (mapped via `HTTP_PORT` in compose)

## Environment variables

Compose `.env` (subset):

- `OWNCLOUD_IMAGE_TAG` — tag for the locally built app image (default `24.04-dhi`)
- `OWNCLOUD_BUNDLE_VERSION` — informational; documents which ownCloud bundle `owncloud.tar.bz2` matches (see `scripts/prepare-v24.04-context.sh`)
- `HTTP_PORT`, `OWNCLOUD_DOMAIN`, `OWNCLOUD_TRUSTED_DOMAINS`, `ADMIN_USERNAME`, `ADMIN_PASSWORD`

Full image/runtime variables are documented under **owncloud/base** and upstream `ENVIRONMENT.md`.

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/owncloud-docker/server/blob/master/LICENSE) file for details.

## Copyright

```Text
Copyright (c) 2022 ownCloud GmbH
```
