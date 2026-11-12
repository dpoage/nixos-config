{ config, lib, pkgs, ... }:

let
  cfg = config.myPrompt;
  stylix = config.stylix;

  # Rounded pill around `body`; the body styles itself and must carry bg:`color`.
  pill = color: body: "[](fg:${color})${body}[](fg:${color}) ";

  badgeText = b: if b.label != "" then "${b.icon} ${b.label}" else b.icon;
  badges = lib.concatMapStringsSep " " badgeText cfg.badges;

  # Identity pill: static badges plus user@host, which starship shows only over
  # SSH or as another user. Without badges the pill exists only when they do.
  gap = "[ ](bg:neutral)";
  identity =
    if cfg.badges != [ ]
    then pill "neutral" "[ ${badges}](bg:neutral fg:neutral_fg)(${gap}$username$hostname)${gap}"
    else "(${pill "neutral" "${gap}$username$hostname${gap}"})";

  # Semantic prompt colors; pills put base00 text on them, other text sits on base00.
  promptColors = { colors, roles, ... }: lib.mapAttrs (_: hex: "#${hex}") {
    neutral = colors.base02;
    neutral_fg = colors.base05;
    pill_text = colors.base00;
    path = roles.fill "base16";
    branch = roles.fill "base0B";
    dirty = roles.fill "base0A";
    toolchain = roles.fill "base15";
    cloud = roles.fill "base17";
    danger = roles.dangerFill;
    subtle = roles.hint;
  };

  kittyColors = import ../theme/kitty-colors.nix { inherit lib; };
  toml = pkgs.formats.toml { };

  # LS_COLORS is `vivid generate` of the Stylix vivid target's theme, whose
  # styles name slots; each palette fills them in.
  vividTheme = config.programs.vivid.themes.${config.programs.vivid.activeTheme};
  shellTheme = { name, colors, roles, ... }: pkgs.runCommandLocal "shell-theme-${name}"
    { nativeBuildInputs = [ config.programs.vivid.package ]; } ''
      # JSON, not formats.yaml: unquoted hex like 2e3440 reads as a float.
      vivid=$(vivid generate ${pkgs.writeText "vivid-${name}.yml" (builtins.toJSON (vividTheme // {
        colors = lib.getAttrs (lib.attrNames vividTheme.colors) colors;
      }))})
      printf 'export LS_COLORS=%q\n' "$vivid" > $out
      # Default hint is ANSI 8, 1.9:1 on catppuccin-latte.
      printf 'ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE=%q\n' ${lib.escapeShellArg (if roles.light then "fg=#${roles.hint}" else "fg=8")} >> $out
    '';
  shellSlot = config.myTheme.apps.shell.path;
