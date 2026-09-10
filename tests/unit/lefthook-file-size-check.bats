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

# ---- path-keyed exemptions, end to end --------------------------------------

@test "a path exemption lets one named file exceed its extension limit" {
    cat >"$TMP/config/lefthook/file_size_limits.yml" <<'YAML'
default: 100
extensions:
  md: 10
paths:
  SPEC.md: 100000
YAML
    cd "$TMP"
    printf 'x%.0s' $(seq 1 500) >SPEC.md
    printf 'x%.0s' $(seq 1 500) >OTHER.md
    run lefthook-file-size-check SPEC.md
    assert_success
    run lefthook-file-size-check OTHER.md
    assert_failure
    assert_output --partial "OTHER.md"
}

@test "a ./-prefixed path still matches its exemption" {
    # lefthook passes bare paths, a find passes ./-prefixed ones, and an
    # exemption that depends on which one called is not an exemption.
    cat >"$TMP/config/lefthook/file_size_limits.yml" <<'YAML'
default: 100
extensions:
  md: 10
paths:
  SPEC.md: 100000
YAML
    cd "$TMP"
    printf 'x%.0s' $(seq 1 500) >SPEC.md
    run lefthook-file-size-check ./SPEC.md
    assert_success
}

@test "a violation names the RULE that decided it" {
    cat >"$TMP/config/lefthook/file_size_limits.yml" <<'YAML'
default: 100
extensions:
  md: 10000
paths:
  docs/inventory.md: 10
YAML
    cd "$TMP"
    mkdir -p docs
    printf 'x%.0s' $(seq 1 500) >docs/inventory.md
    run lefthook-file-size-check docs/inventory.md
    assert_failure
    assert_output --partial "path: docs/inventory.md"
}

@test "an extension violation still names the extension" {
    cat >"$TMP/config/lefthook/file_size_limits.yml" <<'YAML'
default: 100
extensions:
  md: 10
YAML
    cd "$TMP"
    printf 'x%.0s' $(seq 1 500) >README.md
    run lefthook-file-size-check README.md
    assert_failure
    assert_output --partial "(.md)"
}
