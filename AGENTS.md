# iframely

Upstream [Iframely](https://github.com/itteco/iframely) (Node.js, MIT) pinned as the `lib/iframely`
submodule at a release tag, plus a quilt series and our own source. The artifact is a Docker image
of the patched tree, built with upstream's Dockerfile and configured entirely from environment
variables — [README.md](README.md) lists them.

## Two owners, disjoint

**`patches/` modifies files that exist upstream. `overlay/` adds files that do not.** No path may be
owned by both; `mise run overlay --check` fails if one is.

Upstream keeps its files at the repo root, so `overlay/<path>` is copied to `lib/iframely/<path>`:
`overlay/config.local.js` becomes the `config.local.js` that upstream's `config.js` loads under
`NODE_ENV=local`, which the image sets.

The order is always `quilt push -a` → `mise run overlay` → build or test; `mise run up` is both halves.

## Commands

| Task | Command |
| --- | --- |
| Assemble the tree | `mise run up` |
| Back to pristine upstream | `mise run down` |
| Who owns a file | `mise run owner <path>` |
| Copy the overlay into another tree | `mise run overlay --into <root>` |
| Series integrity (10 checks) | `mise run test:series` |
| Tests the series and overlay carry | `mise run test:unit` — needs `pnpm install --frozen-lockfile` in `lib/iframely` |
| Lint every file type | `mise run lint` |
| Everything that gates a push | `mise run check` |
| Build the image and run `tests.yaml` | `mise run build [patch]` — tags `iframely:26.11.13.<patch>` |
| That, after every gate | `mise run ci` |
| Publish `ghcr.io/astrateam-net/iframely:26.11.13.N` | dispatch `Draft release` with `version` = the upstream tag and `patch` = N, then publish the draft; a published tag is never overwritten |

quilt is a system package (`brew install quilt`, `apt-get install quilt`), not a mise tool. Never run
`quilt` outside `mise`: `.quiltrc` reaches quilt only through the `QUILTRC` that mise exports.

## Versions

Upstream tags releases by date, `v26.11.13`. Ours is that tag plus one slot: `26.11.13.0`, then
`26.11.13.1` for the same upstream with a changed series. The pin is resolved against upstream's
tags on the remote (`iframely_tag` in `.mise/lib.sh`), so the submodule must sit exactly on a tag.

## Bumping the pin

1. `git -C lib/iframely fetch --tags && git -C lib/iframely checkout <tag>`.
2. `mise run up`. A backport that upstream now contains fails as already applied: delete it from
   `patches/series` and `patches/`. Restack the rest: `quilt push -f`, fix the `*.rej` hunks,
   `quilt refresh`.
3. Re-read each remaining patch against the new upstream: still needed, still tested.
4. `mise run ci`, then a changelog entry naming the upstream tag.

## Write facts, not prose

**A comment states what and why in one or two lines. Never more than the code it explains.** This
binds every doc, comment, patch header and commit message in the repo. Describe what the code does;
never how the change came about.

## The quality bar

1. **Use Iframely's own building block** — `CONFIG` keys `config.js` already reads, the
   graceful-cluster options, the whitelist loader, the SSRF guard in `lib/fetch.js`.
2. **Add a new building block in the overlay**, at the path it would have upstream.
3. Never a workaround.

Overlay JS and JSON follow `biome.jsonc`, not upstream's style: this is our build, not a fork for
pull requests. Patches follow upstream's style in the file they touch. Overlay tests are mocha files
named `test/<capability>.test.js`, run by upstream's own mocha.

Commits here are conventional (`feat: …`, lowercase imperative, about 60 characters), enforced by hk.

## Invariants

- `patches/**` or `lib/iframely/**` → read `.claude/rules/quilt-mechanics.md` before editing.
- **A patch applying cleanly is not acceptance.** It must still be needed and still be tested.
- **A backport names the upstream commit** in its header and leaves on the first bump whose tag
  contains it.
- **An unverified claim is labelled unverified.**
