{pkgs,
cpkgs,
bins,
deps,
meta,
}:

let
  name = {
    game = "${meta.imageRepo}/game:${meta.version}";
    users = "${meta.imageRepo}/users:${meta.version}";
  };

  game-container = sys: let
    cli = deps.diagrid-cli.${sys};
    bin = bins.game.${sys};
    spkgs = cpkgs.${sys};
    script = spkgs.writeShellApplication {
      name = ".wrapped.sh";
      runtimeInputs = [ cli bin ];
      text = builtins.readFile ../game/.wrapped.sh;
    };
  in pkgs.dockerTools.buildLayeredImage {
    name = "game";
    tag = meta.version;
    contents = with spkgs; [
      cacert
      coreutils
      cli
      bin
      script
    ];
    config = {
      Cmd = [ "/bin/.wrapped.sh" ];
    };
  };

  users-container = sys: let
    cli = deps.diagrid-cli.${sys};
    bin = bins.users.${sys};
    spkgs = cpkgs.${sys};
    script = spkgs.writeShellApplication {
      name = ".wrapped.sh";
      text = builtins.readFile ../users/.wrapped.sh;
      runtimeInputs = [ cli bin ];
    };
  in pkgs.dockerTools.buildLayeredImage {
    name = "users";
    tag = meta.version;
    contents = with spkgs; [
      cacert
      coreutils
      cli
      bin
      script
    ];
    config = {
      Env = [ "COMMAND=${bin}/bin/app.py" ];
      Cmd = [ "/bin/.wrapped.sh" ];
    };
  };

  images = {
    game = {
      amd64 = game-container"amd64";
      arm64 = game-container"arm64";
    };
    users = {
      amd64 = users-container "amd64";
      arm64 = users-container "arm64";
    };
  };

  build-containers = let
    docker = pkgs.writeShellApplication {
      name = "build-containers";
      text = ''
        docker manifest rm ${name.game} 2>/dev/null || true
        docker manifest rm ${name.users} 2>/dev/null || true
        docker manifest create ${name.game} ${images.game.amd64} ${images.game.arm64}
        docker manifest create ${name.users} ${images.users.amd64} ${images.users.arm64}
      '';
    };
    podman = pkgs.writeShellApplication {
      name = "build-containers";
      text = ''
        podman manifest rm ${name.game} 2>/dev/null || true
        podman manifest rm ${name.users} 2>/dev/null || true
        podman manifest create ${name.users}
        podman manifest create ${name.game}
        podman manifest add ${name.game} docker-archive:${images.game.amd64} --os linux --arch amd64
        podman manifest add ${name.game} docker-archive:${images.game.arm64} --os linux --arch arm64
        podman manifest add ${name.users} docker-archive:${images.users.amd64} --os linux --arch amd64
        podman manifest add ${name.users} docker-archive:${images.users.arm64} --os linux --arch arm64
      '';
    };
  in pkgs.writeShellApplication {
    name = "build-containers";
    text = ''
      echo ">> Building ${name.game} and ${name.users} images"
      if [[ -S /var/run/docker.sock ]]; then
        echo ">> Using container runtime: docker"
        ${docker}/bin/build-containers
      else
        echo ">> Using container runtime: podman"
        ${podman}/bin/build-containers
      fi
      echo ">> Built ${name.game} and ${name.users} images"
    '';
  };

in {
  packages = with images; {
    image-game = game.${meta.localSystem};
    image-users = users.${meta.localSystem};
    image-game-amd64 = game.amd64;
    image-game-arm64 = game.arm64;
    image-users-amd64 = users.amd64;
    image-users-arm64 = users.arm64;
  };
  apps = {
    build-containers = { type = "app"; program = "${build-containers}/bin/build-containers"; };
  };
}
