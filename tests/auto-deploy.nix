{
  name = "k3snix-auto-deploy";
  passthru.platforms = [
    "x86_64-linux"
    "aarch64-linux"
  ];

  nodes = {
    server =
      { config, pkgs, ... }:
      {
        imports = [
          ../modules/grafana.nix
          ../modules/prometheus.nix
          ../modules/node-exporter.nix
          ../modules/secrets.nix
          ../modules/helm-hello-world.nix
        ];
        networking.firewall.enable = false;
        environment.etc."ssh/ssh_host_ed25519_key" = {
          source = ../keys/demo_id_ed25519;
          mode = "0400";
        };
        services.k3s = {
          enable = true;
          token = "token";
          images = [ config.services.k3s.package.airgapImages ];
          extraFlags = [
            "--disable metrics-server"
            "--embedded-registry"
            "--node-ip ${config.networking.primaryIPAddress}"
          ];
        };
      };
    agent =
      {
        config,
        nodes,
        pkgs,
        ...
      }:
      {
        networking.firewall.enable = false;
        services.k3s = {
          enable = true;
          role = "agent";
          token = "token";
          serverAddr = "https://${nodes.server.networking.primaryIPAddress}:6443";
          extraFlags = [ "--node-ip ${config.networking.primaryIPAddress}" ];
        };
      };
  };

  testScript = # python
    ''
      start_all()
      server.wait_for_unit("k3s")
      agent.wait_for_unit("k3s")
      # TODO
    '';
}
