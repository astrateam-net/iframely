#!/usr/bin/env bats

# Integrity of the patch series itself. The suite pops and pushes the whole
# series — it restores the state it found, but nothing else may read the tree
# while it runs.

ROOT="$BATS_TEST_DIRNAME/../.."
PATCHES="$ROOT/patches"

# File scope, not setup_file: a hook exports GIT_DIR, and check 10 would then
# read the outer index and call every upstream file unowned.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY

setup_file() {
  cd "$ROOT" || exit 1
  # Check 9 rewrites patches, so quilt's prefix must be pinned even when bats
  # was launched outside `mise run`, which is what exports QUILTRC.
  : "${QUILTRC:=$ROOT/.quiltrc}"
  export QUILTRC
  # Remember what was applied so the suite is a no-op on a dev machine mid-work.
  QUILT_STATE_TOP="$(quilt top 2> /dev/null || true)"
  export QUILT_STATE_TOP
}

teardown_file() {
  cd "$ROOT" || exit 1
  quilt pop -a > /dev/null 2>&1 || true
  if [ -n "${QUILT_STATE_TOP:-}" ]; then
    quilt push "$QUILT_STATE_TOP" > /dev/null 2>&1 || true
  fi
}

series_entries() {
  grep -v '^[[:space:]]*\(#\|$\)' "$PATCHES/series"
}

@test "series file exists" {
  [ -f "$PATCHES/series" ]
}

@test "every entry in series exists on disk" {
  local missing=""
  while read -r p; do
    [ -f "$PATCHES/$p" ] || missing="$missing $p"
  done < <(series_entries)
  [ -z "$missing" ] || {
    echo "listed in patches/series but not on disk (restore the file, or delete the line):$missing"
    false
  }
}

@test "every patch on disk is listed in series" {
  local orphan=""
  for f in "$PATCHES"/*.diff; do
    [ -e "$f" ] || continue # no patches yet: the glob stays literal
    local base
    base="$(basename "$f")"
    series_entries | grep -qxF "$base" || orphan="$orphan $base"
  done
  [ -z "$orphan" ] || {
    echo "on disk but not in patches/series (add it at its apply position, or delete it):$orphan"
    false
  }
}

@test "patch names carry no ordinal prefix" {
  # Order is data in series, never a filename convention.
  local numbered=""
  while read -r p; do
    case "$p" in [0-9]*) numbered="$numbered $p" ;; esac
  done < <(series_entries)
  [ -z "$numbered" ] || {
    echo "ordinal-prefixed names (order is data in patches/series — rename to the capability):$numbered"
    false
  }
}

@test "every patch names a test file that exists" {
  # The header naming the covering test in backticks is the only link from a
  # patch to its test. Necessary, not sufficient.
  local bad=""
  while read -r p; do
    local named f
    # shellcheck disable=SC2016  # backticks are literal here: the header quotes
    # test paths in backticks, and this matches that, not a subshell.
    named="$(sed -n '/^Index:/q;p' "$PATCHES/$p" \
      | grep -oE '`test/[A-Za-z0-9._/-]+\.js`' | tr -d '`' | sort -u)"
    if [ -z "$named" ]; then
      bad="$bad $p(names-none)"
      continue
    fi
    for f in $named; do
      # A backport may carry the upstream test it adds, absent from the pristine tree.
      [ -f "$ROOT/lib/iframely/$f" ] \
        || grep -qxF "+++ b/lib/iframely/$f" "$PATCHES/$p" \
        || bad="$bad $p:$f(missing)"
    done
  done < <(series_entries)
  [ -z "$bad" ] || {
    echo "every header must name its covering test in backticks, as test/<path>.js:$bad"
    echo "  names-none = the header names no test; missing = the named file is not under lib/iframely/"
    false
  }
}

@test "every patch opens with a rationale header" {
  # quilt keeps free text above the first Index: line.
  local bare=""
  while read -r p; do
    head -1 "$PATCHES/$p" | grep -q '^Index:' && bare="$bare $p"
  done < <(series_entries)
  [ -z "$bare" ] || {
    echo "no rationale header (quilt header -e <patch>: symptom, cause, how to check, test name):$bare"
    false
  }
}

@test "the whole series applies to the pinned submodule" {
  [ -n "$(series_entries)" ] || skip "empty series"
  cd "$ROOT"
  quilt pop -a > /dev/null 2>&1 || true
  run quilt push -a
  [ "$status" -eq 0 ] || {
    echo "$output"
    echo "restack it: quilt push -f, apply the *.rej hunks by hand, quilt refresh"
    false
  }
}

@test "no patch applies with fuzz" {
  [ -n "$(series_entries)" ] || skip "empty series"
  # Fuzz means the patch survived on context alone — one edit from a silent
  # mis-apply.
  cd "$ROOT"
  quilt pop -a > /dev/null 2>&1 || true
  run quilt push -a
  echo "$output" | grep -qi "with fuzz" && {
    echo "$output" | grep -i "with fuzz"
    echo "re-anchor it: quilt push to that patch, quilt refresh, and commit the result"
    false
  }
  [ "$status" -eq 0 ]
}

@test "every patch is refreshed — a rebuild changes nothing" {
  # The committed patch must be byte-identical to what quilt would write now —
  # what makes a hand-edited or stale patch impossible to hide.
  cd "$ROOT"
  quilt pop -a > /dev/null 2>&1 || true
  local stale=""
  while quilt push > /dev/null 2>&1; do
    local top before after
    top="$(quilt top)"
    before="$(md5 -q "$ROOT/$top" 2> /dev/null || md5sum "$ROOT/$top" | cut -d' ' -f1)"
    quilt refresh > /dev/null 2>&1 || true
    after="$(md5 -q "$ROOT/$top" 2> /dev/null || md5sum "$ROOT/$top" | cut -d' ' -f1)"
    [ "$before" = "$after" ] || stale="$stale $(basename "$top")"
  done
  [ -z "$stale" ] || {
    echo "not refreshed (run quilt refresh and commit):$stale"
    false
  }
}

@test "every file in the submodule tree is owned by a patch or the overlay" {
  # Silent failure: `quilt add` snapshots what is on disk, so adding a file that
  # was written first records it as unchanged and `quilt refresh` captures
  # nothing. It keeps working locally and a fresh checkout loses it.
  cd "$ROOT"
  quilt pop -a > /dev/null 2>&1 || true
  quilt push -a > /dev/null 2>&1 || true
  mise run overlay > /dev/null

  local owned orphans=""
  owned="$( {
    grep -hs '^+++ [^/]*/lib/iframely/' "$PATCHES"/*.diff \
      | sed 's|^+++ [^/]*/lib/iframely/||' \
      | sed 's/[[:space:]].*$//'
    [ -d "$ROOT/overlay" ] && (cd "$ROOT/overlay" && find . -type f | sed 's|^\./||')
  } | sort -u)"

  local f
  for f in $(git -C lib/iframely ls-files -o --exclude-standard); do
    echo "$owned" | grep -qxF "$f" || orphans="$orphans $f"
  done

  [ -z "$orphans" ] || {
    echo "in the tree but in no patch (quilt add BEFORE creating, then refresh):$orphans"
    false
  }
}
