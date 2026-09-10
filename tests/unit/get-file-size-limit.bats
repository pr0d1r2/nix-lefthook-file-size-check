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

# ---- path-keyed limits ------------------------------------------------------
# One known-large file should not force the ceiling up for every file sharing
# its extension. A `paths:` entry names that file, so the exemption is visible
# in the config with a reason beside it rather than hidden in a raised limit
# nobody can attribute later.

setup_paths() {
    cat >"$TMP/paths.yml" <<'YAML'
default: 100
extensions:
  nix: 5000
  md: 1000
paths:
  # the whole-repository spec: one file, declared, with a reason
  SPEC.md: 200000
  docs/inventory.md: 250
YAML
}

@test "a paths entry beats the extension limit" {
    setup_paths
    run get-file-size-limit md "$TMP/paths.yml" SPEC.md
    assert_success
    assert_output "200000"
}

@test "a paths entry can also be SMALLER than the extension limit" {
    setup_paths
    run get-file-size-limit md "$TMP/paths.yml" docs/inventory.md
    assert_success
    assert_output "250"
}

@test "a nested path key matches on the full repo-relative path" {
    setup_paths
    run get-file-size-limit md "$TMP/paths.yml" other/inventory.md
    assert_success
    assert_output "1000"
}

@test "a file with no paths entry still gets its extension limit" {
    setup_paths
    run get-file-size-limit md "$TMP/paths.yml" README.md
    assert_success
    assert_output "1000"
}

@test "no path argument at all behaves exactly as before" {
    setup_paths
    run get-file-size-limit md "$TMP/paths.yml"
    assert_success
    assert_output "1000"
}

@test "a paths entry answers even when the extension has no limit" {
    setup_paths
    run get-file-size-limit inventory "$TMP/paths.yml" SPEC.md
    assert_success
    assert_output "200000"
}

@test "sections are respected: a key under paths never answers as an extension" {
    # Without section awareness a grep for '  md:' would match a path named
    # `md:` and vice versa -- a limit answering for the wrong file is worse
    # than no limit, because it reads as a deliberate exemption.
    cat >"$TMP/sections.yml" <<'YAML'
default: 100
paths:
  nix: 42
extensions:
  nix: 5000
YAML
    run get-file-size-limit nix "$TMP/sections.yml"
    assert_success
    assert_output "5000"
}

@test "a quoted path key is matched unquoted" {
    cat >"$TMP/quoted.yml" <<'YAML'
default: 100
paths:
  "docs/some file.md": 777
YAML
    run get-file-size-limit md "$TMP/quoted.yml" "docs/some file.md"
    assert_success
    assert_output "777"
}

@test "a trailing comment is not part of the limit" {
    cat >"$TMP/commented.yml" <<'YAML'
default: 100
paths:
  SPEC.md: 200000  # the whole-repo spec (see V-whatever)
YAML
    run get-file-size-limit md "$TMP/commented.yml" SPEC.md
    assert_success
    assert_output "200000"
}
