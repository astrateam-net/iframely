#!/usr/bin/env bash
#MISE alias="down"
#MISE description="Return lib/iframely to pristine upstream"
#MISE dir="{{config_root}}"
set -Eeuo pipefail

# The overlay's copies and the baked list are untracked in the submodule, so a
# pop leaves them behind.
quilt pop -a > /dev/null 2>&1 || true
mise run overlay --clean
mise run whitelist --clean
