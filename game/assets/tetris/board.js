function Board(x, y) {

  this.c = color(50);
  this.xpos = x;
  this.ypos = y;
  this.squares = [];
  this.score =0;
  this.mul =0.5;
  this.linesRem = 0;
  this.current = null;

  this.present = new Array(10);
  for(var i=0; i<10; i++){
    this.present[i] =new Array(20);
  }
  for(var i=0; i<10; i++){
    for(var j=0; j<20; j++){
      this.present[i][j]=0;
    }
  }

  this.addToBoard = function(shape){
    var newSquare = {};
    for(var i=0; i< shape.squares.length; i++){
      newSquare = cloneObject(shape.squares[i]);
      newSquare.ypos = Math.round(newSquare.ypos / 10) * 10;
      this.present[((newSquare.xpos-100)/10)][(newSquare.ypos/10)-1] = 1;
      this.squares.push(newSquare);
    }
  }

  cloneObject = function(original){
    var clone = Object.create(Object.getPrototypeOf(original)) ;
    var i , keys = Object.getOwnPropertyNames(original) ;
    for ( i = 0 ; i < keys.length ; i ++ ) {
      Object.defineProperty( clone , keys[ i ] ,
        Object.getOwnPropertyDescriptor( original , keys[ i ] )
      );
    }
    return clone ;
  }

  this.updateScore = function() {
    this.score += (this.mul*this.linesRem*100);
    this.linesRem=0;
    this.mul=0.5;
    return this.score;
  }

  this.checkLines = function() {
    for(var i =0; i<20; i++) {
      if(this.checkLine(i)){
        this.removeLine(i);
        this.mul*=2;
        this.linesRem++;
        this.checkLines();
        break;
      }
    }
    return 0;
  }

  this.checkLine = function(y) {
    for(var i=0; i< 10; i++){
      if(!this.present[i][y]) return 0;
    }
    return 1;
  }

  this.removeLine = function(y) {
    for(var i=this.squares.length-1; i >=0; i--) {
      if(this.squares[i].ypos == (y*10)+10) {
        this.squares.splice(i,1);
      }
    }
    for(var i=this.squares.length-1; i >=0; i--) {
      if(this.squares[i].ypos <(y*10+10)) this.squares[i].ypos += 10;
    }
    for(var i=0; i<10; i++) {
      this.present[i][0] == 0;
      for(var j=y; j>0; j--){
        this.present[i][j] = this.present[i][j-1];
      }
    }
  }

  this.randShape = function() {
    var r = Math.floor(random(6.999));
    switch(r) {
      case 0:
      return new TShape(this.xpos, this.ypos, speed);
      case 1:
      return new LineShape(this.xpos, this.ypos, speed);
      case 2:
      return new ZShape(this.xpos, this.ypos, speed);
      case 3:
      return new BoxShape(this.xpos, this.ypos, speed);
      case 4:
      return new LShape(this.xpos, this.ypos, speed);
      case 5:
      return new SShape(this.xpos, this.ypos, speed);
      case 6:
      return new LOpShape(this.xpos, this.ypos, speed);
    }
  }

  this.display = function() {
    fill(this.c);
    rectMode(CORNER);
    rect(this.xpos, this.ypos, 100, 200);
    for(var i=0; i<this.squares.length; i++) {
      this.squares[i].display();
    }
    if (this.current) {
      this.current.display();
    }
  }

  this.fromEvent = function(obj) {
    this.squares = [];
    if (obj.current) {
      for (var i = 0; i < obj.current.squares.length; i++) {
        obj.squares.push(obj.current.squares[i]);
      }
    }
    for (var i = 0; i < obj.squares.length; i++) {
      var col = color(obj.squares[i].c.levels[0],obj.squares[i].c.levels[1],obj.squares[i].c.levels[2]);
      this.squares.push(new Square(this.xpos+obj.squares[i].xpos-100, this.ypos+obj.squares[i].ypos-10, col));
    }
    this.score = obj.score;
    this.mul = obj.mul;
    this.linesRem = obj.linesRem;
    this.present = obj.present;
  }
}
