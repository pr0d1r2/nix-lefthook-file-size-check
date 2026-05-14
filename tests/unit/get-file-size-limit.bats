#!/usr/bin/env bats

setup() {
    load "${BATS_LIB_PATH}/bats-support/load.bash"
    load "${BATS_LIB_PATH}/bats-assert/load.bash"

    TMP="$BATS_TEST_TMPDIR"

    cat > "$TMP/limits.yml" <<'YAML'
default: 100
extensions:
  nix: 5000
  sh: 2000
YAML
}

@test "returns extension-specific limit" {
    run get-file-size-limit nix "$TMP/limits.yml"
    assert_success
    assert_output "5000"
}

@test "returns default when extension not found" {
    run get-file-size-limit unknown "$TMP/limits.yml"
    assert_success
    assert_output "100"
}

@test "returns empty when no default and no match" {
    cat > "$TMP/no-default.yml" <<'YAML'
extensions:
  nix: 5000
YAML
    run get-file-size-limit unknown "$TMP/no-default.yml"
    assert_success
    assert_output ""
}

@test "handles multiple extensions" {
    run get-file-size-limit sh "$TMP/limits.yml"
    assert_success
    assert_output "2000"
}
