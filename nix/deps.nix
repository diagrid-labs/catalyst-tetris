{ pkgs }:

let
  diagrid-cli-version = "v0.64.1";

  diagrid-cli-sha-tar = sys: sha256: builtins.fetchurl {
    name = "diagrid-cli-${sys}.tar.gz";
    url = "https://storage.googleapis.com/bkt-p-cli-common-us-central1-95640/${diagrid-cli-version}/catalyst/diagrid_linux_${sys}.tar.gz";
    inherit sha256;
  };

  diagrid-cli-sha = sys: sha256: pkgs.stdenv.mkDerivation {
    name = "diagrid-cli-sha-${sys}";
    src = diagrid-cli-sha-tar sys sha256;
    phases = [ "installPhase" ];
    installPhase = ''
      ${pkgs.gnutar}/bin/tar -xzf $src
      mkdir -p $out/bin
      cp diagrid $out/bin
    '';
  };

  diagrid-cli = {
    arm64 = diagrid-cli-sha "arm64" "0fvjsvrw4lqjslqla6ixs2zmclraj7jq7a0qfsig5wysrwfk96z7";
    amd64 = diagrid-cli-sha "amd64" "1r9l7d876j9ss2l8nj8xsqhcb3adg61mwa14z3n4kj44bqij5xl7";
  };

  components-contrib = pkgs.applyPatches {
    patches = [
      ./components-contrib.patch
    ];
    src = pkgs.fetchFromGitHub {
      owner = "dapr";
      repo = "components-contrib";
      rev = "v1.12.5";
      sha256 = "sha256-4HpW+UVFV9IthqeJs+0/u+IaC7pQ5+HaXR3HeFgW60o=";
    };
  };

  dapr-patched-src = pkgs.applyPatches {
    patches = [ ./dapr.patch ];
    src = pkgs.fetchFromGitHub {
      owner = "dapr";
      repo = "dapr";
      rev = "v1.12.2";
      sha256 = "sha256-g+A5Bnfyh+XG5KHtguBTechXRsqjUJxx45s8weYeht8=";
    };
    postPatch = ''
      cp -r ${components-contrib} components-contrib
    '';
  };

in {
  inherit diagrid-cli dapr-patched-src;
}
