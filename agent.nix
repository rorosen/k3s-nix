{ config, ... }:
{
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

  # Place the demo SSH key on the node so it can decrypt sops-nix secrets, this is unsecure and
  # only done to keep the example simple
  environment.etc."ssh/ssh_host_ed25519_key" = {
    source = ./keys/agent_ed_25519;
    mode = "0400";
  };

  services.k3s = {
    enable = true;
    role = "agent";
    tokenFile = config.sops.secrets.k3s-token.path;
    # TODO: Replace with the IP of the server node!
    serverAddr = "https://192.168.1.2:6443";
  };
}
