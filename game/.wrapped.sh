#!/usr/bin/env bash

if [ -z "${DIAGRID_URL+x}" ]; then
  echo ">> DIAGRID_URL environment variable is not set, using default https://api.diagrid.io"
  DIAGRID_URL="https://api.diagrid.io"
else
  echo ">> DIAGRID_URL environment variable is set to '$DIAGRID_URL'"
fi

if [ -z "${DIAGRID_API_KEY+x}" ]; then
  echo "<< DIAGRID_API_KEY environment variable is not set"
  exit 1
else
  echo ">> DIAGRID_API_KEY environment variable set"
fi

if [ -z "${DIAGRID_PROJECT+x}" ]; then
  echo "<< DIAGRID_PROJECT environment variable is not set"
  exit 1
else
  echo ">> DIAGRID_PROJECT environment variable set to '$DIAGRID_PROJECT'"
fi

if [ -z "${DIAGRID_APP_ID+x}" ]; then
  echo ">> DIAGRID_APP_ID environment variable is not set, defaulting to 'game'"
  DIAGRID_APP_ID="game"
else
  echo ">> DIAGRID_APP_ID environment variable set to '$DIAGRID_APP_ID'"
fi

if [ -z "${GAME_HOST+x}" ]; then
  echo ">> GAME_HOST environment variable is not set, using default localhost:8000"
else
  echo ">> GAME_HOST environment variable is set to '$GAME_HOST'"
fi

if [ -z "${LOBBY_HOST+x}" ]; then
  echo ">> LOBBY_HOST environment variable is not set, using default localhost:5000"
else
  echo ">> LOBBY_HOST environment variable is set to '$LOBBY_HOST'"
fi

diagrid login --api "$DIAGRID_URL" --api-key "$DIAGRID_API_KEY"
diagrid project use "$DIAGRID_PROJECT"
diagrid dev start --app-id "$DIAGRID_APP_ID" --app-port 8001 -- game
