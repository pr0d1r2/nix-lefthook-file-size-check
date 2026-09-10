{
  description = "Lefthook-compatible file size limit checker, packaged as a Nix flake";

  nixConfig = {
    extra-substituters = [ "https://pr0d1r2.cachix.org" ];
    extra-trusted-public-keys = [ "pr0d1r2.cachix.org-1:NfWjbhgAj41byXhCKiaE+av3Vnphm1fTezHXEGsiQIM=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nix-dev-shell-agentic = {
      url = "github:pr0d1r2/nix-dev-shell-agentic";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-lefthook-unicode-lint = {
      url = "github:pr0d1r2/nix-lefthook-unicode-lint";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # lefthook.yml pulls the bats-unit remote config, whose command is the
    # wrapper `lefthook-bats-unit` rather than a bare `bats` invocation. The CI
    # shell runs with --ignore-environment, so a wrapper nothing here provides
    # is simply absent: `timeout: failed to run command 'lefthook-bats-unit'`,
    # reported by lefthook as a FAILED CHECK. A check that consumes a config
    # must also supply the binary that config names.
    nix-lefthook-bats-unit = {
      url = "github:pr0d1r2/nix-lefthook-bats-unit";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nix-dev-shell-agentic,
      nix-lefthook-bats-unit,
      ...
    }@inputs:
    let
      supportedSystems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems =
        f: nixpkgs.lib.genAttrs supportedSystems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: {
        get-file-size-limit = pkgs.writeShellApplication {
          name = "get-file-size-limit";
          runtimeInputs = [
            pkgs.gawk
            pkgs.gnugrep
          ];
          text = builtins.readFile ./get-file-size-limit.sh;
        };
        default = pkgs.writeShellApplication {
          name = "lefthook-file-size-check";
          runtimeInputs = [
            pkgs.gawk
            pkgs.gnugrep
            pkgs.coreutils
            self.packages.${pkgs.stdenv.hostPlatform.system}.get-file-size-limit
          ];
          text = builtins.readFile ./lefthook-file-size-check.sh;
        };
      });

      devShells = forAllSystems (
        pkgs:
        let
          inherit (pkgs.stdenv.hostPlatform) system;
          localBin = "${self.packages.${system}.default}/bin:${
            self.packages.${system}.get-file-size-limit
          }/bin";
          shells = nix-dev-shell-agentic.lib.mkShells {
            inherit pkgs inputs;
            ciPackages = [
              self.packages.${system}.get-file-size-limit
              self.packages.${system}.default
              nix-lefthook-bats-unit.packages.${system}.default
            ];
            shellHook =
              builtins.replaceStrings [ "@BATS_LIB_PATH@" "@LOCAL_BIN@" ] [ "${shells.batsWithLibs}" localBin ]
                (builtins.readFile ./dev.sh);
          };
        in
        # mkShells applies `shellHook` to the interactive shell only, and CI runs
        # `.#ci`. Without this the CI shell keeps the shared shell's PINNED copy
        # of this tool ahead of the one just built, so CI tests the release.
        shells
        // {
          ci = shells.ci.overrideAttrs (old: {
            shellHook =
              (old.shellHook or "")
              + builtins.replaceStrings [ "@LOCAL_BIN@" ] [ localBin ] (builtins.readFile ./local-bin.sh);
          });
        }
      );
    };
}
