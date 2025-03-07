{ pkgs, nixosModules }:
let
  runTest =
    module:
    pkgs.testers.runNixOSTest {
      imports = [ module ];
      interactive.defaults = import ./interactive.nix;
      globalTimeout = 8 * 60; # 8 minutes
      extraBaseModules = {
        imports = [
          {
            virtualisation.memorySize = 2048;
            virtualisation.diskSize = 4096;
            virtualisation.restrictNetwork = true;
          }
        ] ++ (builtins.attrValues nixosModules);
      };
    };
in
{
  grafana = runTest ./grafana.nix;
  multiNode = runTest ./multi-node.nix;
}
