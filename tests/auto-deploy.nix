{
  name = "k3snix-auto-deploy";
  passthru.platforms = [
    "x86_64-linux"
    "aarch64-linux"
  ];

  nodes = {
    server.imports = [ ../server.nix ];
    agent =
      {
        lib,
        nodes,
        ...
      }:
      {
        imports = [ ../agent.nix ];
        # Override the server address set in agent.nix
        services.k3s.serverAddr = lib.mkForce "https://${nodes.server.networking.primaryIPAddress}:6443";
      };
  };

  testScript = # python
    ''
      start_all()

      with subtest("K3s is running"):
        agent.wait_for_unit("k3s")
        server.wait_for_unit("k3s")

      with subtest("Deployments are ready"):
        server.wait_until_succeeds("kubectl rollout status daemonset node-exporter", timeout=90)
        server.wait_until_succeeds("kubectl rollout status deployment prometheus", timeout=90)
        server.wait_until_succeeds("kubectl rollout status deployment hello-world", timeout=90)
        server.wait_until_succeeds("kubectl -n kube-system rollout status deployment traefik", timeout=90)
        server.wait_until_succeeds("kubectl rollout status deployment grafana", timeout=90)

      with subtest("Deployments are healthy"):
        # node-exporter
        agent.succeed("nc -zv localhost 9100")
        server.succeed("nc -zv localhost 9100")
        # hello-world
        code = agent.succeed('curl -o /dev/null -s -w "%{http_code}" http://localhost/hello')
        assert code == "200", f"Unexpectd HTTP response code from /hello on agent node: {code}"
        code = server.succeed('curl -o /dev/null -s -w "%{http_code}" http://localhost/hello')
        assert code == "200", f"Unexpectd HTTP response code from /hello on server node: {code}"
        # grafana
        code = agent.succeed('curl -o /dev/null -s -w "%{http_code}" http://localhost/grafana/api/health')
        assert code == "200", f"Unexpectd HTTP response code from /grafana/api/health on agent node: {code}"
        code = server.succeed('curl -o /dev/null -s -w "%{http_code}" http://localhost/grafana/api/health')
        assert code == "200", f"Unexpectd HTTP response code from /grafana/api/health on server node: {code}"
    '';
}
