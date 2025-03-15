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
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      sops-nix,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      perSystem =
        { pkgs, system, ... }:
        {
          packages =
            let
              mkNode =
                module:
                import "${pkgs.path}/nixos/lib/eval-config.nix" {
                  inherit pkgs system;
                  modules = [
                    sops-nix.nixosModules.sops
                    ./qemu.nix
                    module
                  ];
                  specialArgs = { inherit inputs; };
                };
            in
            {
              agent = (mkNode ./agent.nix).config.system.build.qcow;
              server = (mkNode ./server.nix).config.system.build.qcow;

            };
          checks = import ./tests { inherit pkgs sops-nix; };
          devShells.default = pkgs.mkShell {
            packages = [ pkgs.sops ];
            SOPS_AGE_KEY_FILE = "./keys/age.txt";
          };
        };
    };
}
