{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.k3sNix.prometheus;
  image = pkgs.dockerTools.pullImage {
    imageName = "quay.io/prometheus/prometheus";
    imageDigest = "sha256:6559acbd5d770b15bb3c954629ce190ac3cbbdb2b7f1c30f0385c4e05104e218";
    hash = "sha256-3A9E+joDExH1JL3QsEWTse8EqaIjjzlKhgsU5U2LWiQ=";
    finalImageTag = "v3.1.0";
  };
in
{
  options.k3sNix.prometheus = {
    enable = lib.mkEnableOption "the Prometheus deployment";
    image = lib.mkOption {
      type = lib.types.package;
      default = image;
      description = "The Prometheus container image to use";
    };
  };

  config = lib.mkIf cfg.enable {
    services.k3s = {
      images = [ cfg.image ];
      manifests = {
        prometheus-cluster-role.content = {
          apiVersion = "rbac.authorization.k8s.io/v1";
          kind = "ClusterRole";
          metadata = {
            name = "prometheus";
          };
          rules = [
            {
              apiGroups = [
                ""
              ];
              resources = [
                "nodes"
                "nodes/proxy"
                "services"
                "endpoints"
                "pods"
              ];
              verbs = [
                "get"
                "list"
                "watch"
              ];
            }
            {
              apiGroups = [
                "extensions"
              ];
              resources = [
                "ingresses"
              ];
              verbs = [
                "get"
                "list"
                "watch"
              ];
            }
            {
              nonResourceURLs = [
                "/metrics"
              ];
              verbs = [
                "get"
              ];
            }
          ];
        };
        prometheus-cluster-role-binding.content = {
          apiVersion = "rbac.authorization.k8s.io/v1";
          kind = "ClusterRoleBinding";
          metadata = {
            name = "prometheus";
          };
          roleRef = {
            apiGroup = "rbac.authorization.k8s.io";
            kind = "ClusterRole";
            name = "prometheus";
          };
          subjects = [
            {
              kind = "ServiceAccount";
              name = "prometheus";
              namespace = "default";
            }
          ];
        };
        prometheus-serviceaccount.content = {
          apiVersion = "v1";
          kind = "ServiceAccount";
          metadata.name = "prometheus";
        };
        prometheus-config-map.content = {
          apiVersion = "v1";
          kind = "ConfigMap";
          metadata = {
            name = "prometheus-server-conf";
            labels = {
              name = "prometheus-server-conf";
            };
          };
          data."prometheus.yaml" = ''
            global:
              scrape_interval: 5s
              evaluation_interval: 5s
            scrape_configs:
              - job_name: 'node-exporter'
                kubernetes_sd_configs:
                  - role: endpoints
                relabel_configs:
                - source_labels: [__meta_kubernetes_endpoints_name]
                  regex: 'node-exporter'
                  action: keep
              - job_name: 'kubernetes-apiservers'
                kubernetes_sd_configs:
                - role: endpoints
                scheme: https
                tls_config:
                  ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
                bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
                relabel_configs:
                - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
                  action: keep
                  regex: default;kubernetes;https
              - job_name: 'kubernetes-nodes'
                scheme: https
                tls_config:
                  ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
                bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
                kubernetes_sd_configs:
                - role: node
                relabel_configs:
                - action: labelmap
                  regex: __meta_kubernetes_node_label_(.+)
                - target_label: __address__
                  replacement: kubernetes.default.svc:443
                - source_labels: [__meta_kubernetes_node_name]
                  regex: (.+)
                  target_label: __metrics_path__
                  replacement: /api/v1/nodes/''${1}/proxy/metrics
              - job_name: 'kubernetes-cadvisor'
                scheme: https
                tls_config:
                  ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
                bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
                kubernetes_sd_configs:
                - role: node
                relabel_configs:
                - action: labelmap
                  regex: __meta_kubernetes_node_label_(.+)
                - target_label: __address__
                  replacement: kubernetes.default.svc:443
                - source_labels: [__meta_kubernetes_node_name]
                  regex: (.+)
                  target_label: __metrics_path__
                  replacement: /api/v1/nodes/''${1}/proxy/metrics/cadvisor
          '';
        };
        prometheus-deployment.content = {
          apiVersion = "apps/v1";
          kind = "Deployment";
          metadata = {
            name = "prometheus";
            labels = {
              app = "prometheus-server";
            };
          };
          spec = {
            replicas = 1;
            selector = {
              matchLabels = {
                app = "prometheus-server";
              };
            };
            template = {
              metadata = {
                labels = {
                  app = "prometheus-server";
                };
              };
              spec = {
                containers = [
                  {
                    name = "prometheus";
                    image = with cfg.image; "${imageName}:${imageTag}";
                    args = [
                      "--config.file=/etc/prometheus/prometheus.yaml"
                      "--storage.tsdb.path=/prometheus/"
                    ];
                    ports = [
                      {
                        containerPort = 9090;
                      }
                    ];
                    volumeMounts = [
                      {
                        mountPath = "/prometheus";
                        name = "storage";
                      }
                      {
                        mountPath = "/etc/prometheus";
                        name = "config";
                        readOnly = true;
                      }
                    ];
                  }
                ];
                serviceAccountName = "prometheus";
                volumes = [
                  {
                    name = "storage";
                    persistentVolumeClaim.claimName = "prometheus";
                  }
                  {
                    name = "config";
                    configMap = {
                      name = "prometheus-server-conf";
                    };
                  }
                ];
              };
            };
          };
        };
        prometheus-pvc.content = {
          apiVersion = "v1";
          kind = "PersistentVolumeClaim";
          metadata.name = "prometheus";
          spec = {
            accessModes = [ "ReadWriteOnce" ];
            storageClassName = "local-path";
            resources.requests.storage = "5Gi";
          };
        };
        prometheus-service.content = {
          apiVersion = "v1";
          kind = "Service";
          metadata = {
            name = "prometheus";
          };
          spec = {
            selector = {
              app = "prometheus-server";
            };
            ports = [
              {
                name = "http";
                protocol = "TCP";
                port = 80;
                targetPort = 9090;
              }
            ];
          };
        };
      };
    };
  };
}
