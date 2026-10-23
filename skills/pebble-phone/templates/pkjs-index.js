// Minimal PKJS lifecycle skeleton (src/pkjs/index.js)
Pebble.addEventListener("ready", function () {
  console.log("PKJS ready");
});

Pebble.addEventListener("appmessage", function (e) {
  if (e.payload.REQUEST_DATA) {
    Pebble.sendAppMessage({ DATA_VALUE: 42 },
      function () { console.log("sent"); },
      function (err) { console.log("send failed", err); });
  }
});
