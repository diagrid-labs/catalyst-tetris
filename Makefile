VERSION="0.0.23";

build:
	docker build -f game/Dockerfile -t tetris/game:$(VERSION)
	docker build -f game/Dockerfile.tunnel -t tetris/game-tunnel:$(VERSION)
	docker build -f users/Dockerfile -t tetris/users:$(VERSION)
	docker build -f users/Dockerfile.tunnel -t tetris/users-tunnel:$(VERSION)
