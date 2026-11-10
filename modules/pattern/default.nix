# Pattern Labs layer, on top of core, dev and dev-cloud. Work hosts
# additionally import ./profiles/work.nix.
{ ... }:

{
  imports = [
    ./cli.nix
    ./compliance.nix
  ];
}
