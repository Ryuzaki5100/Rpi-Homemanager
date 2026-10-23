# Project types

## Watchface vs watchapp

| | Watchface | Watchapp |
|---|---|---|
| `watchapp.watchface` | `true` | `false` |
| Buttons | None; accelerometer tap only | Full Click API |
| Exit | System-controlled | BACK pops the window stack |
| Update | Tick timer / minute change | Clicks + AppTimer loops |
| Launcher | Default face | App list / quick launch / wakeup |

## C vs Alloy

| Prefer Alloy | Prefer C |
|---|---|
| emery/gabbro only | Any older platform |
| Web APIs via `fetch()` | MenuLayer/ActionBar/Health/Glances/timeline/workers |
| Modern JS ergonomics | Maximum performance / tight memory |
| Quick UI iteration | Games with per-frame control |

Alloy metadata: `"projectType": "moddable"`. C projects must not set it.

## Phone integration

- `none`: no `src/pkjs`.
- `pkjs`: `src/pkjs/index.js` for AppMessage/web data/location.
- `clay`: `src/pkjs/index.js` + `src/pkjs/config.js`, `"capabilities": ["configurable"]`, matching `messageKeys`.
