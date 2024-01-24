ARG GO_VERSION=1.21

FROM golang:${GO_VERSION} as game
WORKDIR /game
COPY . /game
RUN CGO_ENABLED=0 go build -v -o game

FROM scratch
COPY --from=game /game/game /usr/local/bin/game

ENTRYPOINT ["/usr/local/bin/game"]
