{
  pkgs,
  ...
}:
let
  image = pkgs.dockerTools.pullImage {
    imageName = "quay.io/prometheus/node-exporter";
    imageDigest = "sha256:337ff1d356b68d39cef853e8c6345de11ce7556bb34cda8bd205bcf2ed30b565";
    hash = "sha256-Us01w7MzoSLV6441UT+TqTZ7pyZubg1KpTi/qfXFQ/o=";
    finalImageTag = "v1.10.2";
    arch = "amd64";
  };
in
{
  services.k3s = {
    images = [ image ];
    manifests = {
      node-exporter-daemonset.content = {
        apiVersion = "apps/v1";
        kind = "DaemonSet";
        metadata = {
          name = "node-exporter";
          labels."app.kubernetes.io/name" = "node-exporter";
        };
        spec = {
          selector.matchLabels."app.kubernetes.io/name" = "node-exporter";
          template = {
            metadata.labels."app.kubernetes.io/name" = "node-exporter";
            spec = {
              containers = [
                {
                  name = "node-exporter";
                  image = "${image.imageName}:${image.imageTag}";
                  args = [
                    "--path.sysfs=/host/sys"
                    "--path.rootfs=/host/root"
                    "--no-collector.wifi"
                    "--no-collector.hwmon"
                    "--collector.filesystem.ignored-mount-points=^/(dev|proc|sys|var/lib/docker/.+|var/lib/kubelet/pods/.+)($|/)"
                    "--collector.netclass.ignored-devices=^(veth.*)$"
                  ];
                  ports = [ { containerPort = 9100; } ];
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
              hostNetwork = true;
              volumes = [
                {
                  hostPath.path = "/sys";
                  name = "sys";
                }
                {
                  hostPath.path = "/";
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
        metadata.name = "node-exporter";
        spec = {
          selector."app.kubernetes.io/name" = "node-exporter";
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
}
