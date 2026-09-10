# shellcheck shell=bash
# The shared dev shell ships a PINNED copy of this very tool -- it is one of the
# lefthook wrappers every repository in the fleet gets -- and it sits EARLIER on
# PATH than the packages this flake builds. Left alone, `lefthook-file-size-check`
# is the last RELEASE rather than the working tree, so the checks pass or fail on
# code that is not the code under review and a change to the checker cannot be
# tested by the checker.
#
# This runs in the CI shell as well as the interactive one, because CI is where
# it matters: `nix develop .#ci --ignore-environment` has no ambient PATH to fall
# back on, and the shared shell's copy is then the ONLY one.
export PATH="@LOCAL_BIN@:$PATH"
