# AppMessage protocol

## Message keys

- Declared in `package.json`:
  ```json
  "messageKeys": ["TEMPERATURE", "CONDITIONS", "REQUEST_WEATHER"]
  ```
- C: `MESSAGE_KEY_TEMPERATURE`, etc.
- PKJS: string keys in the dictionary.
- Clay: `messageKey` strings must match.

## C receive

```c
static void inbox_received(DictionaryIterator *iter, void *context) {
  Tuple *t = dict_find(iter, MESSAGE_KEY_TEMPERATURE);
  if (t) s_temperature = (int)t->value->int32;
  Tuple *c = dict_find(iter, MESSAGE_KEY_CONDITIONS);
  if (c) snprintf(s_conditions, sizeof(s_conditions), "%s", c->value->cstring);
}
```

Register before opening:

```c
app_message_register_inbox_received(inbox_received);
app_message_register_inbox_dropped(inbox_dropped);
app_message_open(app_message_inbox_size_maximum(), app_message_outbox_size_maximum());
```

## C send

```c
DictionaryIterator *iter;
if (app_message_outbox_begin(&iter) == APP_MSG_OK) {
  dict_write_uint8(iter, MESSAGE_KEY_REQUEST_WEATHER, 1);
  app_message_outbox_send();
}
```

## PKJS

```javascript
Pebble.sendAppMessage({ TEMPERATURE: 18, CONDITIONS: "Clear" },
  function () {}, function (e) { console.log("nack", e); });
```

## Rules

- Keep payloads small; emery supports larger buffers than older platforms.
- Check `dict_find` results; do not dereference missing tuples.
- Use `int32`/`cstring` consistently on both sides.
- Test the inbox handler without PKJS: `pebble send-app-message`.
