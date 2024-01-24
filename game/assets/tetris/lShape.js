function LShape(boardX, boardY, speed) {
  this.squares = [];
  this.bottom = 30;
  this.left =   30;
  this.right =  60;
  this.settled = 0;
  this.rotation =0;
  this.speed =speed;
  this.colour = color(255, 255, 100);

  this.squares.push(new Square(boardX + 30,20, this.colour));
  this.squares.push(new Square(boardX + 40,20, this.colour));
  this.squares.push(new Square(boardX + 50,20, this.colour));
  this.squares.push(new Square(boardX + 50,10, this.colour));

  this.display = function() {
    for(var i=0; i<this.squares.length; i++){
      this.squares[i].display();
    }
  }

  this.fall = function() {
    for(var i =0; i< this.squares.length; i++){
      this.squares[i].ypos += this.speed;
    }
    this.bottom +=this.speed;
  }

  this.moveRight = function(){
    if(this.right < 100){
      for(var i =0; i < this.squares.length; i++){
        this.squares[i].xpos += 10;
      }
      this.right+=10;
      this.left +=10;
    }
  }

  this.moveLeft = function(){
    if(this.left > 0){
      for(var i =0; i < this.squares.length; i++){
        this.squares[i].xpos += -10;
      }
      this.right += -10;
      this.left += -10;
    }
  }

  this.rotateClock = function() {
    if(this.rotation ==0){
      //_| -> L
      this.squares[0].xpos += 10;
      this.squares[0].ypos += -10;
      this.squares[2].xpos += -10;
      this.squares[2].ypos += 10;
      this.squares[3].ypos += 20;
      this.left += 10;
      this.bottom += 10;
      this.rotation = 1;

    } else if(this.rotation == 1) {
      // L -> |--
      if(this.left > 0) {
        this.squares[0].xpos += 10;
        this.squares[0].ypos += 10;
        this.squares[2].xpos += -10;
        this.squares[2].ypos += -10;
        this.squares[3].xpos += -20;
        this.left += -10;
        this.rotation = 2;
      }

    } else if(this.rotation == 2){
      //|-- -> -|
      this.squares[0].xpos += -10;
      this.squares[0].ypos += 10;
      this.squares[2].xpos += 10;
      this.squares[2].ypos += -10;
      this.squares[3].ypos += -20;
      this.right += -10;
      this.rotation = 3;

    } else if(this.rotation == 3){
      // -| -> _|
      if(this.right < 100){
        this.squares[0].xpos += -10;
        this.squares[0].ypos += -10;
        this.squares[2].xpos += 10;
        this.squares[2].ypos += 10;
        this.squares[3].xpos += 20;
        this.bottom += -10
        this.right += 10;
        this.rotation = 0;
      }
    }
  }
}
