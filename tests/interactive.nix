# Allow for a uniform debugging experience by enabling ssh + port forwarding in interactive mode.
# Access test nodes via `ssh root@localhost -p x0022` where x is the number of the node in the test.
{ config, ... }:
{
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PermitEmptyPasswords = "yes";
    };
  };
  security.pam.services.sshd.allowNullPassword = true;
  virtualisation.forwardPorts = [
    {
      from = "host";
      host.port = 22 + 10000 * config.virtualisation.test.nodeNumber;
      guest.port = 22;
    }
    {
      from = "host";
      host.port = 80 + 10000 * config.virtualisation.test.nodeNumber;
      guest.port = 80;
    }
    {
      from = "host";
      host.port = 443 + 10000 * config.virtualisation.test.nodeNumber;
      guest.port = 443;
    }
    {
      from = "host";
      host.port = 6443 + 10000 * config.virtualisation.test.nodeNumber;
      guest.port = 6443;
    }
  ];
}
