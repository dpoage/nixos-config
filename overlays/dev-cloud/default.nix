# Dev-cloud-layer packages.
final: prev: {
  # krr (Robusta's Kubernetes Resource Recommender): unbuildable as shipped.
  # nixpkgs' prometrix (0.1.18-unstable) requires pydantic 2 and is marked
  # broken against prometheus-api-client >= 0.5.3, while krr itself pins
  # pydantic 1 — so the stock pairing can never work. krr's own poetry.lock
  # resolves prometrix 0.1.10 (pydantic 1 native); pin that release from PyPI
  # inside krr's python scope. Two fixups on top:
  #  - prometheus-api-client >= 0.5.3 removed the `ssl_verification` attribute
  #    prometrix reads (robusta-dev/prometrix#14). It was defined as
  #    `not disable_ssl`, so patch the references to compute that from
  #    prometrix's own config.
  #  - relax the prometheus-api-client < 0.6 cap (scope ships 0.6.0).
  # Drop this once nixpkgs' prometrix/krr pairing builds again.
  krr =
    (prev.krr.override {
      python3 = prev.python3.override {
        packageOverrides = pyfinal: pyprev: {
          prometrix = pyprev.prometrix.overridePythonAttrs (old: {
            version = "0.1.10";
            src = final.fetchPypi {
              pname = "prometrix";
              version = "0.1.10";
              hash = "sha256-ntYcC3e1A9OM6cZtcHQq2BqEt6/G+/Y+jbupMWtBpN8=";
            };
            postPatch = ''
              substituteInPlace prometrix/connect/custom_connect.py prometrix/connect/aws_connect.py \
                --replace-fail "self.ssl_verification" "(not self.config.disable_ssl)"
            '';
            dependencies = with pyfinal; [
              boto3
              botocore
              prometheus-api-client
              pydantic_1
              requests
            ];
            pythonRelaxDeps = [ "prometheus-api-client" ];
            meta = old.meta // {
              broken = false;
            };
          });
        };
      };
    }).overridePythonAttrs
      (old: {
        pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [
          "numpy"
          "prometheus-api-client"
        ];
        # robusta_krr/utils/service_discovery.py imports cachetools, which
        # nixpkgs' krr leaves undeclared (formerly pulled in transitively).
        dependencies = (old.dependencies or [ ]) ++ [ prev.python3.pkgs.cachetools ];
        # Two click-8.2 fixups (krr pins typer ^0.7 / click <8.2 upstream;
        # nixpkgs relaxes those pins):
        #  - CliRunner(mix_stderr=...) was removed; stderr is separate by
        #    default now, which is what mix_stderr=False asked for.
        #  - unset multi-value options now yield None instead of (), which
        #    crashes `"*" in namespaces` and Config's headers validator.
        #    Substitute [] — Config's validators map [] to the "*"/{} defaults
        #    exactly as the old () did.
        postPatch = (old.postPatch or "") + ''
          substituteInPlace tests/test_krr.py \
            --replace-fail "CliRunner(mix_stderr=False)" "CliRunner()"
          substituteInPlace robusta_krr/main.py \
            --replace-fail \
              'namespaces="*" if "*" in namespaces else namespaces' \
              'namespaces="*" if "*" in (namespaces or []) else (namespaces or [])' \
            --replace-fail \
              'resources="*" if "*" in resources else resources' \
              'resources="*" if "*" in (resources or []) else (resources or [])' \
            --replace-fail \
              'prometheus_other_headers=prometheus_other_headers,' \
              'prometheus_other_headers=prometheus_other_headers or [],'
        '';
      });
}
