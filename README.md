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


# Running locally

This sections covers the steps to run the project locally. It involves some prerequisites that you need to install, getting the source code, the creation of Diagrid Catalyst resources, and updating a Diagrid config file.

## Prerequisites

To be able to run this project locally, you need to have the following prerequisites installed:

- [Docker Desktop](https://docs.docker.com/get-docker/)
- [VSCode](https://code.visualstudio.com/) with the [DevContainers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension
- A [Diagrid Catalyst](https://www.diagrid.io/catalyst) account (currently in early access)

## Get the source code

1. Fork this repo, and clone it to your local machine.
2. Open the repo in VSCode.
3. Open the repo in a DevContainer as suggested by VSCode.
   - This will install some utilities as well as the Diagrid CLI, which is required in the next steps.

## Create the Diagrid Catalyst resources

Use the Diagrid CLI in the DevContainer to create the Diagrid Catalyst resources as follows:

1. Login into Diagrid using the CLI and follow the instructions:

    ```bash
    diagrid login
    ```

2. Create a Catalyst project that includes a managed pubsub and key-value store:

    ```bash
    diagrid project create catalyst-tetris --deploy-managed-pubsub --deploy-managed-kv
    ```

3. Set this project as the default for the upcoming commands:

    ```bash
    diagrid project use catalyst-tetris
    ```

4. Create an App ID for the `game` and `users` services:

    ```bash
    diagrid appid create game
    diagrid appid create users
    ```

5. You can use the list command to status of the created App IDs:

    ```bash
    diagrid appid list
    ```

6. Since the project is created with a managed pubsub and key-value store, you can use the connection command to list these connections:

    ```bash
    diagrid connection list
    ```

7. Create a subscription for the pubsub connection that will trigger the `update-score` endpoint in the `users` service:

    ```bash
    diagrid subscription create pubsub --connection pubsub --topic scoreupdates --route /update-score --scopes users
    ```

8. List the subscriptions to see status of the subscription:

    ```bash
    diagrid subscription list
    ```

## Generate the Diagrid dev config file

Once all the Diagrid Catalyst resources have been created run the following command to generate the Diagrid dev config file in the root of the repo:

```bash
diagrid dev scaffold
```

This results in a `dev-catalyst-tetris` file in the root of the repo. This file contains app connection details for the `game` and `users` services. Some attributes are provided such as `DAPR_API_TOKEN`, `DAPR_APP_ID`, and endpoints provided by Catalyst.

You need to update the following attributes for both the `game` and the `users` service:

- `appPort`
- `command`
- `workDir`

The `users` service also requires a `FLASK_KEY` environment variable to be set.

Copy the values from yaml snippet below.

```yaml
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
```

## Install the Python dependencies

The final step is to install the Python dependencies for the `users` service. This can be done by running the following commands in the terminal:

1. Create a Python virtual environment

    ```bash
    python3 -m venv env
    source env/bin/activate
    ```

2. Install Python requirements

    ```bash
    pip3 install -r users/requirements.txt
    ```

## Run the services

Now you can start both services via the Diagrid CLI:

```bash
diagrid dev start
```

Once the services are running and connected to the Diagrid cloud you can open a browser and navigate to `http://localhost:5000` to play the game.

You can open a second browser window in private mode to simulate another player.


## More information

Do you want to try out Catalyst? Sign up for [early access](https://pages.diagrid.io/catalyst-early-access-waitlist)!

Want to learn more about Catalyst? Join the [Diagrid Discourse](https://community.diagrid.io/) where application developers share knowledge on building distributed applications.

Have you built something with Catalyst? Post it in the [Built with Catalyst](https://community.diagrid.io/t/built-with-catalyst/23) topic and get your item featured in the Diagrid newsletter.