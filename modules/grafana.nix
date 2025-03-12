{
  config,
  pkgs,
  ...
}:
let
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
  datasources."prometheus.yaml" = builtins.toJSON prometheusDatasource;
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
  dashboards."node-exporter.json" = builtins.readFile nodeExporterDashboard;
in
{
  services.k3s = {
    images = [ image ];
    manifests = {
      grafana-deployment.content = {
        apiVersion = "apps/v1";
        kind = "Deployment";
        metadata = {
          name = "grafana";
          namespace = "default";
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
              namespace = "default";
              labels = {
                app = "grafana";
              };
            };
            spec = {
              containers = [
                {
                  name = "grafana";
                  image = "${image.imageName}:${image.imageTag}";
                  env = [
                    {
                      name = "GF_ANALYTICS_CHECK_FOR_UPDATES";
                      value = "false";
                    }
                    {
                      name = "GF_ANALYTICS_CHECK_FOR_PLUGIN_UPDATES";
                      value = "false";
                    }
                    {
                      name = "GF_ANALYTICS_REPORTING_ENABLED";
                      value = "false";
                    }
                    {
                      name = "GF_PLUGINS_PLUGIN_ADMIN_ENABLED";
                      value = "false";
                    }
                    {
                      name = "GF_PLUGINS_PUBLIC_KEY_RETRIEVAL_DISABLED";
                      value = "true";
                    }
                    {
                      name = "GF_SECURITY_ADMIN_USER";
                      value = "admin";
                    }
                    {
                      name = "GF_SECURITY_ADMIN_PASSWORD";
                      valueFrom.secretKeyRef = {
                        name = "grafana-admin";
                        key = "password";
                      };
                    }
                  ];
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
                  livenessProbe = {
                    httpGet = {
                      path = "/api/health";
                      port = 3000;
                    };
                    timeoutSeconds = 30;
                    failureThreshold = 1;
                  };
                  startupProbe = {
                    httpGet = {
                      path = "/api/health";
                      port = 3000;
                    };
                    timeoutSeconds = 30;
                    failureThreshold = 10;
                  };
                  readinessProbe = {
                    httpGet = {
                      path = "/api/health";
                      port = 3000;
                    };
                  };
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
        metadata = {
          name = "grafana";
          namespace = "default";
        };
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
          namespace = "default";
        };
        data = datasources;
      };
      grafana-dashboards-provider.content = {
        apiVersion = "v1";
        kind = "ConfigMap";
        metadata = {
          name = "grafana-dashboards-provider";
          namespace = "default";
        };
        data."demo-dashboards.yaml" = builtins.toJSON dashboardProvider;
      };
      grafana-dashboards.content = {
        apiVersion = "v1";
        kind = "ConfigMap";
        metadata = {
          name = "grafana-dashboards";
          namespace = "default";
        };
        data = dashboards;
      };
      grafana-service.content = {
        apiVersion = "v1";
        kind = "Service";
        metadata = {
          name = "grafana";
          namespace = "default";
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
      grafana-ingress.content = {
        apiVersion = "networking.k8s.io/v1";
        kind = "Ingress";
        metadata = {
          name = "grafana";
          namespace = "default";
        };
        spec = {
          ingressClassName = "traefik";
          rules = [
            ({
              http = {
                paths = [
                  {
                    path = "/";
                    pathType = "Prefix";
                    backend = {
                      service = {
                        inherit (config.services.k3s.manifests.grafana-service.content.metadata) name;
                        port = {
                          number = 80;
                        };
                      };
                    };
                  }
                ];
              };
            })
          ];
        };
      };
    };
  };
}
