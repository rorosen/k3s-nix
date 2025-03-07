{
  name = "k3snix-multi-node";
  passthru.platforms = [
    "x86_64-linux"
    "aarch64-linux"
  ];

  nodes = {
    server =
      { config, ... }:
      {
        k3sNix = {
          grafana.enable = true;
          nodeExporter.enable = true;
          prometheus.enable = true;
        };
        networking.firewall.enable = false;
        services.k3s = {
          enable = true;
          token = "token";
          images = [ config.services.k3s.package.airgapImages ];
          extraFlags = [
            "--disable local-storage"
            "--disable metrics-server"
            "--node-ip ${config.networking.primaryIPAddress}"
            # The interface selection logic of flannel would normally use eth0, as the nixos
            # testing driver sets a default route via dev eth0. However, in test setups we
            # have to use eth1 for inter-node communication.
            "--flannel-iface eth1"
          ];
        };
      };
    agent =
      { config, nodes, ... }:
      {
        networking.firewall.enable = false;
        services.k3s = {
          enable = true;
          role = "agent";
          token = "token";
          serverAddr = "https://${nodes.server.networking.primaryIPAddress}:6443";
          extraFlags = [
            "--node-ip ${config.networking.primaryIPAddress}"
            "--flannel-iface eth1"
          ];
        };
      };
  };

  testScript = # python
    ''
      start_all()
      server.wait_for_unit("k3s")
      agent.wait_for_unit("k3s")
    '';
}
