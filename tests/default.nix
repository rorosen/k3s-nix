{ pkgs, sops-nix }:
{
  autoDeploy = pkgs.testers.runNixOSTest {
    imports = [ ./auto-deploy.nix ];
    interactive.defaults = import ./interactive.nix;
    globalTimeout = 8 * 60; # 8 minutes
    extraBaseModules = {
      imports = [
        sops-nix.nixosModules.sops
        {
          # our deployments need more resources than the default
          virtualisation.cores = 2;
          virtualisation.memorySize = 2048;
          virtualisation.diskSize = 4096;
          # make sure the test also runs offline in interactive mode
          virtualisation.restrictNetwork = true;
          # The interface selection logic of flannel would normally use eth0, as the nixos
          # testing driver sets a default route via dev eth0. However, in test setups we
          # have to use eth1 on all nodes for inter-node communication.
          services.k3s.extraFlags = [ "--flannel-iface eth1" ];
        }
      ];
    };
  };
}
