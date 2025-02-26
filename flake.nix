{
  description = "Auto deploying k3s configuration in pure Nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs =
    inputs@{ self, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      flake = {
        nixosModules = import ./modules;
      };
      perSystem =
        { pkgs, system, ... }:
        {
          packages.qcow2 =
            let
              eval = import "${pkgs.path}/nixos/lib/eval-config.nix" {
                inherit pkgs system;
                modules = [ ./configuration.nix ];
              };
            in
            eval.config.system.build.qcow;
          checks = { };
        };
    };

}
