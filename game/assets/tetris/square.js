function Square(x, y, cl) {
  this.xpos = x;
  this.ypos = y;
  this.c = cl;

  this.display = function() {
    fill(this.c);
    rectMode(CORNER);
    rect(this.xpos, this.ypos, 10, 10);
  }
}
