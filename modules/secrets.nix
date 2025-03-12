{ config, ... }:
let
  mkSecretTemplate =
    {
      name,
      namespace ? "default",
      stringData,
    }:
    builtins.toJSON {
      apiVersion = "v1";
      kind = "Secret";
      metadata = { inherit name namespace; };
      inherit stringData;
    };
in
{
  sops = {
    defaultSopsFile = ../secrets.yaml;
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
    secrets.grafana-admin-password = { };
    templates.grafanaAdmin = {
      content = mkSecretTemplate {
        name = "grafana-admin";
        stringData.password = config.sops.placeholder.grafana-admin-password;
      };
      path = "/var/lib/rancher/k3s/server/manifests/grafana-admin-secret.json";
    };
  };
}
