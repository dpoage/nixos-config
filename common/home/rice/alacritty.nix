# Alacritty terminal, themed from the active palette.
# Note: this coexists with the existing programs.kitty config in
# terminal.nix — both can be installed; the user picks at runtime.

{ config, lib, pkgs, ... }:

let
  cfg = config.myRice;
  c   = cfg.colors;
  # Alacritty wants colors as "0x" + hex.
  hex = v: "0x${v}";
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
          opacity = 1.0;
          decorations_theme_variant = "Dark";
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
          size = 12;
          normal = { family = "FantasqueSansM Nerd Font Mono"; style = "Regular"; };
          bold   = { family = "FantasqueSansM Nerd Font Mono"; style = "Bold"; };
          italic = { family = "FantasqueSansM Nerd Font Mono"; style = "Italic"; };
          bold_italic = { family = "FantasqueSansM Nerd Font Mono"; style = "Bold Italic"; };
        };
        colors = {
          draw_bold_text_with_bright_colors = true;
          primary = {
            background = hex c.bg;
            foreground = hex c.fg;
          };
          normal = {
            black   = hex c.bg0;
            red     = hex c.red;
            green   = hex c.green;
            yellow  = hex c.yellow;
            blue    = hex c.blue;
            magenta = hex c.purple;
            cyan    = hex c.aqua;
            white   = hex c.fg4;
          };
          bright = {
            black   = hex c.gray;
            red     = hex c.redBr;
            green   = hex c.greenBr;
            yellow  = hex c.yellowBr;
            blue    = hex c.blueBr;
            magenta = hex c.purpleBr;
            cyan    = hex c.aquaBr;
            white   = hex c.fg;
          };
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
