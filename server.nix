{ config, ... }:
{
  imports = [
    ./modules/grafana.nix
    ./modules/helm-hello-world.nix
    ./modules/node-exporter.nix
    ./modules/prometheus.nix
    ./modules/secrets.nix
  ];

  sops = {
    defaultSopsFile = ./secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets.k3s-token = { };
  };

  system.stateVersion = "25.05";
  networking.firewall = {
    allowedTCPPorts = [
      # SSH
      22
      # HTTP
      80
      # HTTPS
      443
      # Embedded registry (spegel)
      5001
      # Kubernetes API server
      6443
      # Node exporter
      9100
    ];
    # Flannel VXLAN
    allowedUDPPorts = [ 8472 ];
  };

  # Allow insecure SSH access just for the example
  security.pam.services.sshd.allowNullPassword = true;
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PermitEmptyPasswords = "yes";
    };

    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
    ];
  };

  environment.etc = {
    # Place the demo SSH key on the node so it can decrypt sops-nix secrets, this is unsecure and
    # only done to keep the example simple
    "ssh/ssh_host_ed25519_key" = {
      source = ./keys/server_ed_25519;
      mode = "0400";
    };
    # Enable the embedded registry mirror for all registries
    "rancher/k3s/registries.yaml".text = ''
      mirrors:
        "*":
    '';
  };

  services.k3s = {
    enable = true;
    tokenFile = config.sops.secrets.k3s-token.path;
    images = [ config.services.k3s.package.airgapImages ];
    extraFlags = [
      "--embedded-registry"
      "--disable metrics-server"
    ];
  };
}
