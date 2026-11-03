#!/usr/bin/env bash
# Evaluate both hosts and build the flake-input packages cache.nixos.org
# lacks. pattern-cli is a private git+ssh input; an empty stub stands in so
# this runs without credentials. Evaluation warnings (deprecations, renamed
# options) are echoed as GitHub annotations rather than failing the check.
set -euo pipefail
cd "$(dirname "$0")/.."

stub=(--override-input pattern-cli path:./ci/pattern-cli-stub)
log=$(mktemp)
trap 'rm -f "$log"' EXIT

for host in oerlikon tunguska; do
  echo ">> evaluating $host"
  status=0
  nix eval --raw --option allow-import-from-derivation false "${stub[@]}" \
    ".#nixosConfigurations.$host.config.system.build.toplevel.drvPath" 2>"$log" || status=$?
  cat "$log" >&2
  grep -h 'evaluation warning:' "$log" | sed "s/^/::warning title=$host::/" || true
  [ "$status" -eq 0 ] || exit "$status"
  echo
done

echo ">> building beads and omp"
nix build --no-link --print-build-logs "${stub[@]}" \
  .#nixosConfigurations.tunguska.pkgs.beads \
  .#nixosConfigurations.tunguska.pkgs.omp
