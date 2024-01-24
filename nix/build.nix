{pkgs,
cpkgs,
deps,
meta,
}:

with pkgs;

let
  game-bin = sys: (pkgs.buildGoApplication {
    version = meta.version;
    name = "game";
    modules = ../game/gomod2nix.toml;
    src = meta.src.game;
    postInstall = ''
      if [ -f $out/bin/linux_${sys}/game ]; then
        mv -n $out/bin/linux_${sys}/game $out/bin/game
      fi
      rm -rf $out/bin/linux_${sys}
    '';
  }).overrideAttrs(old: old // { GOARCH = sys; CGO_ENABLED = "0"; });

  users-bin = sys: let
    usersTemplates = ../users/templates;
    usersStatic = ../users/static;
    cpkgs = pkgs.${sys};
  in with pkgs.python3Packages; buildPythonApplication {
    pname = "users";
    version = meta.version;
    postInstall = ''
      cp -r ${usersTemplates} $out/bin/templates
      cp -r ${usersStatic} $out/bin/static
    '';
    propagatedBuildInputs = [
      flask
      grpcio
      redis
      flask-socketio
      aiohttp
      dateutil
      deprecation
      (buildPythonPackage rec {
        pname = "dapr";
        version = "1.12.1";
        src = fetchPypi {
          inherit pname version;
          sha256 = "sha256-QtydNCLf9E+Gzywwv7NvwGKYKshmp89ovBwfSCMnO8I=";
        };
        doCheck = false;
      })
      (buildPythonPackage rec {
         pname = "cloudevents";
         version = "1.10.0";
         src = fetchPypi {
           inherit pname version;
           sha256 = "sha256-DE9yUBJnlTv3xsZROSFgKvzaAmgiAsZd6qur7AmFZzE=";
         };
         doCheck = false;
       })
      (buildPythonPackage rec {
         pname = "names_generator";
         version = "0.1.0";
         src = fetchPypi {
           inherit pname version;
           sha256 = "sha256-A9Desg5MF5aIAYED6u5ABKwrjYzMH4FSJy91FotqC0E=";
         };
         doCheck = false;
       })
      (buildPythonPackage rec {
         pname = "cmdkit";
         version = "2.1.2";
         src = fetchPypi {
           inherit pname version;
           sha256 = "sha256-4Re/Y5M+u7EWNL8tgYr+2Sr3I/5NEeZ3ONeoLplPsZg=";
         };
         doCheck = false;
       })
    ];
    src = meta.src.users;
  };

  bins = {
    game = {
      amd64 = game-bin "amd64";
      arm64 = game-bin "arm64";
    };
    users = {
      amd64 = users-bin "amd64";
      arm64 = users-bin "arm64";
    };
  };

  tetris = let
    containerRuntimeSH = pkgs.writeShellApplication {
      name = "container-runtime";
      text = ''
        echo ">> Starting Tetris App"
        if [[ -S /var/run/docker.sock ]]; then
          echo ">> Using container runtime docker"
          exec docker "$@"
        fi
        echo ">> Using container runtime podman"
        exec podman "$@"
      '';
    };
    redisDockerfile = ./Dockerfile.redis;
    res = {
      game = ../game/res;
      users = ../users/res;
    };
    usersBin = "${bins.users.${meta.localSystem}}/bin/app.py";
  in writeShellApplication {
    name = "tetris";
    runtimeInputs = with pkgs; [
      containerRuntimeSH
      dapr-cli
      go_1_20
      podman
      bins.game.${meta.localSystem}
      bins.users.${meta.localSystem}
    ];
    text = ''
      cleanup() {
        container-runtime stop -i redis-jsonsearch
        container-runtime rm redis-jsonsearch
      }

      trap 'cleanup' EXIT
      container-runtime buildx build -t redis-jsonsearch -f ${redisDockerfile}
      container-runtime run -d --name redis-jsonsearch -p 6379:6379 localhost/redis-jsonsearch

      rm -rf ~/.dapr/bin
      mkdir -p ~/.dapr/bin
      cd ${deps.dapr-patched-src} && go build -tags allcomponents -v -o ~/.dapr/bin/daprd ./cmd/daprd; cd -

      cat > ~/.dapr/config.yaml <<EOF
      apiVersion: dapr.io/v1alpha1
      kind: Configuration
      metadata:
        name: daprConfig
      spec: {}
      EOF

      FLASK_KEY=foo dapr run --app-id users --resources-path ${res.users} --log-level debug --app-protocol http --dapr-http-port=1234 --app-port 8002 -- ${usersBin} &
      dapr run --app-id game --resources-path ${res.game} --log-level debug --app-protocol http --dapr-grpc-port=5002 --app-port=8001 -- game &

      wait
    '';
  };

  tetrisApp = { type = "app"; program = "${tetris}/bin/tetris"; };

in {
  inherit bins;
  apps = {
    default = tetrisApp;
    tetris = tetrisApp;
  };
  packages = with bins; {
    game = game.${meta.localSystem};
    users = users.${meta.localSystem};
    game-amd64 = game.amd64;
    game-arm64 = game.arm64;
    users-amd64 = users.amd64;
    users-arm64 = users.arm64;
  };
}
