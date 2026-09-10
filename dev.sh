# shellcheck shell=bash
export BATS_LIB_PATH="@BATS_LIB_PATH@/share/bats"
export PATH="@LOCAL_BIN@:$PATH"
[ -f .git/hooks/pre-commit ] || lefthook install
