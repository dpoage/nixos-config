# Palette registry. Each file exports { meta, fonts, terminal, colors }.
#
# To add a new palette:
#   1. Create palettes/<name>.nix following the schema
#   2. Add it to the attrset below
#   3. Nix eval will enforce that all required color keys exist
{
  gruvbox    = import ./gruvbox.nix;
  catppuccin = import ./catppuccin.nix;
}
