{
  config,
  modulesPath,
  lib,
  pkgs,
  ...
}:
let
  isx86_64Linux = pkgs.stdenv.system == "x86_64-linux";
in
{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
    ./configuration.nix
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    autoResize = true;
    fsType = "ext4";
  };

  boot = {
    growPartition = true;
    kernelParams = [ "console=ttyS0" ];
    loader = {
      timeout = 0;
      grub = {
        efiSupport = lib.mkIf (!isx86_64Linux) (lib.mkDefault true);
        efiInstallAsRemovable = lib.mkIf (!isx86_64Linux) (lib.mkDefault true);
        device = lib.mkDefault (if isx86_64Linux then "/dev/vda" else "nodev");
      };
    };
  };

  system.build.qcow = import "${pkgs.path}/nixos/lib/make-disk-image.nix" {
    inherit lib config pkgs;
    inherit (config.virtualisation) diskSize;
    format = "qcow2";
    partitionTableType = "hybrid";
  };
}
