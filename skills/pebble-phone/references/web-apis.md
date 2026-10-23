# Web APIs and location

## Open-Meteo (no API key)

```javascript
function weatherCodeToCondition(code) {
  if (code === 0) return "Clear";
  if (code <= 3) return "Cloudy";
  if (code <= 48) return "Fog";
  if (code <= 55) return "Drizzle";
  if (code <= 65) return "Rain";
  if (code <= 75) return "Snow";
  if (code <= 82) return "Showers";
  if (code >= 95) return "T-Storm";
  return "Unknown";
}

function fetchWeather(lat, lon) {
  var url = "https://api.open-meteo.com/v1/forecast?latitude=" + lat +
    "&longitude=" + lon + "&current=temperature_2m,weather_code";
  var xhr = new XMLHttpRequest();
  xhr.timeout = 15000;
  xhr.onload = function () {
    if (xhr.status < 200 || xhr.status >= 300) return fail("http " + xhr.status);
    var j = JSON.parse(xhr.responseText);
    Pebble.sendAppMessage({
      TEMPERATURE: Math.round(j.current.temperature_2m),
      CONDITIONS: weatherCodeToCondition(j.current.weather_code)
    }, ok, fail);
  };
  xhr.onerror = function () { fail("network"); };
  xhr.ontimeout = function () { fail("timeout"); };
  xhr.open("GET", url);
  xhr.send();
}
```

## Location

```javascript
navigator.geolocation.getCurrentPosition(function (pos) {
  fetchWeather(pos.coords.latitude, pos.coords.longitude);
}, function (err) {
  console.log("location error", err);
  // Send a fallback or an explicit "no location" state.
});
```

- Add `"capabilities": ["location"]`.
- On the emulator/desktop, location may be unavailable; handle it.
- Re-request on a schedule or when the watch asks; do not poll aggressively.

## Retry

First fetch can fail transiently. Retry a few times with backoff; keep the watch UI in a clear "no data" state instead of a permanent spinner.

## Security

Never embed API keys/secrets in PKJS; the `.pbw` is readable.
