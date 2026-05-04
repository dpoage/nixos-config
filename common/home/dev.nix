{ pkgs, ... }:

{
  # Direnv + nix-direnv (auto-load project shells)
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = true;
  };

  # Git with delta for better diffs
  programs.git = {
    enable = true;
    userName = "Dustin Poage";
    delta = {
      enable = true;
      options = {
        navigate = true;
        side-by-side = true;
        line-numbers = true;
      };
    };
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      core.editor = "nvim";
      merge.conflictstyle = "zdiff3";
      diff.algorithm = "histogram";
      rerere.enable = true;
    };
  };

  # GitHub CLI
  programs.gh = {
    enable = true;
    settings.git_protocol = "ssh";
  };

  # SSH agent
  services.ssh-agent.enable = true;

  # nix-index + comma (run any nix package without installing)
  programs.nix-index = {
    enable = true;
    enableZshIntegration = true;
  };

  home.packages = with pkgs; [
    comma
    cachix
  ];
}
