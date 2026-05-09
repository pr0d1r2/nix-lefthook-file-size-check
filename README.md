# nix-lefthook-file-size-check

[![CI](https://github.com/pr0d1r2/nix-lefthook-file-size-check/actions/workflows/ci.yml/badge.svg)](https://github.com/pr0d1r2/nix-lefthook-file-size-check/actions/workflows/ci.yml)

> This code is LLM-generated and validated through an automated integration process using [lefthook](https://github.com/evilmartians/lefthook) git hooks, [bats](https://github.com/bats-core/bats-core) unit tests, and GitHub Actions CI.

Lefthook-compatible file size limit checker, packaged as a Nix flake.

Enforces per-extension file size limits from a YAML config file. Exits 0 when no matching files are found or all files are within limits.

## Config file format

Create a YAML config (default path: `config/lefthook/file_size_limits.yml`):

```yaml
default: 4096
extensions:
  rb: 8192
  js: 10240
  Gemfile: 6144
```

The `default` key sets the fallback limit (bytes). Extension-specific limits go under `extensions`. Bare filenames (like `Gemfile`) are matched by full filename.

## Usage

### Option A: Lefthook remote (recommended)

Add to your `lefthook.yml` - no flake input needed, just the wrapper binary in your devShell:

```yaml
remotes:
  - git_url: https://github.com/pr0d1r2/nix-lefthook-file-size-check
    ref: main
    configs:
      - lefthook-remote.yml
```

### Option B: Flake input

Add as a flake input:

```nix
inputs.nix-lefthook-file-size-check = {
  url = "github:pr0d1r2/nix-lefthook-file-size-check";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

Add to your devShell:

```nix
nix-lefthook-file-size-check.packages.${pkgs.stdenv.hostPlatform.system}.default
```

Add to `lefthook.yml`:

```yaml
pre-commit:
  commands:
    file-size-check:
      run: timeout ${LEFTHOOK_FILE_SIZE_CHECK_TIMEOUT:-30} lefthook-file-size-check {staged_files}
```

### Configuring config path

Override the config file path via environment variable:

```bash
export LEFTHOOK_FILE_SIZE_CONFIG=.file-size-limits.yml
```

### Configuring timeout

The default timeout is 30 seconds. Override per-repo via environment variable:

```bash
export LEFTHOOK_FILE_SIZE_CHECK_TIMEOUT=60
```

## Development

The repo includes an `.envrc` for [direnv](https://direnv.net/) - entering the directory automatically loads the devShell with all dependencies:

```bash
cd nix-lefthook-file-size-check  # direnv loads the flake
bats tests/unit/
```

If not using direnv, enter the shell manually:

```bash
nix develop
bats tests/unit/
```

## License

MIT
