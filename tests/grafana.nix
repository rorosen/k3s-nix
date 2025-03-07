{
  name = "k3snix-grafana";
  passthru.platforms = [
    "x86_64-linux"
    "aarch64-linux"
  ];

  nodes.device =
    { config, pkgs, ... }:
    {
      k3sNix.grafana.enable = true;
      services.k3s = {
        enable = true;
        images = [ config.services.k3s.package.airgapImages ];
      };
    };

  testScript = # python
    ''
      import time

      start_all()

      with subtest("Wait until Grafana deployment is available"):
        device.wait_for_unit("k3s")
        device.wait_until_succeeds("kubectl wait deployment/grafana --for=condition=Available", timeout=90)

      time.sleep(1)
      # device.execute("kubectl proxy --address 127.0.0.1 --port=8001 >&2 &")
      # start kubectl proxy in background
      device.execute("kubectl port-forward svc/grafana 8080:80 >&2 &")
      device.wait_until_succeeds("nc -z 127.0.0.1 8080", timeout=5)

      # with subtest("Check Grafana health endpoint"):
      #   code = device.wait_until_succeeds('curl -s -o /dev/null -w "%{http_code}" localhost:3000/api/health', timeout=5)
      #   assert code == "200", f"Unexpected response code from /api/health: {code}"
    '';
}
