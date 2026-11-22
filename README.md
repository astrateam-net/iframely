# iframely

[Iframely](https://github.com/itteco/iframely) — the open-source URL engine for link previews and
embeds — as a container image configured entirely from environment variables.

```text
ghcr.io/astrateam-net/iframely:<upstream tag>.<N>     e.g. 26.11.13.0
```

It serves upstream's API unchanged on port `8061`:

- `/iframely?url=` — the Iframely format; add `&group=true` for links grouped by rel.
- `/oembed?url=` — the same data as oEmbed.

Point a client at it with its own setting, typically `IFRAMELY_URL=http://iframely:8061`. No API
key is checked; a client that sends one has it ignored.

## Configuration

Every variable is optional. Unset means upstream's default unless the table says otherwise.

| Variable | Default | Effect |
| --- | --- | --- |
| `IFRAMELY_WORKERS_COUNT` | `2` | Node worker processes in the cluster. Unset in upstream, it is one per host CPU. |
| `IFRAMELY_WORKER_MAX_MEMORY_MB` | `250` | A worker is restarted above this resident memory. |
| `IFRAMELY_WORKER_RESTART_PERIOD_SEC` | `1800` | Each worker is restarted after this long. |
| `IFRAMELY_CACHE_ENGINE` | `node-cache` | `node-cache` (per worker, in memory), `redis`, `memcached` or `no-cache`. |
| `IFRAMELY_CACHE_TTL` | `86400` | Seconds a response stays cached. |
| `IFRAMELY_REDIS_URL` | — | `redis://[user:pass@]host:6379/db`, with `IFRAMELY_CACHE_ENGINE=redis`. |
| `IFRAMELY_MEMCACHED_LOCATIONS` | — | `host:11211[,host:11211]`, with `IFRAMELY_CACHE_ENGINE=memcached`. |
| `IFRAMELY_WHITELIST_URL` | Iframely's hosted list | Where the provider allowlist is fetched from, hourly. Empty disables the fetch. |
| `IFRAMELY_BASE_URL` | — | Public URL of this instance, used for `/r/` static files and hosted renders. |
| `IFRAMELY_ALLOWED_ORIGINS` | — | Comma-separated origins allowed by CORS, for browsers that call the API directly. |
| `IFRAMELY_LOCALE` | — | `en_US`-style locale sent as the first `Accept-Language`. |
| `IFRAMELY_GOOGLE_MAPS_KEY` | — | Google Maps embed key; Maps links need it. |
| `IFRAMELY_YOUTUBE_API_KEY` | — | YouTube Data API key; optional, YouTube works without it. |
| `IFRAMELY_POWERED_BY` | `Astra Team` | `X-Powered-By` on every response. |
| `IFRAMELY_HOME_URL` | `https://astrateam.net` | Where `/` redirects. |

`PORT` and `HOST` are read by upstream directly. Anything else upstream's `config.js` accepts can be
set by mounting a YAML file at `/iframely/config.local.yml`; it is applied after the variables.

## The provider allowlist

Domain plugins (YouTube, Vimeo, X, Instagram, Google Maps, Miro and the rest under `plugins/domains/`)
always work. For every other site, oEmbed, Open Graph and Twitter Card players are returned only
for domains on the allowlist; the rest get metadata and thumbnails. The list is fetched from
Iframely every hour by default.

Without internet access to that list, set `IFRAMELY_WHITELIST_URL=` and mount a list as
`/iframely/whitelist/iframely-<timestamp>.json`; the directory is watched and reloaded on change.
The format is in upstream's `docs/QA Whitelist Format.md`.

## Network

The engine fetches whatever URL a client sends it. It refuses loopback, private, link-local and
other non-public addresses — by DNS result, by IP literal and on every redirect — so it cannot be
pointed at the network it runs in. Links to internal sites therefore get no preview.

Players and images in the returned HTML are loaded by the end user's browser from the provider,
not through this service.

## Building

See [AGENTS.md](AGENTS.md): `mise run up` assembles the patched tree, `mise run build` builds and
tests the image.
