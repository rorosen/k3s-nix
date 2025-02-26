{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.k3sNix.nodeExporter;
  image = pkgs.dockerTools.pullImage {
    imageName = "quay.io/prometheus/node-exporter";
    imageDigest = "sha256:4032c6d5bfd752342c3e631c2f1de93ba6b86c41db6b167b9a35372c139e7706";
    hash = "sha256-DnQ5e6uhlC5YEFfSZVsAhbc+7tZqxSkwNPPmTJ/iL+c=";
    finalImageTag = "v1.8.2";
  };
in
{
  options.k3sNix.nodeExporter = {
    enable = lib.mkEnableOption "the Prometheus node exporter deployment";
    image = lib.mkOption {
      type = lib.types.package;
      default = image;
    };
  };

  config = lib.mkIf cfg.enable {
    services.k3s = {
      images = lib.mkIf config.k3sNix.airGap.enable [ cfg.image ];
      manifests = {
        node-exporter-daemonset.content = {
          apiVersion = "apps/v1";
          kind = "DaemonSet";
          metadata = {
            labels = {
              "app.kubernetes.io/component" = "exporter";
              "app.kubernetes.io/name" = "node-exporter";
            };
            name = "node-exporter";
          };
          spec = {
            selector = {
              matchLabels = {
                "app.kubernetes.io/component" = "exporter";
                "app.kubernetes.io/name" = "node-exporter";
              };
            };
            template = {
              metadata = {
                labels = {
                  "app.kubernetes.io/component" = "exporter";
                  "app.kubernetes.io/name" = "node-exporter";
                };
              };
              spec = {
                containers = [
                  {
                    name = "node-exporter";
                    image = with config.k3sNix.nodeExporter.image; "${imageName}:${imageTag}";
                    args = [
                      "--path.sysfs=/host/sys"
                      "--path.rootfs=/host/root"
                      "--no-collector.wifi"
                      "--no-collector.hwmon"
                      "--collector.filesystem.ignored-mount-points=^/(dev|proc|sys|var/lib/docker/.+|var/lib/kubelet/pods/.+)($|/)"
                      "--collector.netclass.ignored-devices=^(veth.*)$"
                    ];
                    ports = [
                      {
                        containerPort = 9100;
                      }
                    ];
                    volumeMounts = [
                      {
                        mountPath = "/host/sys";
                        mountPropagation = "HostToContainer";
                        name = "sys";
                        readOnly = true;
                      }
                      {
                        mountPath = "/host/root";
                        mountPropagation = "HostToContainer";
                        name = "root";
                        readOnly = true;
                      }
                    ];
                  }
                ];
                volumes = [
                  {
                    hostPath = {
                      path = "/sys";
                    };
                    name = "sys";
                  }
                  {
                    hostPath = {
                      path = "/";
                    };
                    name = "root";
                  }
                ];
              };
            };
          };
        };
        node-exporter-service.content = {
          kind = "Service";
          apiVersion = "v1";
          metadata = {
            name = "node-exporter";
          };
          spec = {
            selector = {
              "app.kubernetes.io/component" = "exporter";
              "app.kubernetes.io/name" = "node-exporter";
            };
            ports = [
              {
                name = "node-exporter";
                protocol = "TCP";
                port = 9100;
                targetPort = 9100;
              }
            ];
          };
        };
      };
    };
  };
}
