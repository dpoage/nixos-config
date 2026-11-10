# Alacritty terminal, themed from the active palette.
# Note: this coexists with the existing programs.kitty config in
# terminal.nix — both can be installed; the user picks at runtime.

{ config, lib, pkgs, ... }:

let
  cfg = config.myRice;
  stylix = config.stylix;
  colors = config.lib.stylix.colors;
  ansi = import ../../theme/ansi.nix colors;
  # Alacritty wants colors as "0x" + hex.
  hex = v: "0x${v}";
  ansiNames = [ "black" "red" "green" "yellow" "blue" "magenta" "cyan" "white" ];
  ansiHalf = offset: lib.listToAttrs (lib.imap0
    (i: name: lib.nameValuePair name (hex (builtins.elemAt ansi (offset + i)))) ansiNames);
in
{
  config = lib.mkIf cfg.enable {
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
          decorations_theme_variant = if stylix.polarity == "dark" then "Dark" else "Light";
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
        colors = {
          draw_bold_text_with_bright_colors = true;
          primary = {
            background = hex colors.base00;
            foreground = hex colors.base05;
          };
          normal = ansiHalf 0;
          bright = ansiHalf 8;
        };
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
        };
      };
    };
  };
}
