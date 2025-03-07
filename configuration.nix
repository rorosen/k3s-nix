{ config, ... }:
{
  imports = builtins.attrValues (import ./modules);

  config = {
    system.stateVersion = "25.05";
    k3sNix = {
      grafana.enable = true;
      nodeExporter.enable = true;
      prometheus.enable = true;
    };
    services.k3s = {
      enable = true;
      images = [ config.services.k3s.package.airgapImages ];
    };
  };
}
