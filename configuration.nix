{ config, ... }:
{
  imports = [
    ./modules/grafana.nix
    ./modules/prometheus.nix
    ./modules/node-exporter.nix
    ./modules/secrets.nix
  ];

  config = {
    system.stateVersion = "25.05";
    services.k3s = {
      enable = true;
      images = [ config.services.k3s.package.airgapImages ];
    };
  };
}
