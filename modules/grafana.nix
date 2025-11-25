{
  config,
  pkgs,
  ...
}:
let
  image = pkgs.dockerTools.pullImage {
    imageName = "docker.io/grafana/grafana";
    imageDigest = "sha256:408c41e88a0e3a7af1297cdd0b2b2ac19cc16f094d6a6eaea3bdf63ef67df75c";
    hash = "sha256-47mFJYg0lnVGx+eJFyPNFiOsZcTMeJpFpjx+MJIVZPo=";
    finalImageTag = "12.4.0-19291686361";
    arch = "amd64";
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
    url = "https://grafana.com/api/dashboards/1860/revisions/42/download";
    hash = "sha256-pNgn6xgZBEu6LW0lc0cXX2gRkQ8lg/rer34SPE3yEl4=";
  };
  k8sApiServerDashboard = pkgs.fetchurl {
    url = "https://grafana.com/api/dashboards/15761/revisions/20/download";
    hash = "sha256-u1gU0kSYM9bRwb7CQYyN1iMtGyCb/Y+OHKUwB8hxHHI=";
  };
  dashboards = {
    "node-exporter.json" = builtins.readFile nodeExporterDashboard;
    "k8s-system-api-server.json" = builtins.readFile k8sApiServerDashboard;
  };
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
          labels."app.kubernetes.io/name" = "grafana";
        };
        spec = {
          replicas = 1;
          selector.matchLabels."app.kubernetes.io/name" = "grafana";
          template = {
            metadata.labels."app.kubernetes.io/name" = "grafana";
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
                      name = "GF_SERVER_ROOT_URL";
                      value = "/grafana";
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
                  ports = [ { containerPort = 3000; } ];
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
                  readinessProbe.httpGet = {
                    path = "/api/health";
                    port = 3000;
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
                  configMap.name = "grafana-datasources";
                }
                {
                  name = "dashboards-provider";
                  configMap.name = "grafana-dashboards-provider";
                }
                {
                  name = "dashboards";
                  configMap.name = "grafana-dashboards";
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
          labels."app.kubernetes.io/name" = "grafana";
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
          labels."app.kubernetes.io/name" = "grafana";
        };
        data = datasources;
      };
      grafana-dashboards-provider.content = {
        apiVersion = "v1";
        kind = "ConfigMap";
        metadata = {
          name = "grafana-dashboards-provider";
          labels."app.kubernetes.io/name" = "grafana";
        };
        data."demo-dashboards.yaml" = builtins.toJSON dashboardProvider;
      };
      grafana-dashboards.content = {
        apiVersion = "v1";
        kind = "ConfigMap";
        metadata = {
          name = "grafana-dashboards";
          labels."app.kubernetes.io/name" = "grafana";
        };
        data = dashboards;
      };
      grafana-service.content = {
        apiVersion = "v1";
        kind = "Service";
        metadata = {
          name = "grafana";
          labels."app.kubernetes.io/name" = "grafana";
        };
        spec = {
          selector."app.kubernetes.io/name" = "grafana";
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
          annotations."traefik.ingress.kubernetes.io/router.middlewares" =
            "default-grafana-strip-prefix@kubernetescrd";
        };
        spec = {
          ingressClassName = "traefik";
          rules = [
            ({
              http = {
                paths = [
                  {
                    path = "/grafana";
                    pathType = "Prefix";
                    backend = {
                      service = {
                        name = "grafana";
                        port.number = 80;
                      };
                    };
                  }
                ];
              };
            })
          ];
        };
      };
      grafana-strip-prefix.content = {
        apiVersion = "traefik.io/v1alpha1";
        kind = "Middleware";
        metadata.name = "grafana-strip-prefix";
        spec = {
          stripPrefix.prefixes = [ "/grafana" ];
        };
      };
    };
  };
}
