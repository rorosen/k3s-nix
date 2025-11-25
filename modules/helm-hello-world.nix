# Uses the k3s Helm controller to deploy a Helm chart.
# See https://docs.k3s.io/helm#using-the-helm-controller for further information.
{ pkgs, ... }:
let
  image = pkgs.dockerTools.pullImage {
    imageName = "nginx";
    imageDigest = "sha256:b3c656d55d7ad751196f21b7fd2e8d4da9cb430e32f646adcf92441b72f82b14";
    hash = "sha256-qrQIBp2EbKw3Aicu424rbu26v2T1LZgHVQ+hJKKZQxE=";
    finalImageTag = "1.29.3-alpine";
    arch = "amd64";
  };
in
{
  services.k3s = {
    images = [ image ];
    autoDeployCharts.hello-world = {
      name = "hello-world";
      repo = "https://helm.github.io/examples";
      version = "0.1.0";
      hash = "sha256-U2XjNEWE82/Q3KbBvZLckXbtjsXugUbK6KdqT5kCccM=";
      # configure the chart values like you would do in values.yaml
      values = {
        image = {
          repository = image.imageName;
          tag = image.imageTag;
        };
        serviceAccount.create = false;
      };
      # Deploy additional resources that are not part of the Helm chart. This is especially useful
      # for CRDs that shouldn't be managed by Helm.
      extraDeploy = [
        {
          apiVersion = "networking.k8s.io/v1";
          kind = "Ingress";
          metadata = {
            name = "hello-world";
            annotations."traefik.ingress.kubernetes.io/router.middlewares" =
              "default-hello-world-strip-prefix@kubernetescrd";
          };
          spec = {
            ingressClassName = "traefik";
            rules = [
              {
                http.paths = [
                  {
                    path = "/hello";
                    pathType = "Exact";
                    backend.service = {
                      name = "hello-world";
                      port.number = 80;
                    };
                  }
                ];
              }
            ];
          };
        }
        {
          apiVersion = "traefik.io/v1alpha1";
          kind = "Middleware";
          metadata.name = "hello-world-strip-prefix";
          spec.stripPrefix.prefixes = [ "/hello" ];
        }
      ];
    };
  };
}
