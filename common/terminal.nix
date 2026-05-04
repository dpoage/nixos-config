{ pkgs, ... }:

{
  home.stateVersion = "25.11";

  # Kitty terminal - Catppuccin Mocha theme
  programs.kitty = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font";
      size = 12;
    };
    settings = {
      # Catppuccin Mocha colors
      foreground = "#CDD6F4";
      background = "#1E1E2E";
      selection_foreground = "#1E1E2E";
      selection_background = "#F5E0DC";
      cursor = "#F5E0DC";
      cursor_text_color = "#1E1E2E";
      url_color = "#F5E0DC";

      # Black
      color0 = "#45475A";
      color8 = "#585B70";
      # Red
      color1 = "#F38BA8";
      color9 = "#F38BA8";
      # Green
      color2 = "#A6E3A1";
      color10 = "#A6E3A1";
      # Yellow
      color3 = "#F9E2AF";
      color11 = "#F9E2AF";
      # Blue
      color4 = "#89B4FA";
      color12 = "#89B4FA";
      # Magenta
      color5 = "#F5C2E7";
      color13 = "#F5C2E7";
      # Cyan
      color6 = "#94E2D5";
      color14 = "#94E2D5";
      # White
      color7 = "#BAC2DE";
      color15 = "#A6ADC8";

      # Tab bar
      active_tab_foreground = "#11111B";
      active_tab_background = "#CBA6F7";
      inactive_tab_foreground = "#CDD6F4";
      inactive_tab_background = "#181825";
      tab_bar_background = "#11111B";

      # Window
      background_opacity = "0.92";
      window_padding_width = "8";
      confirm_os_window_close = "0";
      enable_audio_bell = "no";
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";

      # Scrollback
      scrollback_lines = "10000";

      # URLs
      detect_urls = "yes";
      open_url_with = "default";
    };
  };

  # Zsh
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    enableCompletion = true;

    history = {
      size = 50000;
      save = 50000;
      ignoreDups = true;
      ignoreAllDups = true;
      ignoreSpace = true;
      extended = true;
      share = true;
    };

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "docker"
        "kubectl"
        "sudo"
        "history"
        "extract"
      ];
    };

    shellAliases = {
      ls = "eza --icons";
      ll = "eza -la --icons --git";
      lt = "eza --tree --icons --level=2";
      cat = "bat";
      cd = "z";
      grep = "rg";
      find = "fd";
      top = "btop";
      ".." = "cd ..";
      "..." = "cd ../..";
      gs = "git status";
      gd = "git diff";
      gl = "git log --oneline --graph";
      gc = "git commit";
      gp = "git push";
    };

    initContent = ''
      # Initialize zoxide
      eval "$(zoxide init zsh)"

      # FZF keybindings
      if [ -n "''${commands[fzf-share]}" ]; then
        source "$(fzf-share)/key-bindings.zsh"
        source "$(fzf-share)/completion.zsh"
      fi

      # FZF Catppuccin Mocha theme
      export FZF_DEFAULT_OPTS=" \
        --color=bg+:#313244,bg:#1e1e2e,spinner:#f5e0dc,hl:#f38ba8 \
        --color=fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#f5e0dc \
        --color=marker:#b4befe,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8 \
        --color=selected-bg:#45475a \
        --multi"
    '';
  };

  # Starship prompt
  programs.starship = {
    enable = true;
    settings = {
      format = builtins.concatStringsSep "" [
        "[](mauve)"
        "$os"
        "$username"
        "[](bg:peach fg:mauve)"
        "$directory"
        "[](fg:peach bg:green)"
        "$git_branch"
        "$git_status"
        "[](fg:green bg:teal)"
        "$rust"
        "$golang"
        "$python"
        "$nodejs"
        "[](fg:teal bg:blue)"
        "$docker_context"
        "[](fg:blue bg:purple)"
        "$time"
        "[ ](fg:purple)"
        "$line_break"
        "$character"
      ];

      palette = "catppuccin_mocha";

      palettes.catppuccin_mocha = {
        rosewater = "#f5e0dc";
        flamingo = "#f2cdcd";
        pink = "#f5c2e7";
        mauve = "#cba6f7";
        red = "#f38ba8";
        maroon = "#eba0ac";
        peach = "#fab387";
        yellow = "#f9e2af";
        green = "#a6e3a1";
        teal = "#94e2d5";
        sky = "#89dceb";
        sapphire = "#74c7ec";
        blue = "#89b4fa";
        lavender = "#b4befe";
        text = "#cdd6f4";
        subtext1 = "#bac2de";
        subtext0 = "#a6adc8";
        overlay2 = "#9399b2";
        overlay1 = "#7f849c";
        overlay0 = "#6c7086";
        surface2 = "#585b70";
        surface1 = "#45475a";
        surface0 = "#313244";
        base = "#1e1e2e";
        mantle = "#181825";
        crust = "#11111b";
        purple = "#b4befe";
      };

      os = {
        disabled = false;
        style = "bg:mauve fg:crust";
        symbols.NixOS = " ";
      };

      username = {
        show_always = true;
        style_user = "bg:mauve fg:crust";
        style_root = "bg:mauve fg:crust";
        format = "[ $user ]($style)";
      };

      directory = {
        style = "fg:crust bg:peach";
        format = "[ $path ]($style)";
        truncation_length = 3;
        truncation_symbol = ".../";
        substitutions = {
          Documents = " ";
          Downloads = " ";
          Music = " ";
          Pictures = " ";
        };
      };

      git_branch = {
        symbol = "";
        style = "bg:green fg:crust";
        format = "[ $symbol $branch ]($style)";
      };

      git_status = {
        style = "bg:green fg:crust";
        format = "[$all_status$ahead_behind ]($style)";
      };

      rust = {
        symbol = "";
        style = "bg:teal fg:crust";
        format = "[ $symbol ($version) ]($style)";
      };

      golang = {
        symbol = "";
        style = "bg:teal fg:crust";
        format = "[ $symbol ($version) ]($style)";
      };

      python = {
        symbol = "";
        style = "bg:teal fg:crust";
        format = "[ $symbol ($version) ]($style)";
      };

      nodejs = {
        symbol = "";
        style = "bg:teal fg:crust";
        format = "[ $symbol ($version) ]($style)";
      };

      docker_context = {
        symbol = "";
        style = "bg:blue fg:crust";
        format = "[ $symbol $context ]($style)";
      };

      time = {
        disabled = false;
        time_format = "%R";
        style = "bg:purple fg:crust";
        format = "[ $time ]($style)";
      };

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol = "[❯](bold red)";
      };

      line_break.disabled = false;
    };
  };
}
