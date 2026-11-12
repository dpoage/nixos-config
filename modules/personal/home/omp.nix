# omp follows the active myTheme palette through a generated custom theme.
{ config, lib, pkgs, ... }:

let
  ompTheme = import ../theme/omp-theme.nix { inherit lib; } {
    colors = config.lib.stylix.colors;
    lightContrast = config.myTheme.lightContrast;
  };
  ompConfig = "${config.home.homeDirectory}/.omp/agent/config.yml";
in
{
  home.file.".omp/agent/themes/${ompTheme.name}.json".text = builtins.toJSON ompTheme;

  # omp owns config.yml and rewrites it from its settings UI, so it stays a
  # regular file; point both appearance slots at the generated theme in place.
  home.activation.ompTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run mkdir -p "$(dirname ${ompConfig})"
    [ -e ${ompConfig} ] || run touch ${ompConfig}
    run ${lib.getExe pkgs.yq-go} -i \
      '.theme.dark = "${ompTheme.name}" | .theme.light = "${ompTheme.name}"' ${ompConfig}
  '';
}
