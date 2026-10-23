// Minimal Alloy watchapp skeleton (src/embeddedjs/main.js)
import Poco from "commodetto/Poco";
import Button from "pebble/button";
import Vibes from "pebble/vibes";

const render = new Poco(screen);
const black = render.makeColor(0, 0, 0);
const white = render.makeColor(255, 255, 255);
const font = new render.Font("Gothic-Bold", 28);
let count = 0;

function draw() {
  render.begin();
  render.fillRectangle(black, 0, 0, render.width, render.height);
  const text = `Count: ${count}`;
  const w = render.getTextWidth(text, font);
  render.drawText(text, font, white, (render.width - w) / 2, render.height / 2 - font.height / 2);
  render.end();
}

new Button({
  types: ["select", "back"],
  onPush(down, type) {
    if (!down) return;
    if (type === "select") {
      count++;
      Vibes.shortPulse();
      draw();
    }
  }
});

draw();
