#!/usr/bin/env bash
#MISE alias="whitelist"
#MISE description="Bake Iframely's provider allowlist into the tree"
#MISE dir="{{config_root}}"

# Iframely loads the newest whitelist/iframely-*.json and then never fetches WHITELIST_URL, so the
# image needs no route to iframely.com. Upstream's .gitignore already ignores that name.
#
# WHITELIST_SOURCE overrides where the list comes from, for a host that cannot reach iframely.com.

set -Eeuo pipefail

SOURCE="${WHITELIST_SOURCE:-https://iframely.com/qa/domains.json}"
TARGET=lib/iframely/whitelist
# Iframely's list carries ~1900 domains; far fewer means a truncated or wrong response.
MIN_DOMAINS=1000

function clean_out() {
  rm -f "$TARGET"/iframely-*.json
}

function bake() {
  local count stamp
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT

  curl --fail --silent --show-error --location --retry 3 --max-time 60 --output "$tmp" "$SOURCE"

  count="$(jq '.domains | length' "$tmp")"
  if [ "$count" -lt "$MIN_DOMAINS" ]; then
    echo "error: $SOURCE has $count domains, expected at least $MIN_DOMAINS" >&2
    return 1
  fi

  # Upstream's naming, from the newest entry: a list mounted later in the same format sorts after.
  stamp="$(jq -r '[.domains[].date // empty] | max / 1000 | floor | strftime("%Y-%m-%d-%H-%M-UTC")' "$tmp")"

  clean_out
  install -m 0644 "$tmp" "$TARGET/iframely-$stamp.json"
  echo "whitelist: $count domains, $TARGET/iframely-$stamp.json"
}

function main() {
  case ${1-} in
    --clean)
      clean_out
      ;;
    "")
      bake
      ;;
    *)
      echo "usage: mise run whitelist [--clean]" >&2
      return 1
      ;;
  esac
}

main "$@"
