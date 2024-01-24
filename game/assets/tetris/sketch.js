var shapes  =[];
var square;
var board;
var speed=10;
var otherBoard;
var gameOver=0;
var level=10;
var move=level-1;
var score=0;
var socket;
var scorebar;
var didRandomSeed = false;
var dropBar = 0;
var button;

function setup() {
  console.log(user);
  console.log(sessionID);
  socket = null;
  didRandomSeed = false;

  createCanvas(1000, 500);
  scale(2.0)
  background(0);

  textSize(10);
  fill('cornflowerblue');
  text(user + ' v ' + opponent, 10, 240);


  socketProtocol = 'https://';
  if (gameHost.startsWith('localhost')) {
    socketProtocol = 'http://';
  }
  socket = io.connect(socketProtocol+gameHost, {
    transports: ['websocket'],
    path: '/game/socket.io'
  });
  socket.once('randSeed', function(data) {
    randomSeed(data);
    board = new Board(100, 10);
    scorebar = new ScoreBar(150, 220);
    board.current = board.randShape();
    otherBoard = new Board(300, 10);
    score.html('Score: 0');
    didRandomSeed = true;
  })

  socket.on('draw', function(data) {
    if (!didRandomSeed) {
      return
    }

    if (level == 3 && !gameOver) {
      board.score++;
      scorebar.score++;
      score.html("Score : " + board.score);
    }

    board.display();
    scorebar.display();

    move++;
    if(move >= level && !gameOver){
      board.current.settled = collisionFall();
      if(board.current.settled || (scorebar.oppScore-scorebar.score) >= 1000){
        board.addToBoard(board.current);
        board.checkLines();
        score.html("Score : " + board.updateScore());
        board.current = board.randShape();
        board.current.settled = collisionFall();
        if(board.current.settled || (scorebar.oppScore-scorebar.score >= 1000)) {
          showReturnButton();
          gameOver=1;
          console.log("Game Over");
          score.html("Score : " + scorebar.score + " Game Over!");
          socket.emit('i-lose', {'sessionID': sessionID, 'data': JSON.stringify(board.score)});
        }
      }
      board.current.fall();
      move = 0;
    }
    socket.emit('ready', {'sessionID': sessionID, 'data': JSON.stringify(board)});
  })

  socket.on('opponent-disconnected', function(data) {
    showReturnButton();
    gameOver=1;
    console.log("Game Over");
    score.html("Score : " + board.updateScore() + " Opponent disconnected! Return to lobby to join another game.");
    socket.emit('i-win', {'sessionID': sessionID, 'data': JSON.stringify(board.score)});
  })

  socket.on('you-win', function(data) {
    showReturnButton();
    gameOver=1;
    console.log("You win!");
    score.html("Score : " + board.updateScore() + " You win!");
    socket.emit('i-win', {'sessionID': sessionID, 'data': JSON.stringify(board.score)});
  })

  socket.on('draw-otherboard', function(o) {
    otherBoard.fromEvent(JSON.parse(o));
    otherBoard.display();
    scorebar.oppScore = otherBoard.score;
  })

  socket.on("disconnect", function(o) {
    if (!gameOver) {
      showReturnButton();
      gameOver=1;
      score.html("Score : " + board.updateScore() + " Disconnected from the server.");
    }
  });

  socket.emit('ready-init', {
    'sessionID': sessionID, 'data': user
  });
  score = createP("Waiting for oponent...");
}

collisionFall = function() {
  if(board.current.bottom > 200) return 1;
  for(var i=0; i<board.current.squares.length; i++){
    if(board.present[((board.current.squares[i].xpos-100)/10)][(board.current.squares[i].ypos/10)]){
      return 1;
    }
  }
  return 0;
}

collisionRight = function() {
  for(var i=0; i<board.current.squares.length; i++){
    if(board.current.squares[i].xpos==190) return 1;
    if(board.present[((board.current.squares[i].xpos-100)/10)+1][(board.current.squares[i].ypos/10)-1]){
      return 1;
    }
  }
  return 0;
}

collisionLeft = function() {
  for(var i=0; i<board.current.squares.length; i++){
    if(board.current.squares[i].xpos==100) return 1;
    if(board.present[((board.current.squares[i].xpos-100)/10)-1][(board.current.squares[i].ypos/10)-1]){
      return 1;
    }
  }
  return 0;
}


function keyPressed() {
  if (gameOver) {
    return
  }
  if((key == ' ' || keyCode == UP_ARROW)  && !board.current.settled) {
    board.current.rotateClock();
  } else if (keyCode == RIGHT_ARROW && !collisionRight() && !board.current.settled){
    board.current.moveRight();
  } else if (keyCode == LEFT_ARROW && !collisionLeft()  && !board.current.settled){
    board.current.moveLeft();
  } else if(keyCode == DOWN_ARROW){
    level=3;
    move=2;
  }
}

function keyReleased() {
  if(keyCode == DOWN_ARROW){
    level=6
    move=0;
  }
}

function goToLobby() {
  window.location.href = 'http://'+lobbyHost;
}

function showReturnButton() {
  button = createButton('Back to lobby');
  button.position(150, 450);
  button.mousePressed(goToLobby);
}
