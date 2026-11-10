{ pkgs, ... }:

{
  # nix-ld provides a dynamic linker stub so that binaries downloaded
  # by bazelisk (and other tools) can run on NixOS.
  programs.nix-ld.enable = true;

  environment.systemPackages = with pkgs; [
    bazelisk
  ];
}
