# Alacritty terminal; colors come from the alacritty theme slot.
# Note: this coexists with the existing programs.kitty config in
# terminal.nix — both can be installed; the user picks at runtime.

{ config, lib, pkgs, ... }:

let
  cfg = config.myRice;
  stylix = config.stylix;
  toml = pkgs.formats.toml { };
  # Alacritty wants colors as "0x" + hex.
  hex = v: "0x${v}";
  ansiNames = [ "black" "red" "green" "yellow" "blue" "magenta" "cyan" "white" ];
  themeColors = { name, colors, ... }:
    let
      ansi = import ../../theme/ansi.nix colors;
      ansiHalf = offset: lib.listToAttrs (lib.imap0
        (i: n: lib.nameValuePair n (hex (builtins.elemAt ansi (offset + i)))) ansiNames);
    in
    toml.generate "alacritty-${name}.toml" {
      window.decorations_theme_variant = if colors.variant == "dark" then "Dark" else "Light";
      colors = {
        primary = {
          background = hex colors.base00;
          foreground = hex colors.base05;
        };
        normal = ansiHalf 0;
        bright = ansiHalf 8;
      };
    };
in
{
  config = lib.mkIf cfg.enable {
    # live_config_reload picks up the imported slot when it moves.
    myTheme.apps.alacritty.render = themeColors;

    programs.alacritty = {
      enable = true;
      settings = {
        env = {
          TERM = "xterm-256color";
        };
        window = {
          dynamic_padding = true;
          decorations = "full";
          opacity = stylix.opacity.terminal;
          dimensions = {
            columns = 100;
            lines = 30;
          };
          class = {
            instance = "Alacritty";
            general = "Alacritty";
          };
        };
        scrolling = {
          history = 10000;
          multiplier = 3;
        };
        font = {
          size = stylix.fonts.sizes.terminal;
          normal = { family = stylix.fonts.monospace.name; style = "Regular"; };
          bold   = { family = stylix.fonts.monospace.name; style = "Bold"; };
          italic = { family = stylix.fonts.monospace.name; style = "Italic"; };
          bold_italic = { family = stylix.fonts.monospace.name; style = "Bold Italic"; };
        };
        colors.draw_bold_text_with_bright_colors = true;
        selection = {
          semantic_escape_chars = ",│`|:\"' ()[]{}<>\t";
          save_to_clipboard = true;
        };
        cursor = {
          style = "Underline";
          unfocused_hollow = true;
          thickness = 0.15;
        };
        mouse = {
          hide_when_typing = true;
        };
        general = {
          live_config_reload = true;
          import = [ config.myTheme.apps.alacritty.path ];
        };
      };
    };
  };
}
