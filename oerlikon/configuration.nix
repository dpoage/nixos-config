{ config, pkgs, ... }:

{
  imports = [
    ../common/profiles/laptop.nix
    ../common/profiles/work.nix
    # oerlikon runs hyprland only; switch to niri-stack alongside myRice
    # when you migrate this host.
    ../common/profiles/hyprland-stack.nix
  ];

  networking.hostName = "oerlikon";

  # Pattern CLI + netrc wiring (see common/pattern.nix for the bootstrap
  # dance the first rebuild after a reinstall needs).
  pattern.enable = true;

  # Since kernel 6.18, alienware-wmi exposes this Alienware's thermal modes as
  # platform_profile, and its "performance" mode pins both fans at full boost
  # even when idle. laptop.nix's PLATFORM_PROFILE_ON_AC = "performance" was a
  # no-op under 6.12; on 6.18 it means constant max fans, so stay on balanced.
  services.tlp.settings.PLATFORM_PROFILE_ON_AC = "balanced";

  myUser = {
    name = "dpoage";
    fullName = "Dustin";
    home =
      { ... }:
      {
        imports = [
          ../common/home
          ./monitors.nix
          ./bazel-prune.nix
        ];

        # Bazel's output base defaults to ~/.cache/bazel and grows into the
        # hundreds of GB; keep it on the big /data SSD (see ./storage.nix).
        # Every workspace path (so every worktree) gets its own output base;
        # what can be shared across them is the download cache, the fetched
        # external repos, and the action/CAS disk cache. Bazel GCs the disk
        # cache itself once it is idle. Wrappers that pass their own
        # --output_user_root/--disk_cache (the apollo dev container) are
        # unaffected; ./bazel-prune.nix caps those from outside.
        home.file.".bazelrc".text = ''
          startup --output_user_root=/data/cache/bazel
          common --repository_cache=/data/cache/repos
          common --repo_contents_cache=/data/cache/repo-contents
          build --disk_cache=/data/cache/build
          build --experimental_disk_cache_gc_max_size=100G
        '';
        # Gruvbox palette on the Hyprland stack. The palette themes the base
        # components (kitty, waybar, hyprland, hyprlock, starship) without
        # the rice bundle. To go fully gruvbox+niri, add `enable = true;
        # compositor = "niri";` and import niri-stack.nix.
        myRice.palette = "gruvbox";
      };
  };

  system.stateVersion = "25.11";
}
