{ pkgs, ... }:

{
  # Direnv + nix-direnv (auto-load project shells)
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    enableZshIntegration = true;
  };

  # Git
  programs.git = {
    enable = true;
    settings = {
      user.name = "Dustin Poage";
      init.defaultBranch = "main";
      pull.rebase = true;
      core.editor = "nvim";
      merge.conflictstyle = "zdiff3";
      diff.algorithm = "histogram";
      rerere.enable = true;
    };
  };

  # Delta (better diffs)
  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      side-by-side = true;
      line-numbers = true;
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

  # Put `go install` output (GOPATH/bin) on PATH. Entries are expanded in a
  # double-quoted context, so $HOME resolves at session init. Lets binaries
  # like `go install github.com/dpoage/bugbot@latest` run by bare name.
  home.sessionPath = [ "$HOME/go/bin" ];

  home.packages = with pkgs; [
    comma
    cachix

    # TypeScript / Node
    nodejs
    typescript
    nodePackages.typescript-language-server
  ];
}
