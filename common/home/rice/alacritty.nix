# Alacritty terminal, themed from the active palette.
# Note: this coexists with the existing programs.kitty config in
# terminal.nix — both can be installed; the user picks at runtime.

{ config, osConfig, lib, pkgs, ... }:

let
  cfg = config.myRice;
  t   = osConfig.myTheme;
  c   = t.colors;
  # Alacritty wants colors as "0x" + hex.
  hex = v: "0x${v}";
  ansiNames = [ "black" "red" "green" "yellow" "blue" "magenta" "cyan" "white" ];
  ansiHalf = offset: lib.listToAttrs (lib.imap0
    (i: name: lib.nameValuePair name (hex (builtins.elemAt t.ansi (offset + i)))) ansiNames);
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
          opacity = t.terminal.opacity;
          decorations_theme_variant = if t.meta.variant == "dark" then "Dark" else "Light";
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
          size = t.fonts.monoSize;
          normal = { family = t.fonts.mono; style = "Regular"; };
          bold   = { family = t.fonts.mono; style = "Bold"; };
          italic = { family = t.fonts.mono; style = "Italic"; };
          bold_italic = { family = t.fonts.mono; style = "Bold Italic"; };
        };
        colors = {
          draw_bold_text_with_bright_colors = true;
          primary = {
            background = hex c.bg;
            foreground = hex c.fg;
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
