{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:
let
  cfg = config.k3sNix;
  isx86_64Linux = pkgs.stdenv.system == "x86_64-linux";
in
{
  imports = [ "${modulesPath}/profiles/qemu-guest.nix" ] ++ (builtins.attrValues (import ./modules));

  options.k3sNix.airGap.enable = lib.mkEnableOption "an air-gapped configuration";

  config = {
    system.stateVersion = "25.05";
    k3sNix = {
      airGap.enable = true;
      grafana.enable = true;
      nodeExporter.enable = true;
      prometheus.enable = true;
    };
    services.k3s = {
      enable = true;
      images = lib.mkIf cfg.airGap.enable [ config.services.k3s.package.airgapImages ];
    };
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
  };
}
