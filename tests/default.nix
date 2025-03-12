{ pkgs, sops-nix }:
let
  manifests = pkgs.testers.runNixOSTest {
    imports = [ ./manifests.nix ];
    interactive.defaults = import ./interactive.nix;
    globalTimeout = 8 * 60; # 8 minutes
    extraBaseModules = {
      imports = [
        sops-nix.nixosModules.sops
        {
          virtualisation.cores = 2;
          virtualisation.memorySize = 2048;
          virtualisation.diskSize = 4096;
          virtualisation.restrictNetwork = true;
          services.k3s.extraFlags = [
            # The interface selection logic of flannel would normally use eth0, as the nixos
            # testing driver sets a default route via dev eth0. However, in test setups we
            # have to use eth1 on all nodes for inter-node communication.
            "--flannel-iface eth1"
          ];
        }
      ];
    };
  };
in
{
  inherit manifests;
}
