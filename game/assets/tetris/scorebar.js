function ScoreBar(x, y) {

  this.c = color(176,224,230);
  this.xpos = x;
  this.ypos = y;
  this.score = 0;
  this.oppScore = 0;

  this.display = function() {
    fill(this.c);
    rectMode(CORNER);
    rect(this.xpos, this.ypos, 100, 10);
    rect(this.xpos+100, this.ypos, 100, 10);
    barScore = this.oppScore-this.score;
    fill(color(255,0,0));
    rect(this.xpos+100, this.ypos, barScore/10, 10);
  }
}
