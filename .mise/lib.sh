#!/usr/bin/env bash
set -euo pipefail

# git hands a hook an absolute GIT_DIR, and in a linked worktree that makes
# `git -C lib/iframely` read the outer index. Every call here names its repo.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY

pushd() {
  builtin pushd "$@" > /dev/null
}

popd() {
  builtin popd > /dev/null
}

UPSTREAM_URL="https://github.com/itteco/iframely"

# The upstream tag lib/iframely is pinned to, from the remote: actions/checkout fetches submodules
# shallow and untagged, so `git describe` has nothing to read.
iframely_tag() {
  local sha tag
  sha="$(git -C lib/iframely rev-parse HEAD)"
  tag="$(git ls-remote --tags "$UPSTREAM_URL" | awk -v sha="$sha" '$1 == sha { sub("refs/tags/", "", $2); sub("\\^\\{\\}$", "", $2); print $2 }' | sort -V | tail -1)"
  if [ -z "$tag" ]; then
    echo >&2 "lib/iframely is on $sha, which no upstream tag points at"
    return 1
  fi
  echo "$tag"
}

# Upstream v26.11.13 releases as 26.11.13.N: the last slot is ours ($1), so one upstream tag can
# carry several releases of the series.
iframely_version() {
  local tag
  tag="$(iframely_tag)"
  echo "${tag#v}.${1:-0}"
}

os() {
  osname=$(uname | tr '[:upper:]' '[:lower:]')
  case $osname in
    linux)
      ldd_output=$(ldd --version 2>&1 || true)
      if echo "$ldd_output" | grep -iq musl; then
        osname="alpine"
      fi
      ;;
    darwin) osname="macos" ;;
    cygwin* | mingw*) osname="windows" ;;
  esac
  echo "$osname"
}

arch() {
  cpu="$(uname -m)"
  case "$cpu" in
    aarch64) cpu=arm64 ;;
    x86_64) cpu=amd64 ;;
  esac
  echo "$cpu"
}

if [[ ! ${ARCH-} ]]; then
  ARCH=$(arch)
  export ARCH
fi

if [[ ! ${OS-} ]]; then
  OS=$(os)
  export OS
fi

if [[ ! ${RELEASE_PATH-} ]]; then
  RELEASE_PATH="dist"
  export RELEASE_PATH
fi

run-steps() {
  local -i failed=0
  mkdir -p .cache
  rm -f .cache/checklist
  while (($#)); do
    local name=$1
    shift
    local fn=$1
    shift
    echo "$name..."
    if [[ $failed == 0 ]]; then
      if $fn | indent; then
        echo "- [X] $name" >> .cache/checklist
      else
        ((failed++))
        echo "- [-] $name" >> .cache/checklist
        echo "Failed" | indent
      fi
    else
      echo "- [ ] $name" >> .cache/checklist
      echo "Skipped" | indent
    fi
  done
  if [[ $failed != 0 ]]; then
    return 1
  fi
}

quiet() {
  "$@" > /dev/null
}

indent() {
  local count=2
  local space
  space=$(printf "%${count}s")
  sed "s/^/$space| /g"
}
