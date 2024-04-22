# Multiplayer Tetris

Browser based multiplayer Tetris game written in Python and Go using Catalyst (Dapr) for state and communication.
This is a demo project to show off the kind of things you can build with [Diagrid Catalyst](https://www.diagrid.io/catalyst).
The game is a bit of fun- there are very many ways you can cheat, stay honest (:

![tetris game](tetris_game.gif)

Watch the webinar on YouTube where Catalyst and the game are explained:

[![Webinar](https://img.youtube.com/vi/VS036hE6cvg/0.jpg)](https://youtu.be/VS036hE6cvg)

## Components

game:
- scorepubsub (pubsub.redis): Sends game results to `users` service.

users:
- scorepubsub (pubsub.redis): Receives game results from `game` service.
- kvstore (state.in-memory): Stores playing waiting in the lobby.
- userscores (state.redis): Stores user state consisting of username, hashed password, wins, points, and games played.

## APIs

game:
- PubSub (scorepubsub): Publishes game results to `users` consumer service.
- Service Invocation: Registers incoming games from `users` service with two players.

users:
- State Set/Get (kvstore): Stores users waiting in the lobby.
- State Set/Get (userscores): Stores user state consisting of username, hashed password, wins, points, and games played.
- State Query (userscores): List the top 20 players by wins.
- PubSub (scorepubsub): Receives game results from `game` producer service.
- Service Invocation: Registers two users ready to play a game with `game` service.




## Prerequisites

- [Docker Desktop](https://docs.docker.com/get-docker/)
- [VSCode](https://code.visualstudio.com/) with the [DevContainers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension

## Running locally

1. Fork this repo, and clone it to your local machine.
2. Open the repo in VSCode.
3. Open the repo in a DevContainer as suggested by VSCode.

## Diagrid setup

```bash
diagrid project create catalyst-tetris --deploy-managed-pubsub --deploy-managed-kv
```

```bash
diagrid project get catalyst-tetris
```

```bash
diagrid project use catalyst-tetris
```

```bash
diagrid appid create game
```

```bash
diagrid appid create users
```

```bash
diagrid appid list
```

```bash
diagrid connection list
```

```bash
diagrid connection apply -f userscores.yaml
```

```bash
diagrid subscription create pubsub --connection pubsub --topic scoreupdates --route /update-score --scopes users
```

```bash
diagrid subscription list
```

## update dev-catalyst-tetris.yaml

- appId: game
  appPort: 8001
  env:
    DAPR_API_TOKEN:
    DAPR_APP_ID: game
    DAPR_GRPC_ENDPOINT: 
    DAPR_HTTP_ENDPOINT: 
  workDir: game
  command: ["go", "run", "main.go"]
- appId: users
  appPort: 8002
  env:
    DAPR_API_TOKEN:
    DAPR_APP_ID: users
    DAPR_GRPC_ENDPOINT:
    DAPR_HTTP_ENDPOINT:
    FLASK_KEY: "12345678"
  workDir: users





Now open http://localhost:5000 in either a single browser with another private tab, or two different browsers to play against yourself.

## Install Python dependencies

1. Create a Python virtual environment

```bash
python3 -m venv env
source env/bin/activate
```

2. Install Python requirements

```bash
pip3 install -r users/requirements.txt
```

3. Run the apps using the Diagrid CLI

```bash
diagrid dev start
```

Open a browser and navigate to `http://localhost:5000` to play the game.
You can open a second browser window in private mode to simulate another player.


## More information
Do you want to try out Catalyst? Sign up for the [private beta](https://pages.diagrid.io/catalyst-early-access-waitlist)! Want to learn more about Catalyst? Join the [Diagrid Discourse](https://community.diagrid.io/) where application developers share knowledge on building distributed applications. Have you built something with Catalyst? Post it in the [Built with Catalyst](https://community.diagrid.io/t/built-with-catalyst/23) topic and get your item featured in the Diagrid newsletter.