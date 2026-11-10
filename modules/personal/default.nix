# dpoage's layer on top of core, dev and dev-cloud: editor, theme, agent
# tooling, shell, timezone. Home-manager config lives in ./home.
{ config, lib, pkgs, ... }:

{
  imports = [
    ./neovim.nix
    ./theme
  ];

  time.timeZone = "America/Denver";

  # programs.neovim conflicts with nixvim's wrapped binary.
  programs.nixvim.viAlias = true;
  programs.nixvim.vimAlias = true;

  environment.systemPackages = with pkgs; [
    claude-code
    beads
    dolt # beads' storage backend (`bd dolt push`)
    b9s # board and tree over beads: `b9s` (TUI), `b9s web` (browser)
    opencode
    bun
    omp

    zsh
    oh-my-zsh
    starship
    tmux

    # Agent sandboxing; NixOS enables user namespaces, so no setuid wrapper.
    bubblewrap
    landrun # Landlock CLI — unprivileged path/TCP restrictions (kernel 6.12 → ABI v6)
    passt # user-mode net stack (`pasta`) for --unshare-net jails, outbound-only

    ffmpeg
    imagemagick
  ];

  # mkAfter: must run after overlays/personal, which defines bend.
  nixpkgs.overlays = lib.mkIf config.myNvidia.enable (
    lib.mkAfter [ (final: prev: { bend = prev.bend.override { cudaSupport = true; }; }) ]
  );
}
