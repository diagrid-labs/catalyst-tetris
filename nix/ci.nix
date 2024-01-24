{
pkgs,
gomod2nix,
build,
}:

let
  checkgomod2nixSH = pkgs.writeShellApplication {
    name = "check-gomod2nix";
    runtimeInputs = [ gomod2nix ];
    text = ''
      tmpdir=$(mktemp -d)
      trap 'rm -rf -- "$tmpdir"' EXIT
      gomod2nix --dir "$1" --outdir "$tmpdir"
      if ! diff -q "$tmpdir/gomod2nix.toml" "$1/gomod2nix.toml"; then
        echo '>> gomod2nix.toml is not up to date. Please run:'
        echo '>> $ nix run .#update'
        exit 1
      fi
      echo ">> \"$1/gomod2nix.toml\" is up to date"
    '';
  };

  updateSH = pkgs.writeShellApplication {
    name = "update";
    runtimeInputs = with pkgs; [
      git
      gomod2nix
      helm-docs
    ];
    text = ''
      cd "$(git rev-parse --show-toplevel)"/game
      gomod2nix
      echo '>> Updated. Please commit the changes.'
    '';
  };

  unitTestSH = pkgs.writeShellApplication {
    name = "unitTest";
    runtimeInputs = with pkgs; [ go ];
    text = ''
      cd "$1"
      gofmt -s -l -e .
      go vet -v ./...
      go test --race -v ./...
    '';
  };

  testSH = pkgs.writeShellApplication {
    name = "test";
    runtimeInputs = with pkgs; [
      git
      checkgomod2nixSH
      unitTestSH
    ];
    text = ''
      cd "$(git rev-parse --show-toplevel)"/game
      check-gomod2nix .
      unitTest .
    '';
  };
in {
  apps = {
    update = {type = "app"; program = "${updateSH}/bin/update";};
    test = {type = "app"; program = "${testSH}/bin/test";};
  };
}
