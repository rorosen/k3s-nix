# Uses the k3s Helm controller to deploy a Helm chart.
# See https://docs.k3s.io/helm#using-the-helm-controller for further information.
{ pkgs, ... }:
let
  image = pkgs.dockerTools.pullImage {
    imageName = "nginx";
    imageDigest = "sha256:4ff102c5d78d254a6f0da062b3cf39eaf07f01eec0927fd21e219d0af8bc0591";
    hash = "sha256-Fh9hWQWgY4g+Cu/0iER4cXAMvCc0JNiDwGCPa+V/FvA=";
    finalImageTag = "1.27.4-alpine";
  };
  helmChart =
    pkgs.runCommand "helm-hello-world"
      {
        nativeBuildInputs = with pkgs; [
          kubernetes-helm
          cacert
        ];
        outputHashAlgo = "sha256";
        outputHash = "sha256-U2XjNEWE82/Q3KbBvZLckXbtjsXugUbK6KdqT5kCccM=";
      }
      ''
        export HOME="$PWD"

        helm repo add examples https://helm.github.io/examples
        helm pull examples/hello-world --version 0.1.0
        mv ./*.tgz $out
      '';
in
{
  services.k3s = {
    images = [ image ];
    charts.hello-world = helmChart;
    manifests = {
      hello-world.content = {
        apiVersion = "helm.cattle.io/v1";
        kind = "HelmChart";
        metadata.name = "hello-world";
        spec = {
          # the chart name (hello-world) has to match the key that is used in services.k3s.charts
          chart = "https://%{KUBERNETES_API}%/static/charts/hello-world.tgz";
          # configure the chart values like you would do in values.yaml
          valuesContent = ''
            image:
              repository: ${image.imageName}
              tag: ${image.imageTag}

            serviceAccount:
              create: false
          '';
        };
      };
      hello-world-ingress.content = {
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
            ({
              http = {
                paths = [
                  {
                    path = "/hello";
                    pathType = "Exact";
                    backend = {
                      service = {
                        name = "hello-world";
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
      hello-world-strip-prefix.content = {
        apiVersion = "traefik.io/v1alpha1";
        kind = "Middleware";
        metadata.name = "hello-world-strip-prefix";
        spec = {
          stripPrefix.prefixes = [ "/hello" ];
        };
      };
    };
  };
}
