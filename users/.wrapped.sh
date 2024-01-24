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
  echo ">> DIAGRID_APP_ID environment variable is not set, defaulting to 'users'"
  DIAGRID_APP_ID="users"
else
  echo ">> DIAGRID_APP_ID environment variable set to '$DIAGRID_APP_ID'"
fi

if [ -z "${FLASK_KEY+x}" ]; then
  echo "<< FLASK_KEY environment variable is not set"
  exit 1
else
  echo ">> FLASK_KEY environment variable is set to '$FLASK_KEY'"
fi

if [ -z "${COMMAND+x}" ]; then
  COMMAND="python3 -m flask run --host=0.0.0.0"
fi

diagrid login --api "$DIAGRID_URL" --api-key "$DIAGRID_API_KEY"
diagrid project use "$DIAGRID_PROJECT"
diagrid dev start --app-id "$DIAGRID_APP_ID" --app-port 8002 -- "$COMMAND"
