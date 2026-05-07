{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    awscli2
    google-cloud-sdk
  ];
}