in
{
  options.myPrompt = {
    badges = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          icon = lib.mkOption {
            type = lib.types.str;
            description = "Nerd Font icon for the badge.";
          };
          label = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Optional text label next to the icon.";
          };
        };
      });
      default = [];
      description = ''
        Static badges shown in the prompt between username and directory.
        Set by host profiles to indicate active modules/context.
      '';
    };

    kubernetes = lib.mkEnableOption "the Kubernetes context segment in the prompt";
    gcloud = lib.mkEnableOption "the Google Cloud segment in the prompt";
    aws = lib.mkEnableOption "the AWS segment in the prompt";
  };

  config = {
    # Stylix's kitty target only emits base16 colors and is off (see
    # modules/personal/theme); colors come from the kitty theme slot, fonts from stylix.*.
    programs.kitty = {
      enable = true;
      font = {
        name = stylix.fonts.monospace.name;
        size = stylix.fonts.sizes.terminal;
      };
      settings = {
        # `theme` recolors over this socket (kitty appends -<pid>);
        # $XDG_RUNTIME_DIR is 0700, and socket-only refuses escape-code requests.
        allow_remote_control = "socket-only";
        listen_on = "unix:\${XDG_RUNTIME_DIR}/kitty";

        # Window
        background_opacity = toString stylix.opacity.terminal;
        window_padding_width = "8";
        # kitty >= 0.49 restores the last window state (incl. maximized) on
        # Wayland; under Hyprland that opens every new kitty maximized
        # instead of tiled. The tiler owns geometry, so don't remember it.
        remember_window_size = "no";
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
      extraConfig = "include ${config.myTheme.apps.kitty.path}";
    };

    myTheme.apps = {
      kitty = {
        render = theme: lib.concatStrings
          (lib.mapAttrsToList (k: v: "${k} ${v}\n") (kittyColors theme));
        reload = ''
          shopt -s nullglob
          for sock in "$XDG_RUNTIME_DIR"/kitty-*; do
            # Sockets of exited kittys linger.
            kill -0 "''${sock##*-}" 2>/dev/null || continue
            ${config.programs.kitty.package}/bin/kitten @ --to "unix:$sock" \
              set-colors --all --configured "$THEME_FILE"
          done
        '';
      };
      # The rendered settings plus the palette; starship rereads it every prompt.
      starship = {
        render = theme@{ name, ... }: toml.generate "starship-${name}.toml"
          (config.programs.starship.settings // {
            palette = "base16";
            palettes.base16 = promptColors theme;
          });
        path = "${config.xdg.configHome}/starship.toml";
      };
      # Sourced by zsh before the next prompt once the slot moves.
      shell.render = shellTheme;
      fzf.render = { colors, ... }: with colors.withHashtag; "--color=" + lib.concatStringsSep "," [
        "bg:${base00}" "bg+:${base01}" "fg:${base04}" "fg+:${base06}"
        "header:${base0D}" "hl:${base0D}" "hl+:${base0D}" "info:${base0A}"
        "marker:${base0C}" "pointer:${base0C}" "prompt:${base0A}" "spinner:${base0C}"
      ] + "\n";
      tmux = {
        render = { colors, ... }: colors {
          templateRepo = config.stylix.inputs.tinted-tmux;
          target = "base16";
        };
        reload = ''
          shopt -s nullglob
          for sock in "''${TMUX_TMPDIR:-/tmp}/tmux-$(id -u)"/*; do
            # Sockets of exited servers linger.
            ${pkgs.tmux}/bin/tmux -S "$sock" list-sessions >/dev/null 2>&1 || continue
            ${pkgs.tmux}/bin/tmux -S "$sock" source-file "$THEME_FILE"
          done
        '';
      };
    };
    # The slot replaces the generated starship.toml; settings stay the source.
    xdg.configFile."starship.toml".enable = false;
    stylix.targets = {
      fzf.enable = false;
      starship.enable = false;
      tmux.enable = false;
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
        grep = "rg";
        find = "fd";
        top = "btop";
        ".." = "cd ..";
        # NOTE: `cd` is provided by programs.zoxide (--cmd cd) below, not aliased
        # here. A static `cd = "z"` alias breaks in non-interactive shells (e.g.
        # the Claude Code Bash tool) where zoxide's functions aren't loaded,
        # yielding `__zoxide_z: command not found`.
        "..." = "cd ../..";
        gs = "git status";
        gd = "git diff";
        gl = "git log --oneline --graph";
        gc = "git commit";
        gp = "git push";
      };

      initContent = ''
        # FZF keybindings
        if [ -n "''${commands[fzf-share]}" ]; then
          source "$(fzf-share)/key-bindings.zsh"
          source "$(fzf-share)/completion.zsh"
        fi

        export FZF_DEFAULT_OPTS_FILE=${config.myTheme.apps.fzf.path}

        # Re-source the shell theme slot whenever `theme` re-points it.
        _my_theme_shell() {
          local target=''${''${:-${shellSlot}}:A}
          [[ $target == $_my_theme_shell_seen ]] && return
          _my_theme_shell_seen=$target
          [[ -r ${shellSlot} ]] && source ${shellSlot}
        }
        _my_theme_shell
        precmd_functions+=(_my_theme_shell)
      '';
    };

    # fzf colors come from the fzf theme slot; bat/btop from Stylix.
    programs.fzf = {
      enable = true;
      enableZshIntegration = false;
      defaultOptions = [ "--multi" ];
    };
    programs.bat.enable = true;
    programs.btop.enable = true;

    # The Stylix vivid target defines the theme the shell slot generates
    # LS_COLORS from. Directories use base0D: the target's base0F is
    # unreadable on gruvbox-dark.
    programs.vivid = {
      enable = true;
      enableZshIntegration = false;
      themes.${config.programs.vivid.activeTheme}.core.directory.foreground =
        lib.mkForce "base0D";
    };

    # Zoxide (smart cd). Managed via the home-manager module rather than a
    # manual `eval "$(zoxide init zsh)"` so initialization stays in sync with the
    # package and ordering. `--cmd cd` defines a `cd` shell function that handles
    # real paths directly and falls back to zoxide queries — and, crucially, when
    # the integration isn't loaded (non-interactive shells like the Claude Code
    # Bash tool) `cd` is simply the builtin, instead of a dangling `z` alias.
    programs.zoxide = {
      enable = true;
      enableZshIntegration = true;
      options = [ "--cmd cd" ];
    };

    # Yazi (terminal file browser). enableZshIntegration provides the `yy`
    # wrapper function, which cd's the shell to yazi's last directory on
    # quit — the reason to prefer it over invoking `yazi` directly.
    programs.yazi = {
      enable = true;
      enableZshIntegration = true;
      shellWrapperName = "yy";
      settings = {
        mgr.show_hidden = true;
        preview.wrap = "yes";
      };
    };

    # Tmux
    programs.tmux = {
      enable = true;
      mouse = true;
      terminal = "screen-256color";
      extraConfig = ''
        bind | split-window -h
        bind - split-window -v
        unbind '"'
        unbind %

        # switch panes using Alt-arrow without prefix
        bind -n M-Left select-pane -L
        bind -n M-Right select-pane -R
        bind -n M-Up select-pane -U
        bind -n M-Down select-pane -D

        # don't do anything when a 'bell' rings
        set -g visual-activity off
        set -g visual-bell off
        set -g visual-silence off
        setw -g monitor-activity off
        set -g bell-action none

        # Colors: styles for the status line, windows, panes, messages, copy
        # mode and clock come from the tmux theme slot (tinted-tmux base16).
        source-file -q ${config.myTheme.apps.tmux.path}

        # statusbar
        set -g status-position bottom
        set -g status-justify left

        set -g status-left ""
        set -g status-left-length 10

        set -g status-right '%Y-%m-%d %H:%M '
        set -g status-right-length 50

        setw -g window-status-current-format ' #I #W #F '
        setw -g window-status-format ' #I #W #F '
      '';
    };

    # SSH
    programs.ssh = {
      enable = true;
      enableDefaultConfig = false;
      settings."*" = {
        SetEnv = { TERM = "xterm-256color"; };
      };
      # Alias the fleet flake's platform inputs fetch through
      # (robot-provisioning-fleet flake.nix).
      settings."github-platform" = {
        HostName = "github.com";
        User = "git";
        IdentityFile = "~/.ssh/id_ed25519";
        IdentitiesOnly = true;
        HostKeyAlias = "github.com";
      };
    };

    # Starship prompt. Pills: identity, directory, git; plain text: toolchain
    # and cloud context. Right side: exit status, duration, jobs, time.
    programs.starship = {
      enable = true;
      settings = {
        format = builtins.concatStringsSep "" [
          identity
          "$directory"
          "$git_branch$git_commit$git_state$git_status"
          "$nix_shell$python$rust$golang$nodejs"
          "$docker_context$kubernetes$gcloud$aws"
          "$line_break$character"
        ];
        right_format = "$status$cmd_duration$jobs$time";

        username = {
          style_user = "bg:neutral fg:neutral_fg";
          style_root = "bg:danger fg:pill_text bold";
          format = "[$user]($style)";
        };

        hostname = {
          style = "bg:neutral fg:neutral_fg bold";
          format = "[@$hostname]($style)";
        };

        # Inside a repo: bold repo name, then the path below it.
        directory = let
          tail = "[$path]($style)[$read_only]($read_only_style)[ ]($style)";
        in {
          style = "bg:path fg:pill_text";
          repo_root_style = "bg:path fg:pill_text bold";
          read_only_style = "bg:path fg:pill_text";
          read_only = " 󰌾";
          format = pill "path" "[ ]($style)${tail}";
          repo_root_format = pill "path" "[ $repo_root]($repo_root_style)${tail}";
          truncation_length = 4;
          truncation_symbol = "…/";
        };

        git_branch = {
          only_attached = true;
          format = pill "branch" "[  $branch ](bg:branch fg:pill_text)";
        };

        git_commit.format = pill "branch" "[  $hash$tag ](bg:branch fg:pill_text)";

        git_state.format = pill "danger"
          "[ $state( $progress_current/$progress_total) ](bg:danger fg:pill_text bold)";

        # Shown only when the tree is dirty, stashed, or out of sync with upstream.
        git_status = {
          format = "(${pill "dirty" "[ $all_status$ahead_behind](bg:dirty fg:pill_text)"})";
          conflicted = "✘$count ";
          staged = "+$count ";
          modified = "~$count ";
          renamed = "»$count ";
          deleted = "-$count ";
          typechanged = "";
          untracked = "?$count ";
          stashed = "≡$count ";
          ahead = "⇡$count ";
          behind = "⇣$count ";
          diverged = "⇡$ahead_count⇣$behind_count ";
        };

        nix_shell = {
          symbol = "❄ ";
          style = "fg:toolchain";
          format = "[$symbol$name]($style) ";
        };

        python = {
          symbol = " ";
          style = "fg:toolchain";
          format = "[$symbol$version( \\($virtualenv\\))]($style) ";
        };

        rust = {
          symbol = " ";
          style = "fg:toolchain";
          format = "[$symbol$version]($style) ";
        };

        golang = {
          symbol = " ";
          style = "fg:toolchain";
          format = "[$symbol$version]($style) ";
        };

        nodejs = {
          symbol = " ";
          style = "fg:toolchain";
          format = "[$symbol$version]($style) ";
        };

        docker_context = {
          symbol = " ";
          style = "fg:cloud";
          format = "[$symbol$context]($style) ";
        };

        kubernetes = {
          disabled = !cfg.kubernetes;
          symbol = "☸ ";
          style = "fg:cloud";
          format = "[$symbol$context( \\($namespace\\))]($style) ";
        };

        # Literal symbols: a conditional group hides only when all its variables are empty.
        gcloud = {
          disabled = !cfg.gcloud;
          style = "fg:cloud";
          format = "([☁ $project]($style) )";
        };

        aws = {
          disabled = !cfg.aws;
          style = "fg:cloud";
          format = "([ $profile( \\($region\\))]($style) )";
        };

        status = {
          disabled = false;
          style = "fg:danger bold";
          format = "[✘ $status( $signal_name)]($style) ";
        };

        cmd_duration = {
          min_time = 2000;
          style = "fg:subtle";
          format = "[took $duration]($style) ";
        };

        jobs = {
          symbol = "✦ ";
          number_threshold = 1;
          style = "fg:dirty";
          format = "[$symbol$number]($style) ";
        };

        time = {
          disabled = false;
          time_format = "%R";
          style = "fg:subtle";
          format = "[$time]($style)";
        };

        character = {
          success_symbol = "[❯](bold fg:branch)";
          error_symbol = "[❯](bold fg:danger)";
          vimcmd_symbol = "[❮](bold fg:branch)";
        };
      };
    };
  };
}
