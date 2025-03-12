{ config, ... }:
{
  sops = {
    defaultSopsFile = ../secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets.grafana-admin-password = { };
    templates.grafanaAdmin = {
      content = builtins.toJSON {
        apiVersion = "v1";
        kind = "Secret";
        metadata.name = "grafana-admin";
        stringData.password = config.sops.placeholder.grafana-admin-password;
      };
      path = "/var/lib/rancher/k3s/server/manifests/grafana-admin-secret.json";
    };
  };
}
