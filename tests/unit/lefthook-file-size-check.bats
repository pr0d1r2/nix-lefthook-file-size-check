#!/usr/bin/env bats

setup() {
    load "${BATS_LIB_PATH}/bats-support/load.bash"
    load "${BATS_LIB_PATH}/bats-assert/load.bash"

    TMP="$BATS_TEST_TMPDIR"

    # Create config
    mkdir -p "$TMP/config/lefthook"
    cat > "$TMP/config/lefthook/file_size_limits.yml" <<'YAML'
default: 100
extensions:
  big: 1000
YAML
    export LEFTHOOK_FILE_SIZE_CONFIG="$TMP/config/lefthook/file_size_limits.yml"
}

@test "no args exits 0" {
    run lefthook-file-size-check
    assert_success
}

@test "non-existent file is skipped" {
    run lefthook-file-size-check /nonexistent/file.txt
    assert_success
}

@test "small file passes" {
    echo "small" > "$TMP/small.txt"
    run lefthook-file-size-check "$TMP/small.txt"
    assert_success
}

@test "oversized file fails" {
    dd if=/dev/zero of="$TMP/large.txt" bs=200 count=1 2>/dev/null
    run lefthook-file-size-check "$TMP/large.txt"
    assert_failure
    assert_output --partial "File size limit exceeded"
}

@test "extension-specific limit used" {
    dd if=/dev/zero of="$TMP/medium.big" bs=500 count=1 2>/dev/null
    run lefthook-file-size-check "$TMP/medium.big"
    assert_success
}

@test "extension-specific limit exceeded" {
    dd if=/dev/zero of="$TMP/huge.big" bs=1100 count=1 2>/dev/null
    run lefthook-file-size-check "$TMP/huge.big"
    assert_failure
}

@test "missing config fails" {
    LEFTHOOK_FILE_SIZE_CONFIG=/nonexistent/config.yml run lefthook-file-size-check "$TMP/small.txt"
    assert_failure
    assert_output --partial "config not found"
}

@test "multiple files: one oversized fails" {
    echo "ok" > "$TMP/good.txt"
    dd if=/dev/zero of="$TMP/bad.txt" bs=200 count=1 2>/dev/null
    run lefthook-file-size-check "$TMP/good.txt" "$TMP/bad.txt"
    assert_failure
}
