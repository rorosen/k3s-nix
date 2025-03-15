{ pkgs, sops-nix }:
{
  autoDeploy = pkgs.testers.runNixOSTest {
    imports = [ ./auto-deploy.nix ];
    interactive.defaults = import ./interactive.nix;
    globalTimeout = 8 * 60; # 8 minutes
    extraBaseModules = {
      imports = [
        sops-nix.nixosModules.sops
        (
          { config, ... }:
          {
            # The cluster needs more resources than the default
            virtualisation.cores = 2;
            virtualisation.memorySize = 2048;
            virtualisation.diskSize = 4096;
            # Run tests always offline
            virtualisation.restrictNetwork = true;
            services.k3s.extraFlags = [
              # The interface selection logic of flannel would normally use eth0, as the nixos
              # testing driver sets a default route via dev eth0. However, in test setups we
              # have to use eth1 on all nodes for inter-node communication.
              "--flannel-iface eth1"
              # Use the IP an eth1 as node IP
              "--node-ip ${config.networking.primaryIPAddress}"
            ];
            # Enable the embedded registry mirror for all registries.
            environment.etc."rancher/k3s/registries.yaml".text = ''
              mirrors:
                "*":
            '';
          }
        )
      ];
    };
  };
}
