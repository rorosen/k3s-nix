{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.k3sNix.grafana;
  # toYaml = attrs: with builtins; readFile ((pkgs.formats.yaml { }).generate "useless.yaml" attrs);
  image = pkgs.dockerTools.pullImage {
    imageName = "docker.io/grafana/grafana";
    imageDigest = "sha256:5781759b3d27734d4d548fcbaf60b1180dbf4290e708f01f292faa6ae764c5e6";
    sha256 = "sha256-iGjaomEOMNgixw8iJC0c4HWhUBXcKZcsnV1XfB+ctMs=";
    finalImageTag = "11.5.1";
  };
  prometheusServiceCfg = config.services.k3s.manifests.prometheus-service.content;
  prometheusServiceName = prometheusServiceCfg.metadata.name;
  prometheusServicePort = toString (builtins.elemAt prometheusServiceCfg.spec.ports 0).port;
  prometheusDatasource = {
    apiVersion = 1;
    datasources = [
      {
        access = "proxy";
        editable = true;
        name = "prometheus";
        orgId = 1;
        type = "prometheus";
        url = "http://${prometheusServiceName}.default.svc:${prometheusServicePort}";
        version = 1;
      }
    ];
  };
  datasources = lib.optionalAttrs config.k3sNix.prometheus.enable {
    "prometheus.yaml" = builtins.toJSON prometheusDatasource;
  };
  dashboardProvider = {
    apiVersion = 1;
    providers = [
      {
        name = "demo-dashboards";
        disableDeletion = true;
        allowUiUpdates = false;
        options.path = "/var/lib/grafana/dashboards";
      }
    ];
  };
  nodeExporterDashboard = pkgs.fetchurl {
    url = "https://grafana.com/api/dashboards/1860/revisions/37/download";
    hash = "sha256-1DE1aaanRHHeCOMWDGdOS1wBXxOF84UXAjJzT5Ek6mM=";
  };
  dashboards = lib.optionalAttrs config.k3sNix.nodeExporter.enable {
    "node-exporter.json" = builtins.readFile nodeExporterDashboard;
  };
in
{
  options.k3sNix.grafana = {
    enable = lib.mkEnableOption "the Grafana deployment";
    image = lib.mkOption {
      type = lib.types.package;
      default = image;
      description = "The Grafana container image to use";
    };
  };

  config = lib.mkIf cfg.enable {
    services.k3s = {
      images = [ cfg.image ];
      manifests = {
        grafana-deployment.content = {
          apiVersion = "apps/v1";
          kind = "Deployment";
          metadata = {
            name = "grafana";
          };
          spec = {
            replicas = 1;
            selector = {
              matchLabels = {
                app = "grafana";
              };
            };
            template = {
              metadata = {
                name = "grafana";
                labels = {
                  app = "grafana";
                };
              };
              spec = {
                containers = [
                  {
                    name = "grafana";
                    image = with cfg.image; "${imageName}:${imageTag}";
                    ports = [
                      {
                        containerPort = 3000;
                      }
                    ];
                    volumeMounts = [
                      {
                        mountPath = "/var/lib/grafana";
                        name = "storage";
                      }
                      {
                        mountPath = "/etc/grafana/provisioning/datasources";
                        name = "datasources";
                        readOnly = true;
                      }
                      {
                        mountPath = "/etc/grafana/provisioning/dashboards";
                        name = "dashboards-provider";
                        readOnly = true;
                      }
                      {
                        mountPath = "/var/lib/grafana/dashboards";
                        name = "dashboards";
                        readOnly = true;
                      }
                    ];
                  }
                ];
                volumes = [
                  {
                    name = "storage";
                    persistentVolumeClaim.claimName = "grafana";
                  }
                  {
                    name = "datasources";
                    configMap = {
                      name = "grafana-datasources";
                    };
                  }
                  {
                    name = "dashboards-provider";
                    configMap = {
                      name = "grafana-dashboards-provider";
                    };
                  }
                  {
                    name = "dashboards";
                    configMap = {
                      name = "grafana-dashboards";
                    };
                  }
                ];
              };
            };
          };
        };
        grafana-pvc.content = {
          apiVersion = "v1";
          kind = "PersistentVolumeClaim";
          metadata.name = "grafana";
          spec = {
            accessModes = [ "ReadWriteOnce" ];
            storageClassName = "local-path";
            resources.requests.storage = "1Gi";
          };
        };
        grafana-datasources.content = {
          apiVersion = "v1";
          kind = "ConfigMap";
          metadata = {
            name = "grafana-datasources";
          };
          data = datasources;
        };
        grafana-dashboards-provider.content = {
          apiVersion = "v1";
          kind = "ConfigMap";
          metadata = {
            name = "grafana-dashboards-provider";
          };
          data."demo-dashboards.yaml" = builtins.toJSON dashboardProvider;
        };
        grafana-dashboards.content = {
          apiVersion = "v1";
          kind = "ConfigMap";
          metadata = {
            name = "grafana-dashboards";
          };
          data = dashboards;
        };
        grafana-service.content = {
          apiVersion = "v1";
          kind = "Service";
          metadata = {
            name = "grafana";
          };
          spec = {
            selector = {
              app = "grafana";
            };
            ports = [
              {
                port = 80;
                targetPort = 3000;
              }
            ];
          };
        };
      };
    };
  };
}
