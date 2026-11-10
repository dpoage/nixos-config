# Language toolchains and cross-arch builds for engineering machines.
{ pkgs, ... }:

{
  # QEMU binfmt registration so nix can build aarch64/riscv64 derivations
  # transparently; the binfmt module also sets extra-platforms and sandbox paths.
  boot.binfmt.emulatedSystems = [
    "aarch64-linux"
    "riscv64-linux"
  ];

  environment.systemPackages = with pkgs; [
    pkg-config
    ninja

    # Python
    python3
    uv
    ruff
    pyright

    # Go
    go
    gopls
    golangci-lint
    delve

    # C/C++
    gcc
    gnumake
    cmake
    clang-tools
    gdb

    # Elixir
    elixir
    elixir-ls

    # Rust
    rustup
    rust-analyzer
  ];
}
