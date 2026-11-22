#!/usr/bin/env bash
#MISE alias="overlay"
#MISE description="Copy our own source into the patched Iframely tree"
#MISE dir="{{config_root}}"

# Runs AFTER `quilt push -a`, never before.
#
# `--clean` exists because `quilt pop -a` does NOT undo a copy: the files are
# untracked in the submodule and survive a pop.

set -Eeuo pipefail

# Inherited git env would point `git -C` at the outer repo — see .mise/lib.sh.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY

# Upstream keeps its files at the repo root, so overlay/<path> lands at lib/iframely/<path>.
ROOT=overlay
TARGET=lib/iframely

# Every overlay file, relative to overlay/ (= relative to lib/iframely).
function overlay_files() {
  [ -d "$ROOT" ] || return 0
  (cd "$ROOT" && find . -type f | sed 's|^\./||') | sort
}

# Every path any patch touches, relative to lib/iframely.
function patched_files() {
  local p
  while read -r p; do
    [ -n "$p" ] || continue
    quilt files "$p" 2> /dev/null || true
  done < <(grep -v '^[[:space:]]*\(#\|$\)' patches/series) \
    | sed -n "s|^$TARGET/||p" | sort -u
}

# The overlay copies last, so a path owned by both would silently overwrite the
# patch's result.
function check_disjoint() {
  local both
  both=$(comm -12 <(overlay_files) <(patched_files))
  if [ -n "$both" ]; then
    echo "error: these paths are owned by BOTH a patch and the overlay:" >&2
    # shellcheck disable=SC2001  # indenting every line of a multi-line value is
    # not a substring replacement; ${var//} cannot express it.
    echo "$both" | sed 's/^/  /' >&2
    echo "move the change into the overlay file, or delete the overlay copy." >&2
    return 1
  fi
}

function copy_in() {
  local dest=$1 f
  while read -r f; do
    [ -n "$f" ] || continue
    mkdir -p "$(dirname "$dest/$f")"
    cp "$ROOT/$f" "$dest/$f"
  done < <(overlay_files)
}

# A path the overlay owns that git tracks is upstream's — refuse, never delete.
function clean_out() {
  local f target removed=0 tracked=""
  while read -r f; do
    [ -n "$f" ] || continue
    target="$TARGET/$f"
    [ -e "$target" ] || continue
    if git -C "$TARGET" ls-files --error-unmatch "$f" > /dev/null 2>&1; then
      tracked="$tracked $f"
      continue
    fi
    rm -f "$target"
    removed=$((removed + 1))
  done < <(overlay_files)

  if [ -n "$tracked" ]; then
    echo "error: upstream now tracks a path the overlay owns:$tracked" >&2
    echo "not deleting it. decide whether ours is still needed." >&2
    return 1
  fi
  echo "overlay: removed $removed files from $TARGET"
}

function main() {

  case ${1-} in
    --check)
      check_disjoint
      echo "overlay: $(overlay_files | wc -l | tr -d ' ') files, disjoint from patches"
      ;;
    --clean)
      clean_out
      ;;
    --into)
      [ -n "${2-}" ] || {
        echo "usage: mise run overlay --into <root>" >&2
        return 1
      }
      [ -d "$2" ] || {
        echo "no such tree: $2" >&2
        return 1
      }
      copy_in "$2"
      echo "overlay: copied $(overlay_files | wc -l | tr -d ' ') files into $2"
      ;;
    "")
      check_disjoint
      copy_in "$TARGET"
      echo "overlay: copied $(overlay_files | wc -l | tr -d ' ') files into $TARGET"
      ;;
    *)
      echo "usage: mise run overlay [--check | --clean | --into <root>]" >&2
      return 1
      ;;
  esac
}

main "$@"
