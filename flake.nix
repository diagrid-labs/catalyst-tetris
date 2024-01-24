{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
    gomod2nix = {
      url = "github:tweag/gomod2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, utils, gomod2nix }:
  let
    lib = nixpkgs.lib;
    targetSystems = with utils.lib.system; [
      x86_64-linux
      x86_64-darwin
      aarch64-linux
      aarch64-darwin
    ];

  in utils.lib.eachSystem targetSystems (system:
    let
      overlays = [ gomod2nix.overlays.default ];

      pkgs = import nixpkgs { inherit system overlays; };
      cpkgs = {
        arm64 = pkgs.pkgsCross.aarch64-multiplatform;
        amd64 = pkgs.pkgsCross.gnu64;
      };

      meta = {
        version = "0.0.23";
        imageRepo = "diagrid.io/tetris";
        localSystem = if pkgs.stdenv.hostPlatform.isAarch64 then "arm64" else "amd64";
        src = with lib; {
          game = sourceFilesBySuffices ./game [ ".go" "go.mod" "go.sum" "gomod2nix.toml" "js" "tmpl" ];
          users = sourceFilesBySuffices ./users [ "py" "css" "js" "html" ];
        };
      };


      deps = import ./nix/deps.nix { inherit pkgs; };

      build = import ./nix/build.nix {
        inherit pkgs cpkgs meta deps;
      };

      images = import ./nix/images.nix {
        inherit pkgs cpkgs meta deps;
        bins = build.bins;
      };

      ci = import ./nix/ci.nix {
        inherit pkgs build;
        gomod2nix = (gomod2nix.packages.${system}.default);
      };

    in {
      packages = build.packages // images.packages;

      apps = build.apps // ci.apps // images.apps;

      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          go
          gopls
          gotools
          go-tools
          gomod2nix.packages.${system}.default
        ];
      };
  });
}
