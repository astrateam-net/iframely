# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

Versions are the upstream Iframely tag plus one slot of ours: upstream `v26.11.13` ships as
`26.11.13.0`, and `26.11.13.1` is the same upstream with a changed patch series.

Each entry also names the upstream tag in full, on its own line under the heading.

<!-- Example:

## [99.9.9.0] - 9090-09-09

Iframely v99.9.9

### Changed
### Added
### Deprecated
### Removed
### Fixed
### Security

-->

## Unreleased

Iframely v26.11.13

### Changed

- The image carries Iframely's provider allowlist, downloaded when it is built, and no longer
  fetches it at runtime. A deployment that could not reach iframely.com ran with an empty list.

## [26.11.13.1] - 2026-11-22

Iframely v26.11.13

### Added

- Miro boards embed from both the board link and the Embed tab's `live-embed` link, as Miro's
  live-embed iframe with the viewport kept. The page is never fetched: it is robots `noindex`.

## [26.11.13.0] - 2026-11-22

Iframely v26.11.13

### Added

- Configuration from environment variables: cache engine and Redis or Memcached, worker count and
  restarts, allowlist source, base URL, CORS origins, locale and provider keys.
- `IFRAMELY_WORKERS_COUNT`: the cluster forks a fixed number of workers, 2 by default, instead of
  one per host CPU.
- `IFRAMELY_POWERED_BY` and `IFRAMELY_HOME_URL` set the `X-Powered-By` header and the `/` redirect.

### Security

- Backport of upstream 8ab98c12: IP-literal hosts, hosts behind userinfo and redirects to
  non-public addresses are refused.
