{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # AWS
    awscli2
    ssm-session-manager-plugin

    # GCP
    (google-cloud-sdk.withExtraComponents [
      google-cloud-sdk.components.gke-gcloud-auth-plugin
    ])
  ];
}
