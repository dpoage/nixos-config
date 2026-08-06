{ pkgs, ... }:

# HashiCorp suite. Nomad + Consul + Vault together form the k8s-alternative
# stack; kubernetes.nix stays alongside for the k8s workflow.
# Note: terraform/vault/consul/nomad are BSL-licensed (unfree in nixpkgs);
# covered by the global allowUnfree in default.nix. Waypoint is omitted —
# discontinued upstream and removed from nixpkgs.
{
  environment.systemPackages = with pkgs; [
    # Core products
    terraform # infrastructure as code
    vault # secrets management
    consul # service discovery / mesh
    nomad # workload orchestrator
    packer # machine image builds
    vagrant # dev VM management
    boundary # identity-based remote access

    # Companions
    terraform-ls # Terraform language server
    consul-template # template rendering from Consul/Vault
    nomad-pack # package manager for Nomad jobs
  ];
}
