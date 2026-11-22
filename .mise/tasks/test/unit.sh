#!/usr/bin/env bash
#MISE description="Tests the series and the overlay carry, run with upstream's mocha"
#MISE dir="{{config_root}}"
#MISE depends=["up"]
# Scoped to what the series and overlay touch: upstream's plugin suite reaches live third-party sites.
set -Eeuo pipefail

# Every test a patch header names, plus every overlay test, relative to lib/iframely.
tests() {
  {
    [ -d overlay/test ] && (cd overlay && find test -type f -name '*.test.js')
    # shellcheck disable=SC2016  # backticks are literal: headers quote test paths in them.
    grep -v '^[[:space:]]*\(#\|$\)' patches/series | while read -r p; do
      sed -n '/^Index:/q;p' "patches/$p" | grep -oE '`test/[A-Za-z0-9._/-]+\.js`' | tr -d '`'
    done
  } | sort -u
}

main() {
  local files
  files="$(tests)"
  if [ -z "$files" ]; then
    echo "error: the series and overlay carry no tests" >&2
    return 1
  fi

  cd lib/iframely
  local f
  for f in $files; do
    echo "== $f"
    # One process per file: each test loads its own config, and CONFIG is a process global.
    NODE_ENV="test" pnpm exec mocha --exit "$f"
  done
}

main "$@"
