# Empty barrel — profiles are imported directly by hosts (e.g.
# `imports = [ ../common/profiles/laptop.nix ];`) rather than gated by
# options. This keeps the import graph easy to follow.
#
# Available profiles in this directory:
#   laptop.nix       — TLP, libinput, brightness, lid switch
#   workstation.nix  — desktop tower power/performance defaults
#   work.nix         — pattern-cli, work-only apps, no gaming
#   personal.nix     — Steam, gamescope, gaming, ASUS tools, multimedia

{ }
